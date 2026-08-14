# 20260814 — An empty history is not evidence of dryness

## Context

Every pot has two ways of being judged thirsty: a probe reading below its `dry_below`
threshold, or a watering cadence that has run out. The cadence is the fallback for when
there is no recent reading.

The question this ADR settles is what the fallback should do when there is no history at
all — no readings, and no record of the pot ever having been watered. The first
implementation treated a missing `last_watered_on` as infinitely overdue, so it reported
"needs water". That produced an obviously wrong result: a freshly loaded install, before
anyone has walked the house once, declares that every pot is dry. It is stating as fact
something it has no basis for.

## Decision

Watering and feeding resolve an empty history differently, because the evidence available to
each is different.

**Watering** has a sensor behind it. An absent record means "unknown", not "dry", so
`Pot#needs_water?` returns false and the pot instead surfaces under `#needs_check?` — go and
measure it. The pot is still visible and still actionable; the app just declines to guess
which action.

**Feeding** has no sensor. The record is the only signal there is, so an absent record does
mean "not fed as far as anyone knows", and in growing season that warrants feeding.

`Pot#overdue_by_cadence?` takes an explicit `when_unknown:` argument so the two callers state
which they are, rather than sharing a default that is right for only one of them.

## Consequences

- A fresh install reads "needs checking" everywhere, which is both true and the correct next
  action.
- A pot that is never read and never watered stays in `needs_check?` indefinitely rather than
  disappearing — it keeps asking, just for the right thing.
- The asymmetry needs the comment it has, or it reads as an inconsistency.

## Alternatives considered

- **Treat missing history as overdue for both.** Rejected: it makes the first run of the app
  a wall of false alarms, and trains the reader to ignore it.
- **Treat missing history as fine for both.** Rejected: it lets a pot that has genuinely
  never been fed sit silently through an entire growing season.
- **Require a `last_watered_on` at pot creation.** Rejected: it demands a number nobody
  usually has to hand, and a guessed date is worse than a recorded absence.
