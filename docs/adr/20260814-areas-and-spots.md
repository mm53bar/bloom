# 20260814 — Areas contain Spots; light belongs to the Spot

> The two-level split and the light rule below still hold. The walk-position ordering this
> ADR describes does not — see `docs/adr/20260823-drop-walk-position.md`.

## Context

The first version of this app had a single `Location`, and pots belonged to it
directly. That worked until a real collection went in and immediately broke it: a
living room held a shelf beside a south window under LED grow lights, and a second
shelf on the opposite wall with nothing over it. Those are the same room by any
human account and completely different places to keep a plant.

The workaround was a location called "Living Room North Shelf", which is a lie
about the house — it isn't a room — and it scales badly, because every subdivided
room invents another fake one.

Two separate things were being conflated:

- **What a person names.** "The living room." This is how people talk, how the walk
  is grouped, and how Home Assistant models a house.
- **What determines care.** "The shelf in the window." Light varies sharply within
  a single room, and light is the whole reason the app records place at all.

## Decision

Two levels: **`Area` has_many `Spot`s**, and a `Pot` belongs to a Spot.

- **`Area`** — name, walk position, `ha_area`, notes. Owns **no light**.
- **`Spot`** — `natural_light`, `exposure`, `grow_light_entity_id`, walk position.
  Owns all of it.
- **`Pot`** — belongs to a Spot; `Pot#area` delegates through.

Three decisions make this liveable rather than tedious:

1. **Light lives only on Spot.** Putting a fallback on Area as well would create two
   sources of truth, and eventually they would disagree.
2. **Creating an Area creates one Spot named after it.** Most areas are never
   subdivided, so nobody should have to name a spot to add a kitchen. A second spot
   is what you add precisely when the light differs.
3. **`Spot#full_name` collapses the common case.** A single-spot area renders as just
   the area name — "Kitchen", not "Kitchen — Kitchen" — so the extra level is
   invisible until it is needed.

The word **Area** rather than Room, for two reasons: a deck, a balcony or a
greenhouse is not a room, and Home Assistant calls this exact level an area, which
makes `Area#ha_area` a pairing rather than a translation. The cost is that "area"
and "spot" are close in ordinary English; the direction is therefore stated
everywhere it matters — an Area contains Spots, never the reverse.

## Consequences

- The light question is finally answerable honestly: `Spot#effective_light` describes
  a place a plant actually sits, and `Plant#light_satisfied?` compares against that.
- The API reports both levels. `walk.json` gives `area` and `spot`, so a spoken
  prompt can say "in the living room, on the north shelf".
- `Area#ha_area` now has an obvious home. Previously the HA mapping and a grow-light
  entity were on the same record despite belonging at different levels — an area maps
  to an HA area, a grow light hangs over one shelf.
- Walk order is three-deep: area position, then spot position, then pot position.
- Adding a spot to an area does not disturb the pots already in it, so subdividing a
  room later is cheap. That was the main thing the old model made expensive.
- This was a breaking API change made while the app had no external consumers. Doing
  it after the voice automations were wired would have cost considerably more.

## Alternatives considered

- **Keep one table, add a `room` string for grouping.** Roughly a tenth of the work.
  Rejected: rooms stay un-modelled, so there is nowhere for the HA mapping or
  room-level notes, and "Living Room" versus "Living room" becomes a real bug.
- **Name the levels `Room` and `Spot`.** Better contrast between the two words, and
  tempting for that reason alone. Rejected because it forces decks, balconies and
  entryways to be "rooms", and leaves the HA area mapping as a translation.
- **A self-referential `Location` with an optional parent.** More flexible than
  needed, and every query grows a recursive case for a hierarchy that is always
  exactly two deep.
- **Light on Area with a per-Spot override.** Rejected: two places to read the same
  fact, and the override is the only one that is ever right.
