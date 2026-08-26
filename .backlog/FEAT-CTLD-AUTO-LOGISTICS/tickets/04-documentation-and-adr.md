---
Status: ✅ done
---

# 04 — Documentation, and amend ADR 0016

## Do

- `doc/mission-maker/GUIDE.md` + `.en.md`, CTLD section: what automatic logistics management is,
  which types it covers, that it merges rather than replaces, and when to turn it off. It belongs
  next to the existing "the file is a **complete** configuration" note, which is the rule that makes
  an empty list dangerous in the first place.
- `doc/MISSION_YAML_REFERENCE.md` + `.en.md`: the flag, its default, its shape.
- **`docs/adr/0016-ctld2-sidecar-configuration.md`**: amend, do not rewrite history. Two statements
  stop being true — that `mission.yaml` keeps only an on/off flag for CTLD, and that the sidecar is
  injected verbatim. Record why the exception was made and why it is a union: the ADR's own argument
  against a second configuration channel is what rules out overwriting.
- `CHANGELOG.md` entry, under whatever the version convention is at merge time — the
  `CHORE-VERSION-AT-MERGE` lot may have replaced the per-PR version heading with
  `[Unreleased]` by then. Not linked: that lot is not on `develop` yet.

## Done when

`poetry run docs-check` is green and a reader of the guide can tell, without reading any code,
what their mission will do with an empty list.
