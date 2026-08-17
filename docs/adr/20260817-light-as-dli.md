# 20260817 — Light is measured as DLI, not described in words

## Context

Light started as a five-word ladder on `Spot` — `none`, `low`, `medium`, `bright`,
`direct` — with a grow light worth exactly one step up it. That was a reasonable
guess with no instrument to hand.

Then a real house was measured, and the ladder broke in a way that could not be
patched. Two shelves on the same unit, both with no meaningful natural light and both
under a grow light, delivered **1.5** and **11.3 mol/m²/day**. The model computed both
as `low`, because it had no way to know that one fixture emits seven times what the
other does. It labelled the best plant location in the house identically to one of the
worst.

Two further problems surfaced at the same time:

- **A word cannot be checked.** `bright` was an assertion; nobody could tell whether it
  was true. Photographs had produced values that were systematically optimistic by
  roughly an order of magnitude, and nothing in the app could reveal that.
- **The comparison had no natural unit.** Counting rungs between "what the spot gives"
  and "what the plant wants" gave a shortfall in steps, which says nothing about
  whether moving the plant or improving the lamp would close the gap.

Horticulture already has the right unit. **Daily light integral** — total photons
landing on a surface over a day, in mol/m²/day — is what a plant actually lives on, it
is what published requirements are expressed in, and it can be measured.

## Decision

Every light decision resolves to a DLI figure.

- **`Spot#measured_dli`** holds a real measurement, with `measured_ppfd`,
  `light_hours` and `measured_at` as supporting evidence so a figure can be checked
  rather than trusted.
- **`Spot#effective_dli`** returns the measurement when there is one, and otherwise
  the figure implied by `effective_light` via `IMPLIED_DLI`. An unmetered spot still
  gets an answer.
- **`Plant#dli_required`** returns `dli_minimum` if set, otherwise the default implied
  by `light_requirement` via `REQUIREMENT_DLI`.
- **`Plant#light_satisfied?`** compares the two numbers. `light_severity` is a ratio:
  below half of what is needed is `:poor`, between half and all of it `:marginal`.

The qualitative ladder stays as the entry point — it is how a person describes a spot
before measuring it, and most spots will never be measured. It just no longer decides
anything on its own.

`light_requirement` also gains **`none`** as a legal value. Barring it was a mistake:
snake plants, ZZ plants and pothos tolerate deep shade indefinitely, and without it
they were flagged for living somewhere they are perfectly content.

## Consequences

- A measured spot and an unmeasured one are answered identically, so measurement can
  be adopted spot by spot with no flag day.
- The shortfall is now in mol/m²/day (`light_deficit`), which is actionable: it says
  how much more light is needed, and therefore whether a better lamp could supply it.
- `light_requirement` should be read as **the minimum the plant tolerates**, not what
  it would enjoy. This matters: against absolute figures, "what it would enjoy"
  flagged two thirds of a real collection and the badge stopped meaning anything.
- Requirements are now falsifiable. A plant thriving below its stated minimum means
  the minimum is wrong, and the record can be corrected.
- Nothing forces a DLI to be honest — a wrong number is still a wrong number. But
  `measured_at` makes staleness visible, which a bare word never did.
- Lux is a poor instrument for narrow-spectrum grow lights, since it weights green and
  magenta LEDs emit almost none. DLI sidesteps this by being a photon count, but it
  means lux-derived figures for such lights should be treated as floors.

## Alternatives considered

- **Add more rungs, or a grow-light strength multiplier.** Rejected: it postpones the
  problem rather than fixing it, and every added rung is another arbitrary boundary.
- **Replace the qualitative scale entirely with DLI.** Rejected: somebody adding a
  kitchen shelf should not need a quantum sensor before the app will say anything, and
  most spots will never be metered.
- **Store lux instead.** Rejected: lux is a photometric unit weighted to human vision.
  It is fine for daylight and badly misleading under the exact grow lights this app
  needs to reason about.
