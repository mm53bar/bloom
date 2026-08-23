# Wiring Bloom to Home Assistant

Bloom tracks pots, thresholds, and history for a single roving soil probe — carried from pot
to pot and read into whichever one it's currently sitting in. This guide sets up the Home
Assistant side of that: getting Bloom's pot list into HA, posting readings back, and
identifying which pot a reading belongs to, either by NFC tag or by voice.

Everything below uses placeholder hostnames and entity IDs. Substitute your own.

> **One-time YAML edit.** `rest:` sensors and `rest_command:` services can only be declared in
> `configuration.yaml` — there's no REST endpoint or UI for them. After this initial edit and
> a restart, everything else (automations, scripts) is manageable through the normal API.

## 1. Read from Bloom

```yaml
# configuration.yaml
rest:
  # Every pot, bundled into one response so it can live in one sensor's attributes
  # rather than a request per lookup: aliases, prompts, thresholds, the area and
  # spot, an NFC tag id if one's linked, and where to post each reading.
  - resource: http://bloom.example:3214/pots.json
    scan_interval: 900
    sensor:
      - name: Bloom Pots
        unique_id: bloom_pots
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

The state of `sensor.bloom_pots` is the pot count; the useful payload is in its attributes.
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

`pot_id` here is always a pot's **slug** (`humble-pyramid`), not a database id — see
`docs/adr/20260823-pot-slug-identifiers.md`. It's just a string interpolated into the URL, so
nothing about this `rest_command` changes based on how the caller found that slug.

## 3. Let Bloom do the thinking

`bloom_record_reading` returns the verdict with the record, so the automation never needs a
copy of your thresholds — and never needs to know that semi-hydro pots are judged differently:

```yaml
- action: rest_command.bloom_record_reading
  data:
    pot_id: "{{ pot.slug }}"
    value: "{{ states('sensor.soil_probe_moisture') | float(0) }}"
  response_variable: reading

- action: notify.wherever
  data:
    message: "{{ reading['content']['verdict'] }}"
```

That yields lines like *"The Big Fern is at 12 percent, it needs water."*

## 4. Asking about one plant

`voice_aliases` on a pot are there so a person can say whatever they naturally say. Match
against the pot list rather than hardcoding names:

```yaml
- variables:
    spoken: "{{ trigger.slots.plant | lower | trim }}"
    match: >
      {{ (state_attr('sensor.bloom_pots', 'pots') | default([]))
         | selectattr('aliases', 'contains', spoken) | list | first
         | default((state_attr('sensor.bloom_pots', 'pots') | default([]))
           | selectattr('name', 'equalto', spoken) | list | first) }}
```

If `match` is empty, say so rather than guessing — an honest "I don't know that one" beats
watering the wrong plant.

## 5. Identifying a pot from an NFC tag scan

Each pot has an optional `ha_tag_id` — the ID Home Assistant assigns when you register a tag
under **Settings → Automations & Scenes → Tags**, pasted into that pot's edit form in Bloom
(or synced automatically — see `bin/sync-nfc-tags` in the top-level project). It's `nil` until
a physical tag has actually been linked to that pot.

A tag scan carries that ID as `trigger.event.data.tag_id`. Match it against the pot list the
same way a spoken plant name is matched in the section above — no separate Bloom endpoint
needed:

```yaml
triggers:
  # Not the `tag:` trigger platform — on at least some HA versions it requires a
  # `tag_id` up front, which defeats matching *any* tag against Bloom. The
  # underlying event it wraps has no such requirement.
  - trigger: event
    event_type: tag_scanned
actions:
  - variables:
      pot: >
        {{ (state_attr('sensor.bloom_pots', 'pots') | default([]))
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
    response_variable: reading

  # Whole-house rather than a phone notification: more than one person may be
  # the one holding the probe, and there's no way to know which phone in advance.
  - action: assist_satellite.announce
    target:
      entity_id: all
    data:
      message: "{{ reading['content']['verdict'] }}"
```

Tapping a tag tells Bloom exactly which pot without anyone needing to say a name or follow a
prescribed order — the whole reason a plain pot list, not a sequenced walk, is enough to drive
this.

## Why the data lives in Bloom

Keeping the plant list in Bloom rather than in the automation means adding a plant is one
form submission instead of an edit to every automation that mentions it — and the thresholds,
the phrasing and the soil-versus-semi-hydro rules stay in one place with tests around them.
