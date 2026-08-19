# MIGRATE-DEMO-MISSION-V6 — the demonstration mission is still v5

Status: ✅ done 2026-08-15 — both tickets shipped: migration tests own a frozen v5 fixture, the demo is
v6 (validates clean, builds), and it demonstrates a delayed custom script plus YAML combat zones. A
validator gap surfaced (SANCTUARY polygon_units accepting group names) was fixed at the root.

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
| 01 | Free the migration tests from the demo | ✅ |
| 02 | Convert the demo to v6, and make it demonstrate v6 | ✅ |

## Definition of Done

- `test/veaf-tools/demo-mission/` has a `mission.yaml` and builds with `veaf-tools mission build`.
- The two migration tests still cover the v5 → v6 path, from fixtures they own.
- The demo *shows* v6: at least one thing a v5 mission could not declare (a `modules:` block, a combat
  zone in YAML, radio presets in the preset-plan model).
- Full Python gate green; `veaf-tools mission validate` clean on the folder.

## Not in scope

Publishing the demo as a release asset. It is not one today — checked — and making it one is a
separate decision.

---

## 01 — Free the migration tests from the demo

Status: ✅ done 2026-08-15 — migration tests moved to a frozen v5 fixture; the demo could then convert cleanly.
Type: refactor
Files: `test/python/mission_builder/test_config_migrator.py`,
`test/python/mission_builder/test_presets_schema_migrator.py`, new fixtures under `test/fixtures/`

### Why first

The demo cannot move to v6 while two tests read it *as a v5 artifact*. Doing this first means ticket
02 is a conversion and nothing else.

### The work

Give each migration test a **minimal v5 fixture it owns**: one `missionConfig.lua` and one
`presets.yaml`, carrying the shapes the tests actually assert rather than a whole mission's worth of
content. `test_config_migrator.py:1087` runs an end-to-end migration of the fixture folder, so that
one needs a small v5 *folder*, not just a file.

Keep the coverage identical — this is a fixture move, not a rewrite. `FIX-CONVERT-V5-PRESETS-SCHEMA`
found six renames by walking the demo's presets file, and every one of them must still be exercised.

### Careful

`test_edit_zone.py` reads `veaf-demo-mission.miz` for a zone's field layout and does not care about the
mission's version. Leave it alone; ticket 02 must keep a built `.miz` at that path.

### Acceptance criteria

- [ ] Neither migration test reads `test/veaf-tools/demo-mission/`.
- [ ] The six presets renames and the config migration are still asserted, from the new fixtures.
- [ ] Full Python gate green, coverage ratchet respected.

---

## 02 — Convert the demo to v6, and make it demonstrate v6

Status: ✅ done 2026-08-15 — converted to v6, validates clean, builds; demonstrates a delayed custom script + YAML combat zones/operation; validator SANCTUARY group-name fix.
Type: feat
Files: `test/veaf-tools/demo-mission/**`

### The conversion

`veaf-tools convert v5` on the folder — it is in-place and promotes `src/mission/` too. Then read the
generated `mission.yaml` rather than trusting it: this repository's own history is a list of things
that conversion got subtly wrong (`FIX-CONVERT-V5-PRESETS`, `FIX-CONVERT-V5-OPERATION-SUBZONES`,
`FIX-BRIEFING-MULTILINE`, `FIX-CONVERT-SPAWNABLES-FLAT-FORMAT`).

Rebuild and keep a built `.miz` where `test_edit_zone.py` expects one.

### Then make it worth opening

A converted v5 mission demonstrates v5 with v6 syntax. The demo should show at least one thing a v5
mission could not declare — pick from what shipped since:

- a `modules:` block with a third-party module and its sidecar config;
- a combat zone declared in YAML rather than built by hand;
- radio presets in the **preset-plan** model, which is the whole point of `FEAT-RADIO-PRESET-PROJECTION`;
- `custom_scripts:` with a `delay_seconds:`, the feature `FEAT-CUSTOM-SCRIPT-LOAD-DELAY` added and
  which is invisible in every shipped example.

Say in the mission's own README which v6 feature it is there to show, so the next person does not have
to diff it against a v5 mission to find out.

### Acceptance criteria

- [ ] `mission.yaml` present; `veaf-tools mission validate` clean; `mission build` produces a `.miz`.
- [ ] At least one v6-only feature declared, and named in the folder's README.
- [ ] `test_edit_zone.py` still finds its `.miz`.
- [ ] Full Python gate green.
