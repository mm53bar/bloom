# 20261011 — Read the probe through Home Assistant

## Context

Until now, readings reached Bloom one way: Home Assistant pushed them in, by NFC tag scan or by
voice. Recording one by hand meant watching the probe's value settle in the HA app, then typing
that number into the pot page. The number is already in HA. Copying it by hand is slow and
easy to get wrong.

## Decision

Bloom reads the probe from Home Assistant's REST API (`GET /api/states/<entity>`) when someone
presses **Get from HA** on a pot page. The value fills the reading box. It is not recorded until
the person presses Record, because only they know whether the probe has settled and is in the
right pot. The status line shows how long ago the probe reported, so a value left over from the
previous pot is easy to spot.

Configuration is three environment variables: `HA_URL`, `HA_TOKEN`, and `HA_PROBE_ENTITY`. If
any of them is missing, the feature is off and the button is not shown. The entity id lives in
configuration, not code, because this repository is public.

## Consequences

- Bloom now holds a Home Assistant token, the first credential it needs for anything other than
  itself. It lives in the deployed compose file, like `SECRET_KEY_BASE`
  (`docs/adr/20260814-secrets-from-env.md`).
- Bloom has no authentication (`docs/adr/20260814-no-auth-needed.md`), so anyone who can reach
  it can read the probe's current value through `/probe`. That is one number HA already
  exposes to the same network. The endpoint takes no entity parameter, so it cannot be used to
  read anything else with the token.
- The pot page makes a request to HA only when someone presses the button. Nothing polls.

## Alternatives considered

- **Record immediately on press.** Rejected: one tap fewer, but a press made before the probe
  settles, or while it is still reading the last pot, would store a wrong number with nothing
  to catch it.
- **Have the browser call HA directly.** Rejected: this would put the token in page JavaScript,
  and HA's CORS policy would need loosening.
- **Have HA push the probe value to Bloom continuously.** Rejected: HA does not know which pot
  the probe is in. The person on the pot page does.
