# 20260823 — Drop walk position from Area, Spot, and Pot

## Context

`Area#position`, `Spot#position` and `Pot#position` existed to answer one question: when
there's a single roving probe and no other way to tell which pot it's currently in, what order
do you carry it round the house so a reading can be matched to a pot at all? `PotsController#walk`
and the guided-walk voice automation in `docs/home-assistant.md` were built entirely to solve
that — a spoken prompt per pot, in a fixed sequence, waiting for the probe to visibly move
before trusting a reading belonged to the pot just announced.

NFC tags (`docs/adr/20260823-pot-slug-identifiers.md`, `ha_tag_id` on `Pot`) answer the same
question a different way: tap the tag at the pot you're standing in front of, and Bloom knows
exactly which one it is, instantly, with no sequence and no waiting. Once that path existed,
walk order stopped being load-bearing for anything — it was infrastructure kept alive by a
problem that no longer needs solving that way.

Bloom is a few days old with no other consumers, no printed labels depending on this ordering,
and no automations besides the two documented in this repo. There's a real cost to removing a
concept and no real cost to it being wrong here: this is the moment to do it, not the moment to
carry it forward "just in case," since every day it survives is a day it can end up hardcoded
into something new that then has to be un-wound later.

## Decision

Removed entirely, at all three levels:

- `position` column dropped from `areas`, `spots`, and `pots` (with their now-orphaned
  indexes).
- `Area::in_walk_order` / `Spot::in_walk_order` / `Pot::in_walk_order` replaced by a plain
  `ordered` scope on each — alphabetical by name, joined through the parent where relevant
  (`Pot.ordered` sorts by area name, then spot name, then pot name).
- `PotsController#walk`, its route, and both `walk.html.erb`/`walk.json.jbuilder` views are
  gone. `docs/home-assistant.md`'s guided-walk automation section is deleted rather than kept
  as a documented-but-discouraged option — it depended on `position` existing at all, so there
  was nothing left to document once the column was gone.
- The bundled per-pot JSON payload `walk.json` used to provide (aliases, prompt,
  `record_reading_url`, thresholds, everything one HA sensor needs) moved onto the plain pot
  index instead of disappearing with it — `GET /pots.json` now returns `{ pot_count,
  generated_at, pots: [...] }`, using the same `_pot` partial every other JSON view already
  used. One endpoint bundling every pot for a single cached HA sensor is still useful
  infrastructure; it just isn't "the walk" anymore, and it isn't a second endpoint alongside
  the index that duplicates most of the same fields.
- The "ask about one plant" and "identify a tag scan" automations in `docs/home-assistant.md`
  both already matched against a cached sensor's `pots` attribute rather than anything
  order-dependent, so neither needed to change beyond the sensor's name (`sensor.bloom_pots`)
  and its resource URL.

## Consequences

- The plain pot list page groups by area/spot alphabetically rather than in a chosen sequence.
  Nobody had actually set a deliberate non-alphabetical order yet, so nothing observable changes
  for the one real household this has ever run against.
- Anyone deploying this later needs to update their `configuration.yaml`'s `rest:` sensor to
  point at `/pots.json` instead of `/pots/walk.json` (the one-time YAML edit `docs/home-assistant.md`
  already calls out) and, if they keep an existing `sensor.bloom_walk` entity name rather than
  renaming it, adjust any automation templates that reference it by name. Nothing in this repo
  forces the entity to be renamed — that's a per-deployment choice.
- `bloom_record_reading`'s example payload in `docs/home-assistant.md` section 3 used to show
  `pot_id: "{{ pot.id }}"`, left stale since the slug ADR shipped. Fixed to `pot.slug` while
  touching this file anyway.
- If a future feature genuinely needs a manual sort order again — a printed label sheet laid
  out in a specific sequence, say — it gets reintroduced deliberately for that feature, scoped
  to what that feature needs, not resurrected wholesale because the column used to exist.

## Alternatives considered

- **Keep `position` but stop using it for anything.** Rejected: a column nobody reads or writes
  is worse than no column — it invites a future reader to assume it means something and build
  on top of a value that was never maintained.
- **Keep the guided-walk automation documented as a fallback for probe-only setups with no NFC
  tags yet.** Rejected: it depended on `position` to mean anything (the sequence *was* the
  point), so keeping it would have meant keeping the column just to support a path nothing in
  this household actually uses anymore.
- **Rename `sensor.bloom_walk` in the docs but leave `walk.json` as a separate endpoint from
  the index.** Rejected: it would have meant maintaining two overlapping "list every pot" JSON
  views with slightly different field sets, for no reason beyond historical inertia.
