# FEAT-THIRD-PARTY-MODS-003 — Doc + defaults lockstep + changelog

Status: ✅ done
Type: docs
Files: `doc/`, `src/defaults/mission-folder/mission.yaml`, `CHANGELOG.md`, `pyproject.toml`

## What to build

- Document `mission.third_party_mods` in the mission.yaml documentation (FR + EN): what it
  is (DCS third-party aircraft mods to make non-blocking), that it unions with a VEAF default
  list, and the effect (mission loads without the mod; the slot is just unavailable).
- Add a commented `third_party_mods` example to `src/defaults/mission-folder/mission.yaml`
  under the `mission:` block (defaults lockstep).
- CHANGELOG `[Unreleased]` entry; PATCH version bump in `pyproject.toml` + `poetry install`.

## Acceptance criteria

- [ ] Doc updated FR + EN, mentioning the VEAF default list and the union semantics.
- [ ] Commented example present in the shipped default `mission.yaml`.
- [ ] CHANGELOG + version bump done.

## Blocked by

FEAT-THIRD-PARTY-MODS-001, FEAT-THIRD-PARTY-MODS-002.
