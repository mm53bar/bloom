# 20260823 — Pots are identified by a generated slug, not the database id

## Context

Physical labels are coming: a plastic name stick per pot, with an NFC coin and a QR code on
it. Both encode a URL — `/pots/<something>` — that has to keep working for the life of the
printed label, potentially years.

The database id doesn't survive that. It's stable until a pot is deleted and recreated, which
has already happened twice during the initial data load, and will happen again any time a pot
gets rebuilt rather than edited. A label printed against `/pots/14` can silently start pointing
at nothing, or worse, at whatever pot now holds id 14.

Naming pots by what's in them doesn't work either — plants get repotted, pots get renamed, and
several pots already share a name (`display_name` exists specifically to disambiguate
"Burgundy Pot" collisions in the UI). A stable identifier has to be independent of both the
plant and the pot's current name.

## Decision

Every `Pot` gets a `slug` — two words, adjective-noun, generated once at creation and never
changed (`copper-anchor`, `elegant-vessel`). It comes from two curated word banks that
deliberately avoid plant vocabulary (no `fern`, `basil`, `moss`, `bramble` or similar) so a
slug never reads as a claim about what's actually potted:

```ruby
ADJECTIVES = %w[ copper velvet brisk hollow humble ancient arctic eternal digital happy ... ]
NOUNS      = %w[ harbor canyon ridge valley hill island coast cliff mountain drift ... ]
```

Both banks are entirely a subset of the BIP39 English wordlist (the 2048-word list used for
crypto wallet seed phrases) rather than invented. That list's own design goal — common,
short, unambiguous words with unique 4-letter prefixes, so a partial hearing or a typo still
disambiguates — is exactly what a spoken-and-typed pot identifier wants, and 2048 words is far
more selection than a 60-word bank needs to draw from cleanly. `meadow`, `forest` and `jungle`
are all in BIP39 but excluded anyway — vegetation words fail the same test as `fern` does.

`Pot#to_param` returns the slug, so it becomes the pot's identifier everywhere a URL is built —
`/pots/copper-pebble`, and the nested routes underneath it
(`/pots/copper-pebble/moisture_readings.json`) — with no separate lookup or `/pots/:slug`
route needed. Every controller that resolves a pot from a route param
(`PotsController`, `MoistureReadingsController`, `CareEventsController`) looks it up by
`slug`, not `id`. The raw database id stays out of routing but is still exposed alongside
`slug` in the JSON views — it remains the actual foreign key (see `new_plant_path(pot_id:
@pot.id)`, which sets a real `belongs_to :pot` association and has nothing to do with routing).

Generation happens in `before_validation … on: :create`, not `before_create` — validations run
before `before_create` fires, so a `validates :slug, presence: true` paired with a
`before_create` callback fails every single creation. Caught by the test suite immediately;
recorded here because it's the kind of callback-ordering mistake that's easy to reintroduce.

The migration backfills any existing pots inline, using a migration-local `ActiveRecord::Base`
subclass rather than the `Pot` model, so it keeps working after the model's validations or
callbacks change. In practice the backfill ran against zero rows — production is deployed but
still empty of real data (see top-level `CLAUDE.md`), which is what makes this the right moment
to change the public identifier rather than a breaking change to make later.

## Consequences

- A printed label survives a delete-and-recreate. Renaming a pot, moving it to a different
  spot, or changing what's planted in it never touches the slug.
- `bloom/docs/home-assistant.md`'s payload examples reference `pot.id` for building nested
  URLs. Once real automations are wired up, they should read `pot.slug` (or better, the
  `record_reading_url` the walk/due responses already compute) instead — there's nothing
  deployed yet that this breaks, but it's the thing to get right before wiring the REST
  integration described there.
- Word banks are duplicated between the migration and `Pot` rather than shared. Migrations
  outlive the application code they were written against, so a migration referencing today's
  `Pot::ADJECTIVES` would silently start generating different slugs — or break — the day
  someone edits the word list.
- Two curated 30-word banks give 900 combinations against 23 pots. Comfortable now; worth
  revisiting only if the collection grows by an order of magnitude.

## Alternatives considered

- **UUID.** Rejected: unreadable on a printed label and painful to type if a QR scan fails and
  someone has to enter the URL by hand.
- **A slug derived from the pot's name** (`FriendlyId`-style, re-slugged on rename). Rejected:
  the whole point is a printed label that outlives renames. A slug that changes when the name
  does is the numeric-id problem again with extra steps.
- **Keep the database id, mitigate by never deleting pots.** Rejected: "never delete" isn't a
  constraint this app enforces anywhere else, and relying on discipline to keep 23+ labels
  valid is the kind of thing that fails quietly, months later, for whichever pot got rebuilt.
