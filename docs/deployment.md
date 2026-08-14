# Deploying Bloom

Bloom is one container: Puma serves the app and runs the Solid Queue supervisor in-process.
It needs a writable volume for its SQLite databases and a `SECRET_KEY_BASE`. That's all.

## Generic

```bash
docker run -d \
  -p 3214:8080 \
  -v /srv/bloom:/rails/storage \
  -e SECRET_KEY_BASE="$(openssl rand -hex 64)" \
  -e TZ=UTC \
  ghcr.io/mm53bar/bloom:latest
```

Or copy `compose.yaml` from the repository root, fill in the volume path, the `user:` UID:GID
that owns it, and the secret.

**There is no authentication.** Bloom holds no per-user data and accepts unauthenticated
writes so a home automation system can post readings without a token. Only run it somewhere
that isn't publicly reachable — a LAN-only bind, or a reverse proxy that resolves internally.
See `docs/adr/20260814-no-auth-needed.md`.

## Behind a reverse proxy

Bloom needs no special proxy configuration — no websockets, no long-polling, no path
rewriting. With Caddy, a site block is the whole thing:

```caddyfile
bloom.example.com {
	reverse_proxy 10.0.0.10:3214
}
```

Validate before reloading, especially if the Caddyfile is shared with other services:

```bash
docker exec caddy caddy validate --config /etc/caddy/Caddyfile
docker exec caddy caddy reload   --config /etc/caddy/Caddyfile
```

Containers generally can't resolve LAN hostnames, so use an IP as the proxy target.

## First run

The database is created and migrated automatically on boot by `bin/docker-entrypoint`. A
fresh install is empty — `db/seeds.rb` deliberately seeds nothing, because this repository is
public and a seeded plant list describes somebody's house.

Load your own data over the JSON API. Every resource supports ordinary create and update:

```bash
curl -s -X POST http://bloom.example:3214/locations.json \
  -H 'Content-Type: application/json' \
  -d '{"location": {"name": "Sunroom", "natural_light": "bright", "position": 1}}'
```

Keep that data file outside this repository. Match on name and PATCH when a record already
exists, so the loader can be re-run after edits rather than duplicating everything.

To see the app working before you have real data in it, `bin/rails bloom:demo` builds an
invented household, and `bin/rails bloom:undemo` removes it.

## Upgrading

Images are built and pushed on every commit to `main`. Pull the new image and recreate the
container; migrations run on boot. The SQLite databases live in the mounted volume, so the
container itself stays disposable.
