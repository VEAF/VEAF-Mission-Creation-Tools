# CHORE-VENDOR-CTLD-RC15 — take CTLD 2.0.0-rc15

Status: ✅ done — 2026-10-27 (PR pending)

`published-v2.0.0-rc15` shipped on 2026-10-27, cut so that VMCT can ship the Fat Cow in its next release.
A verbatim sync, done the way `CHORE-VENDOR-CTLD-RC12` did it, plus the catalogue-gap change rc15 calls for.
rc14 shipped the same day and was never vendored: vendoring it showed that the Fat Cow did not work on the Open Trainings, and rc15 is the fix.

## What rc15 changes in the engine

- **The Fat Cow** (VEAF/CTLD#273, rc14): a CH-47 that lands in the field and becomes a forward refuel and rearm point, player-flown or AI, with ready-made loadouts (Apache, Russian, Mixed).
  Its FARPs are named `CTLD_FatCow_FARP_<n>`, which GRASS leaves alone since `FIX-FATCOW-CTLD-FARPS` (#1202).
- JTAC radio messages go through the translation dictionaries; packing a FARP and Unpack Crate no longer announce a success that did not happen (rc14).
- **The embedded configuration catalogue moves to `2.3.0`**: seven new `fatCow*` settings, four of them lists, the Fat Cow on by default.
- **A list newer than the mission's configuration takes its default** (VEAF/CTLD#275, rc15, CTLD ADR 0011 Addendum 3).
  CTLD reads an omitted list as removed on purpose; a configuration written at `2.2.0` never had the Fat Cow lists, so in rc14 the Fat Cow had no aircraft, crate or loadout.
  rc15 embeds `ctld.configListSince` (the version each list appeared in) and gives a newer list its default.

## The catalogue gap in VMCT

`find_catalogue_gap` and `upgrade_to_catalogue` left every list alone: a missing list is a removal.
`ctld-upgrade` would therefore have added the three Fat Cow parameters, stamped `2.3.0`, and turned the four missing lists into removals for good, which rc15's engine would then respect.
They now read `ctld.configListSince` from the vendored engine (`read_list_since`): a list newer than the mission's `configVersion` is missing, `validate` names it, `ctld-upgrade` writes it in.

| mission | effect |
|---|---|
| no `ctld-config.yaml` | CTLD runs on its embedded defaults → the Fat Cow is on |
| scaffolded by `prepare` from now on | the new catalogue is copied in → the Fat Cow is on |
| existing `ctld-config.yaml` (`2.2.0`) | CTLD gives the four lists their default and says so at start; `validate` warns, `ctld-upgrade` writes the seven settings in |

`test_ctld_catalogue_gap.py::test_the_upgrade_only_adds_lines` reads the vendored catalogue: its expected `configVersion` line moves from `2.2.0` to `2.3.0`.

## Measured

- The vendored file is the published asset with its line endings normalised (CRLF → LF), 1 359 535 bytes, SHA-256 `f1ddafaaabee6d8d…`; `ctld.VERSION` reads `2.0.0-rc15`, `ctld.configListSince` dates `fatCowAICows`, `fatCowCrates`, `fatCowLoadouts` and `fatCowTypes` at `2.3.0`.
- `poetry run test-lua`, the whole Python suite, `poetry run check-vendored`: see the PR.

## Definition of done

- `src/scripts/community/CTLD.lua` is the rc15 asset verbatim, in LF.
- `vendored.yaml` pins `2.0.0-rc15` and watches `published-v2.0.0-rc15`.
- `validate` and `ctld-upgrade` treat a list newer than the mission as missing.
- The whole Lua and Python suites green.
- Docs (`GUIDE`, the catalogue-gap message, FR + EN) and `CHANGELOG.md` under `[Unreleased]`.
- No version bump — §9.5.

## Not claimed

The rc15 file has not been flown from this repository.
The Open Trainings published on 2026-10-27 run rc14 with their `ctld-config.yaml` completed by hand to `2.3.0`; their in-game check is still due (VEAF/CTLD `FEAT-FAT-COW` ticket 06).

## Out of scope

- Committing the Open Trainings' completed `ctld-config.yaml` in their own repositories.
- The Fat Cow step of the demo mission: `FIX-FATCOW-CTLD-FARPS` ticket 02, before the next release.
