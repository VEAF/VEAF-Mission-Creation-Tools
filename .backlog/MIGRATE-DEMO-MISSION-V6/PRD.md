# MIGRATE-DEMO-MISSION-V6 — the demonstration mission is still v5

Status: ⬜ ready

Origin: David, 2026-08-14, while preparing the DCS verification session: *"il faudrait la passer en v6
avant notre release aussi"*. Found the same afternoon from the other side — looking for a v6 mission to
build for that session and finding none on the workstation.

## The state

`test/veaf-tools/demo-mission/` is **v5 in structure**: no `mission.yaml`, a `src/scripts/missionConfig.lua`,
and the v5 sibling folders (`spawnableAircrafts/`, `waypoints/`, `weatherAndTime/`). Its built
`.miz` files are `veaf-demo-mission.miz` (2.3 MB) and `veaf-demo-mission_20251016.miz`.

Shipping v6 tooling beside a v5 demonstration is incoherent, and it is the first thing a new mission
maker opens.

## The constraint that shapes the lot

**The demo is a deliberate v5 fixture for two migration tests**, and converting it in place would break
the tests whose whole purpose is proving we can migrate *from* v5:

| Test | What it reads | Why it needs v5 |
|---|---|---|
| `test_config_migrator.py:40` | `src/scripts/missionConfig.lua` | migrates the v5 config to a v6 `mission.yaml`; also runs an end-to-end migration of the whole fixture (`:1087`) |
| `test_presets_schema_migrator.py:180` | `src/presets.yaml` | migrates the v5 presets schema; `FIX-CONVERT-V5-PRESETS-SCHEMA` found **six** renames walking this very file |
| `test_edit_zone.py:8` | `veaf-demo-mission.miz` | reads a zone's shape — version-agnostic, unaffected |

So a plain `convert-v5` on the folder is **not** the deliverable. Two ways out, and the choice is the
first ticket's job:

- **a — give the migration tests their own minimal v5 fixtures**, and convert the demo. The fixtures
  become small and purpose-built (one `missionConfig.lua`, one `presets.yaml`), which is what they
  should have been: sharing a fixture between "the user-facing demo" and "our v5 regression case" is
  exactly what stops the demo from evolving.
- **b — keep a frozen `demo-mission-v5/` beside a new v6 demo.** Cheaper now, and it leaves two demo
  missions in the tree where a newcomer has to guess which one to read.

Recommendation: **a**. The reason the demo is stuck is that it wears two hats.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Free the migration tests from the demo](tickets/01-free-the-migration-tests.md) | ⬜ |
| 02 | [Convert the demo to v6, and make it demonstrate v6](tickets/02-convert-and-enrich.md) | ⬜ |

## Definition of Done

- `test/veaf-tools/demo-mission/` has a `mission.yaml` and builds with `veaf-tools mission build`.
- The two migration tests still cover the v5 → v6 path, from fixtures they own.
- The demo *shows* v6: at least one thing a v5 mission could not declare (a `modules:` block, a combat
  zone in YAML, radio presets in the preset-plan model).
- Full Python gate green; `veaf-tools mission validate` clean on the folder.

## Not in scope

Publishing the demo as a release asset. It is not one today — checked — and making it one is a
separate decision.
