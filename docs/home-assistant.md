# Wiring Bloom to Home Assistant

Bloom is built for one roving soil probe: you carry a single sensor round the house, and the
app tells you where to go, what to say, and what the reading means. This guide sets up the
Home Assistant side of that.

Everything below uses placeholder hostnames and entity IDs. Substitute your own.

> **One-time YAML edit.** `rest:` sensors and `rest_command:` services can only be declared in
> `configuration.yaml` — there's no REST endpoint or UI for them. After this initial edit and
> a restart, everything else (automations, scripts) is manageable through the normal API.

## 1. Read from Bloom

```yaml
# configuration.yaml
rest:
  # The ordered round through the house. Everything needed to run it is in the
  # attributes: prompts, aliases, thresholds, the area and spot, and where to
  # post each reading.
  - resource: http://bloom.example:3214/pots/walk.json
    scan_interval: 900
    sensor:
      - name: Bloom Walk
        unique_id: bloom_walk
        value_template: "{{ value_json.pot_count }}"
        json_attributes:
          - pots
          - generated_at

  # What currently wants attention.
  - resource: http://bloom.example:3214/pots/due.json
    scan_interval: 900
    sensor:
      - name: Bloom Due
        unique_id: bloom_due
        value_template: "{{ value_json.counts.needs_water }}"
        json_attributes:
          - counts
          - needs_water
          - too_wet
          - needs_check
          - needs_fertilizer
```

The state of `sensor.bloom_walk` is the pot count; the useful payload is in its attributes.
That's deliberate — HA truncates sensor state at 255 characters, so lists belong in
attributes.

## 2. Write back to Bloom

```yaml
# configuration.yaml
rest_command:
  bloom_record_reading:
    url: "http://bloom.example:3214/pots/{{ pot_id }}/moisture_readings.json"
    method: post
    content_type: "application/json"
    payload: '{"moisture_reading": {"value": {{ value }}, "source": "zigbee"}}'

  bloom_mark_watered:
    url: "http://bloom.example:3214/pots/{{ pot_id }}/watered.json"
    method: post
    content_type: "application/json"
    payload: "{}"

  bloom_mark_fertilized:
    url: "http://bloom.example:3214/pots/{{ pot_id }}/fertilized.json"
    method: post
    content_type: "application/json"
    payload: "{}"
```

## 3. Let Bloom do the thinking

`bloom_record_reading` returns the verdict with the record, so the automation never needs a
copy of your thresholds — and never needs to know that semi-hydro pots are judged differently:

```yaml
- action: rest_command.bloom_record_reading
  data:
    pot_id: "{{ pot.id }}"
    value: "{{ states('sensor.soil_probe_moisture') | float(0) }}"
  response_variable: reading

- action: notify.wherever
  data:
    message: "{{ reading['content']['verdict'] }}"
```

That yields lines like *"The Big Fern is at 12 percent, it needs water."*

## 4. The guided walk

Iterate the pots from `sensor.bloom_walk`, speaking Bloom's own prompt at each stop and
waiting for the probe to actually move before recording.

```yaml
alias: Bloom - Guided plant check
mode: single
triggers:
  - trigger: conversation
    command:
      - check the plants
      - do the plant round
actions:
  - variables:
      pots: "{{ state_attr('sensor.bloom_walk', 'pots') }}"

  - repeat:
      for_each: "{{ pots }}"
      sequence:
        - variables:
            baseline: "{{ states('sensor.soil_probe_moisture') | float(0) }}"

        # Bloom supplies the sentence — "Put the sensor in the X" for soil,
        # "Check the reservoir on the X" for semi-hydro.
        - action: notify.wherever
          data:
            message: "{{ repeat.item.prompt }}"

        - wait_for_trigger:
            - trigger: template
              value_template: >
                {{ (states('sensor.soil_probe_moisture') | float(baseline) - baseline) | abs >= 2 }}
          timeout: "00:06:00"
          continue_on_timeout: true

        - if:
            - condition: template
              value_template: "{{ wait.trigger is not none }}"
          then:
            - action: rest_command.bloom_record_reading
              data:
                pot_id: "{{ repeat.item.id }}"
                value: "{{ states('sensor.soil_probe_moisture') | float(0) }}"
              response_variable: reading
            - action: notify.wherever
              data:
                message: "{{ reading['content']['verdict'] }}"

  - action: notify.wherever
    data:
      message: That's all of them.
```

Two details worth keeping if you adapt this:

- **Wait for a change of at least 2 points from the baseline**, not for any change. A probe
  sitting on a table drifts by a point either way, and triggering on that records a reading
  for a pot the sensor was never in.
- **Read the baseline fresh at each stop**, not once at the start. After the first pot the
  probe is already wet, so a baseline from the beginning of the walk never matches again.

## 5. Asking about one plant

`voice_aliases` on a pot are there so a person can say whatever they naturally say. Match
against the walk list rather than hardcoding names:

```yaml
- variables:
    spoken: "{{ trigger.slots.plant | lower | trim }}"
    match: >
      {{ (state_attr('sensor.bloom_walk', 'pots') | default([]))
         | selectattr('aliases', 'contains', spoken) | list | first
         | default((state_attr('sensor.bloom_walk', 'pots') | default([]))
           | selectattr('name', 'equalto', spoken) | list | first) }}
```

If `match` is empty, say so rather than guessing — an honest "I don't know that one" beats
watering the wrong plant.

## 6. Identifying a pot from an NFC tag scan

Each pot has an optional `ha_tag_id` — the ID Home Assistant assigns when you register a tag
under **Settings → Automations & Scenes → Tags**, pasted into that pot's edit form in Bloom.
It's `nil` until a physical tag has actually been linked to that pot.

A tag scan carries that ID as `trigger.event.data.tag_id`. Match it against the walk list the
same way a spoken plant name is matched in the section above — no separate Bloom endpoint
needed:

```yaml
triggers:
  - trigger: tag
actions:
  - variables:
      pot: >
        {{ (state_attr('sensor.bloom_walk', 'pots') | default([]))
           | selectattr('ha_tag_id', 'equalto', trigger.event.data.tag_id)
           | list | first }}

  - if:
      - condition: template
        value_template: "{{ pot is none }}"
    then:
      - stop: "Scanned tag isn't linked to a pot in Bloom"

  - action: rest_command.bloom_record_reading
    data:
      pot_id: "{{ pot.slug }}"
      value: "{{ states('sensor.soil_moisture_tool_soil_moisture') | float(0) }}"
```

`pot_id` here is a slug (`humble-pyramid`), not a number — `bloom_record_reading`'s URL
template just interpolates whatever string it's given, so this works unchanged from the
`rest_command` defined in section 2.

## Why the data lives in Bloom

Keeping the plant list in Bloom rather than in the automation means adding a plant is one
form submission instead of an edit to every automation that mentions it — and the thresholds,
the phrasing and the soil-versus-semi-hydro rules stay in one place with tests around them.
