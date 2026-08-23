# Bloom — agent guidance

A self-hosted Rails app for keeping houseplants alive: what lives where, what light it gets,
when it was last watered and fed, and what a moisture probe read last, at whichever pot it was
in. This file is standing rules, not a spec — read the code and `docs/adr/` for the actual
design.

## Standing rules

- **Nothing personal goes in this repository.** It is public. No real plant names, room names,
  smart-home entity IDs, hostnames, IP addresses, or thresholds — not in `db/seeds.rb`, not in
  fixtures, not in docs, not in a commit message. Fixtures are invented and say so;
  `db/seeds.rb` seeds nothing; `bin/rails bloom:demo` builds a fake household for looking at.
  Real data is loaded over the JSON API from a file kept outside this repo. See
  `docs/adr/20260814-no-personal-data-in-this-repo.md`. This covers git history too, so it
  holds from the first commit rather than from whenever the repo is made public.
- **Light resolves to DLI, in mol/m²/day.** `Spot#effective_dli` returns a measurement when
  there is one and otherwise the figure its qualitative word implies; `Plant#dli_required` is
  the **minimum the plant tolerates**, not what it would enjoy. The five-word ladder is the
  entry point for describing an unmetered spot, not the thing that decides anything — two
  shelves it called identical measured 1.5 and 11.3. See `docs/adr/20260817-light-as-dli.md`.
  Read requirements as minimums: against absolute figures, "what it would enjoy" flagged two
  thirds of a real collection and the badge stopped meaning anything.
- **Four levels, each owning one thing.** `Area` (a part of the house) contains `Spot`s (where
  a pot sits) which hold `Pot`s which hold `Plant`s. **Light belongs to the Spot and nowhere
  else** — a shelf in a window and a shelf across the same room are not alike, and a second
  source of truth would eventually disagree with the first. An Area owns its name and
  `ha_area`. Creating an Area auto-creates one Spot named after it, and
  `Spot#full_name` hides that level until an area is actually subdivided. See
  `docs/adr/20260814-areas-and-spots.md`.
- **The pot is the unit of care, not the plant.** Readings, care events and thresholds all
  belong to `Pot`. `Plant` holds what is true of the organism — species, light
  requirement, reference URL. Some pots hold several plants sharing one soil volume. See
  `docs/adr/20260814-pot-is-the-unit-of-care.md`.
- **`Pot#medium` selects a care regime.** Soil and semi-hydro differ in what watering means,
  what a probe reading means, and how feeding works. Every branch on `medium` is one of those
  three. Do not "simplify" them into shared logic with different numbers — that is the
  specific mistake `docs/adr/20260814-medium-is-a-care-regime.md` exists to prevent.
- **Absence of evidence is not evidence.** A pot with no readings and no watering history
  reports `needs_check?`, not `needs_water?`. Watering has a sensor behind it so an empty
  history means "go measure"; feeding has none, so an empty history does mean "feed it". The
  asymmetry is deliberate — see `docs/adr/20260814-absence-of-evidence.md`.
- **A reading is only evidence until something invalidates it.** Watering supersedes an earlier
  reading (`Pot#reading_superseded?`); staleness alone drives `needs_check?`. Keep those two
  questions separate.
- No authentication, on the API or the UI — no `User` model, no login, no proxy-auth headers.
  It must only ever run somewhere that isn't publicly reachable. See
  `docs/adr/20260814-no-auth-needed.md`.
- The JSON API is ordinary resourceful Rails — same URLs as the HTML routes, format
  negotiated. There is no `/api` namespace to keep in sync. Full create/update is supported on
  locations, pots and plants because that is how real data gets loaded.
- **The app owns the phrasing, not the caller.** `Pot#probe_prompt` and `#spoken_verdict`
  exist so a voice assistant never needs a copy of the thresholds or a rule about semi-hydro.
  If a consumer is deciding something Bloom could decide, move it here.
- Prefer Rails conventions over architecture-heavy patterns. No `app/services/`. Extract
  nouns, not verbs. Reach for a plain model method before a new abstraction.
- Testing: Minitest with fixtures, Rack integration tests via `ActionDispatch::IntegrationTest`
  + `assert_select`. No RSpec, no factories, no mocking library, no Capybara — see
  `docs/adr/20260814-integration-tests-over-system-tests.md`.
- Time-dependent behaviour (growing season, reading freshness, cadence) is tested with
  `travel_to`, never against the real clock. A test that passes only in August is not a test.
- **Test-environment defaults can hide production failures.** Three real bugs have now
  reached a running server with the suite fully green: a JSON API that rejected every caller
  (forgery protection is off in test), production database paths left commented out by the
  generator, and a boot warning for a deliberately removed gem. `bin/ci` runs
  `script/production-boot-check` for exactly this reason. When a test asserts the *absence* of
  a protection, switch that protection on inside the test and assert both halves — see the CSRF
  test in `test/integration/api_test.rb`.
- Run `bin/ci` before considering work complete — the full gate (rubocop, bundler-audit,
  importmap audit, brakeman, tests, seeds), not just `bin/rails test`. If it fails, fix or
  surface it; do not declare work done.
- Secrets are a plain `SECRET_KEY_BASE` env var. Rails encrypted credentials are unused and
  git-ignored. Never commit a real secret; `compose.yaml` carries a placeholder. See
  `docs/adr/20260814-secrets-from-env.md`.
- Deployment is a single container: web and Solid Queue run together in Puma — no separate
  worker service, no Redis.
- Record significant architectural decisions in `docs/adr/` (`## Context` / `## Decision` /
  `## Consequences` / `## Alternatives considered`). Read that directory before assuming a
  design decision hasn't been made. Coding preferences go here instead.
