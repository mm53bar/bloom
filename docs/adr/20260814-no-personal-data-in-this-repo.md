# 20260814 — No personal data in this repository

## Context

This repository is intended to be public, so other people can run Bloom for their own plants.
That makes seeded example data a disclosure question rather than a convenience question.

It is tempting to treat a plant list as harmless. It isn't, at the scale this app records it.
Bloom's records are plant names tied to room names, ordered into a walking route, with
smart-home entity IDs attached. That is a floorplan of a specific house. Combined with a home
automation integration, the reading timestamps also describe when somebody is at home walking
around it. A seeded install would publish all of that.

Git history compounds it. A private repository that is later made public exposes every commit
ever made to it, so "clean it up before publishing" is not a real plan — the cleanup has to
have happened already.

The same reasoning covers infrastructure. Naming the specific reverse proxy, container
manager, auth provider or NAS a deployment happens to use is reconnaissance material about a
private network, and it makes the documentation worse for everybody else at the same time.

## Decision

Nothing in this repository describes a real household or a real network. Concretely:

- `db/seeds.rb` seeds nothing. It explains why, and points at `bin/rails bloom:demo`.
- Test fixtures are invented (a Sunroom, a Landing, a Big Fern) and say so at the top of
  `test/fixtures/locations.yml`.
- `compose.yaml` is a template carrying placeholder values only.
- Documentation uses placeholder hostnames, IPs and entity IDs, and describes deployment
  generically rather than naming the author's own stack.
- Real data is loaded over the JSON API after deployment, from a file kept outside this
  repository entirely.

This holds from the first commit, not from whenever the repository is made public.

## Consequences

- The app is developed and tested entirely against invented data, which incidentally proves it
  works for somebody other than its author — exactly what a public repo needs.
- Loading real data needs the API to support full resourceful create/update on locations, pots
  and plants, not just the care endpoints. It does.
- The loader must be idempotent (match on name, then create or update) so the data file can be
  edited and re-run. That belongs to the loader, not to this app.
- Deployment-specific facts — which port, which proxy, which host — belong in whatever private
  notes the deployer keeps, not in `docs/`.
- A future contributor's instinct will be to seed something realistic for convenience. This
  ADR exists to say no, deliberately.

## Alternatives considered

- **Seed real data and keep the repository private.** Rejected: it forecloses the goal of
  others using it, and the history problem makes the decision effectively permanent the moment
  it is taken.
- **Seed real data behind an environment check.** Rejected: the data would still be in the
  repository and its history. Where a file is read from is not the issue; where it is stored
  is.
- **Scrub before publishing.** Rejected: rewriting history is unpleasant, error-prone, and
  fails silently when a fork or clone already exists.
