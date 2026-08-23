# 20260814 — Growing medium selects a care regime, not a set of numbers

## Context

Most pots are soil. Some are LECA under semi-hydroponics, and that proportion is expected to
grow.

The tempting model is a `medium` string used only for display, with the same watering and
feeding logic applied to every pot. That is wrong in three separate places at once:

1. **Watering means something different.** Soil is soak-and-dry. Semi-hydro is a reservoir
   that gets topped up. These are not the same action on different schedules.
2. **A probe reading means something different.** A capacitive sensor in expanded clay is
   reading air gaps as much as water content. The number is not comparable to the same number
   in soil, so a shared `dry_below` threshold would be measuring two different quantities and
   pretending they were one.
3. **Feeding is coupled differently.** Soil has cation exchange capacity and holds nutrients
   between feeds, so feeding is periodic. Semi-hydro has no such buffer, so nutrients go in
   with every top-up — there is no separate feeding schedule to fall behind on.

Practical guidance on semi-hydro conversion tends to reach the same conclusion, describing it
as a different watering method entirely rather than a substrate swap: you bare-root the plant,
wash off all soil, and move to a nutrient solution.

## Decision

`Pot#medium` is an enum (`soil`, `semi_hydro`) that selects behaviour. Every branch on it in
`Pot` is one of the three divergences above:

- `#needs_water?` — semi-hydro ignores the probe reading and uses refill cadence.
- `#too_wet?` — semi-hydro is never "too wet" by probe reading.
- `#needs_fertilizer?` — always false for semi-hydro.
- `#probe_prompt` / `#spoken_verdict` — different phrasing, because the person standing there
  is checking a reservoir rather than poking soil.

Thresholds are still recorded for semi-hydro pots, and readings are still stored. They are
history, not inputs to a decision.

## Consequences

- The app can hold both kinds of pot honestly, and the UI says out loud why a semi-hydro
  pot's thresholds are not in charge.
- `GET /pots.json` carries `medium` and a ready-made `prompt`, so a voice assistant
  never needs to know this distinction exists.
- If a third regime appears (pure hydroponics, passive wicking), it is a new enum value plus
  its own branches — the shape already accommodates it.

## Alternatives considered

- **Subclass `Pot` per medium (STI).** Rejected: three small conditionals do not justify a
  class hierarchy, and it trades a readable model for indirection.
- **Per-medium threshold defaults only, shared logic.** Rejected: this is the model that
  treats a semi-hydro reading as a soil reading with different numbers, which is the
  specific error this ADR exists to avoid.
