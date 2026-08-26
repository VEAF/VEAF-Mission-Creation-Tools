---
Status: ✅ done
---

# 02 — A test, so the rule cannot rot back

A written rule that three documents already contradict needs an executable guard.

## Do

Add `test/python/test_changelog_process.py`:

- `## [Unreleased]` exists in `CHANGELOG.md`. This is the check that actually bites: it fails the
  moment a release commit forgets to re-open the section, which is how the section vanished after
  6.15.0 in the first place.
- The version in `pyproject.toml` has a matching `## [<version>]` heading in `CHANGELOG.md`. Ties
  the number to a documented release rather than to a PR.

Keep `test_plugin_version.py` untouched — manifest ↔ pyproject lockstep is still wanted, it just
fires once per release.

## Done when

Deleting the `[Unreleased]` heading turns the suite red, and the coverage gate is bumped if the
measured figure moves more than ~2 points above it.
