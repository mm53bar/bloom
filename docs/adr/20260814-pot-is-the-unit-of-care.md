# 20260814 — The pot is the unit of care, not the plant

## Context

The obvious primary noun for an app about houseplants is `Plant`. It is the wrong one.

You water a pot. You put a probe into a pot. Moisture thresholds are a property of a volume
of substrate, not of an organism. And roughly one pot in twenty here holds more than one
plant — a succulent bowl with three things in it shares one soil volume, takes one reading,
and gets one watering decision. Hanging readings off `Plant` would mean either duplicating a
reading across every plant in the bowl or inventing a grouping concept later, under pressure.

It's a shape people arrive at without naming it. A hand-written list of things to go and check
tends to contain containers rather than organisms — one entry for a mixed bowl, not one per
species growing in it — because the container is what you walk up to and act on.

## Decision

`Pot` is the unit of care. It belongs to a `Location`, and it owns the thresholds, the walk
position, the voice aliases, the `MoistureReading`s and the `CareEvent`s.

`Plant` belongs to a `Pot` and holds what is true of the organism rather than the container:
species, light requirement, when it was acquired, a reference URL for care notes. The common
case is one plant per pot; the shared-container case is several, with no special handling.

## Consequences

- The shared bowl models honestly, with no fudging and no duplicate readings.
- The API is `/pots/...`, which reads slightly oddly for an app called Bloom. Accepted: the
  URLs describe what is being recorded.
- "Which plants need water" is really "which pots need water" — the UI shows plant names
  under each pot so the distinction stays invisible to a reader.
- Light is the one question that genuinely belongs to the plant, and it is the one place the
  two models meet: `Plant#light_requirement` against `Location#effective_light`.

## Alternatives considered

- **`Plant` as primary, with an optional `container_id` grouping.** Rejected: it makes the
  95% case carry machinery for the 5% case, and leaves "which record owns the threshold"
  ambiguous.
- **`Plant` as primary, duplicating readings across plants in a shared pot.** Rejected: it
  stores one physical measurement as several rows that can drift apart.
