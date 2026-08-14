# Bloom — build plan

## Done

**Phase 1 — the shape.** Rails 8.1 / Ruby 3.4.7 skeleton (SQLite, Solid Queue in Puma,
Propshaft, importmap, Tailwind, Minitest). Five models: `Location`, `Pot`,
`Plant`, `CareEvent`, `MoistureReading`. HTML CRUD throughout.

**Phase 2 — the domain and the API.** Due-ness split into *needs water* and *needs checking*.
Medium as a care regime. Seasonal feeding. Light matching between what a plant wants and what
its location provides. Resourceful JSON API with `walk` and `due`, plus full create/update so
data can be loaded over it. 65 tests, `bin/ci` green.

## Next

**Phase 3 — deploy.** The build workflow publishes an image on every push to `main`; the
container host needs to be able to pull it. Then deploy `compose.yaml` and put a reverse proxy
in front. See `docs/deployment.md`.

**Phase 4 — load the real data.** Write the locations, pots and plants into a file kept
*outside* this repository, and POST it in. The loader matches on name and creates or updates,
so it can be re-run after edits. Needs real names, rooms, mediums, light requirements and
thresholds — deliberately not guessed, and kept outside this repository.

**Phase 5 — wire up Home Assistant.** Point `rest:` sensors at the app as described in
`docs/home-assistant.md`, and post readings back from the check routine. Do this after phase
4, so the automations aren't reading an empty app.

## Deliberately not built

- **Photos.** Tempting for an app called Bloom — watching a leaf unfurl is the whole point —
  but nothing asked for it yet, and an unused Active Storage pipeline is exactly the kind of
  scaffolding worth avoiding. `image_processing` and libvips were removed
  from the Gemfile and Dockerfile for that reason. Adding them back is easy when a real need
  turns up.
- **Charts of moisture over time.** The data is being collected and the history endpoint
  exists. Worth doing once there's enough of it to be worth looking at.
- **Any notion of who did the watering.** No per-user data is what lets the app skip
  authentication entirely; adding it means revisiting
  `docs/adr/20260814-no-auth-needed.md`.
- **Propagation tracking.** Cuttings, offsets, pups — a natural fit for a plant app and a
  genuinely different shape from `CareEvent` (it creates a new plant from an existing one).
  Left alone until it's actually wanted.
