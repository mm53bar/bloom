# 20260814 — Secrets come from the environment

## Context

This repository is public, so `config/credentials.yml.enc` and its master key cannot live in
it. Rails generates both by default, and the encrypted file is normally committed — which is
safe in principle, since it is useless without the key, but it is a live secret sitting in a
public repository for no reason when nothing reads it.

## Decision

`SECRET_KEY_BASE` is read from the environment. Rails encrypted credentials are unused:
`config/master.key` and `config/credentials.yml.enc` are both git-ignored, and the generated
pair was deleted rather than left in place.

`compose.yaml` in this repository carries a placeholder. A deployed copy holds the real value
in its own `environment:` list.

## Consequences

- Nothing secret is ever committed, and there is no key to lose or rotate.
- A deployed compose file is the source of truth for its own configuration.
- Encrypted credentials remain available if something ever genuinely needs them, but adopting
  them means un-ignoring the files and accepting an encrypted secret in a public repo.

## Alternatives considered

- **Commit `credentials.yml.enc` and gitignore only the key.** Rejected: it is the Rails
  default and defensible, but it publishes an encrypted secret that nothing in this app reads.
  Deleting it removes the question entirely.
