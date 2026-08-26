---
Status: 🧑 waiting-human
---

# 03 — What version should the `dev` documentation advertise?

`docs_version_stamp.py` stamps `pyproject.toml`'s version onto the pages it rewrites, and
`docs.yml` deploys the `dev` alias on every push to `develop`. Once the version stops moving
between releases, the dev docs will show **the last released version** instead of a per-PR number.

Arguably better — 6.16.8 was never installable by anyone — but it is a visible change on a public
site, so it is David's call, not a side effect to discover after the fact.

## Options

- **Leave it**: dev docs advertise the last release. Simplest, and honest about what is shipped.
- **Stamp `<version>-dev` or `<version>+<short-sha>`**: says "newer than the release, not a
  release", at the cost of a special case in the stamper.

Blocked on that decision; everything else in the lot proceeds without it.
