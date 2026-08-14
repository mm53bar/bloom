# 20260814 — No authentication

## Context

Bloom holds no per-user state. Plants, pots, locations and their care history are shared
household data with no owner, and nothing in the app would differ between two people looking
at it. There is no account to protect, and no view that needs to know who is asking.

The intended deployment is a private network address, reachable from inside a home and not
from the internet.

One thing deserves naming rather than waving through: this API accepts automated **writes**. A
home automation system posts moisture readings and watering records on a schedule, so the
decision is not merely "no login screen" but "unauthenticated writes are acceptable here".

## Decision

No authentication, on the API or the web UI. No `User` model, no login, no trust of
proxy-injected identity headers.

## Consequences

- A home automation system calls the API with no credential, so there is no token to store in
  its configuration and nothing to rotate. This matters more than it sounds: voice assistants
  and polling sensors cannot do interactive sign-in, so any auth scheme would need a carve-out
  for exactly the endpoints that accept writes.
- Anything on the same network can write a moisture reading. The realistic worst case is a
  wrong number in a plant-watering log, which is why this is acceptable here and would not be
  in an app holding anything of consequence.
- The app must never be deployed anywhere publicly reachable. `compose.yaml` says so in its
  header. This is an operational responsibility the app does not enforce.
- Per-person state — "who watered it", personal reminders — is the trigger to revisit. Not
  before.

## Alternatives considered

- **A shared bearer token on write endpoints.** Rejected: it adds a secret to manage in two
  places to protect against an attacker already inside the network, who could do considerably
  more interesting things than falsify a soil reading.
- **Forward-auth in front of the whole app.** Rejected: it breaks every machine caller, and
  the bypass path needed to unbreak them reinstates the same exposure with more moving parts.
