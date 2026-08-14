# Bloom

A small self-hosted Rails app for keeping houseplants alive.

It tracks what lives where, what light each spot provides, when each pot was last watered and
fed, and what a soil moisture probe read the last time somebody walked round the house with
one. It exposes a JSON API so a home automation system can run that walk by voice, record the
readings, and ask what needs attention.

Bloom assumes one roving probe rather than a sensor per plant — you carry it around, and the
app tells you where to go and what to say.

## What it models

- **Location** — a spot in the house: its natural light, and optionally a grow light. A
  location with a grow light counts as one step brighter, which is what decides whether a
  plant is getting what it asks for.
- **Pot** — the unit of care. Thresholds, watering and feeding cadence, walk position and
  voice aliases live here, because a pot is what you water and what you put a probe into.
- **Plant** — what's growing in a pot, and what light it wants. Several plants can share one
  pot; a succulent bowl is one soil volume with one watering decision.
- **CareEvent** — watering, feeding, repotting, treating, pruning. One timeline per pot.
- **MoistureReading** — what the probe said, and when.

### Soil and semi-hydro are treated differently

Not as a display label — as different care regimes. A semi-hydro pot waters on a refill
schedule rather than a probe reading, is never "too wet" by percentage, and takes its
nutrients with every top-up instead of on a feeding interval. A capacitive probe in expanded
clay isn't measuring the same thing it measures in soil, so Bloom doesn't pretend the numbers
are comparable.

## Running it

Requires Ruby 3.4.7.

```bash
bin/setup
bin/rails bloom:demo   # optional: an invented household to look at
bin/dev
```

`bin/rails bloom:undemo` removes the demo data again. `db/seeds.rb` deliberately seeds
nothing.

Run the full check suite — style, security scans and tests — with:

```bash
bin/ci
```

## Deploying

One container runs both the web server and background jobs; there's no separate worker and no
Redis. Copy `compose.yaml`, set the volume path, the `user:` UID:GID and `SECRET_KEY_BASE`,
and deploy it.

**Bloom has no authentication of any kind**, by design — it holds no per-user data. Only run
it somewhere that isn't publicly reachable: a LAN-only bind, or a reverse proxy that resolves
internally. See `docs/adr/20260814-no-auth-needed.md`.

## The API

Ordinary resourceful Rails — the same URLs as the HTML pages, with `.json` or an `Accept`
header. There's no separate `/api` namespace.

| Endpoint | What it's for |
|---|---|
| `GET /pots/walk.json` | The ordered round through the house: what to say at each stop, what names to listen for, the thresholds, and where to post the reading |
| `GET /pots/due.json` | What needs water, what's too wet, what needs checking, what needs feeding |
| `POST /pots/:id/moisture_readings.json` | Record a reading; the response includes the verdict, already phrased |
| `POST /pots/:id/watered.json` | Mark a pot watered |
| `POST /pots/:id/fertilized.json` | Mark a pot fed |
| `GET`/`POST`/`PATCH` `/pots`, `/plants`, `/locations` | Full CRUD, which is how data gets loaded |

The verdict comes back with the reading on purpose. Callers shouldn't hold their own copy of
a pot's thresholds, or know that semi-hydro is judged differently:

```console
$ curl -s -X POST http://bloom.example/pots/1/moisture_readings.json \
    -H 'Content-Type: application/json' \
    -d '{"moisture_reading": {"value": 12, "source": "zigbee"}}' | jq .verdict
"The Big Fern is at 12 percent, it needs water."
```

See `docs/home-assistant.md` for a worked Home Assistant integration.

## Design notes

Decisions worth their own writeup are in `docs/adr/`. The ones most likely to surprise you:

- The pot, not the plant, is the unit of care
- Growing medium selects a care regime rather than a set of numbers
- A pot with no history at all asks to be measured, not watered
