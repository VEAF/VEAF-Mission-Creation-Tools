# FIX-FLAKY-AIRDROME-POSITIONS — a dispatch test rewrote the shipped airdrome data under xdist

Status: ✅ done — 2026-10-31

## Symptom

PR #1227, documentation only, went red on `python-quality` with one failure out of about 7 500 tests (run 41191478834, worker `gw3`): `test_build_mission_briefing.py::test_a_text_given_as_one_string_is_split_into_paragraphs_and_a_mission_string_is_prose`.
`airfield_positions` read `airdrome-positions.yaml` and `yaml.safe_load` returned `None`: `AttributeError: 'NoneType' object has no attribute 'get'`.
The same base commit is green on `develop`.

## Cause

`test_update_dcs_data_command.py` invokes `veaf-build update-dcs-data` with the countries, units and radio generators patched, but not the airdromes one.
`--all`, and the no-flag default, also regenerate the airdromes: three of its tests downloaded the dcs-world-schema reference database from GitHub and rewrote the committed `veaf_libs/data/airdromes.yaml` and `airdrome-positions.yaml` in place.
`write_positions_yaml` opens the file for writing — which truncates it —, writes five comment lines, then dumps the table.
A reader on another xdist worker in between gets a comment-only document, which `yaml.safe_load` reads as `None`.
The content written back is identical, so `git status` never showed it.

## Measured

- Before: running the five dispatch tests alone moves the mtime of both committed files, and takes 4.6 s (the downloads).
- Reading the file in a loop beside them: 79 empty reads out of 136 on one run, none on the next two — a race, hence the random red.
- The new guard test fails deterministically before the fix, naming `airdrome-positions.yaml` and `airdromes.yaml`.
- After: the guard passes, the dispatch tests take 0.19 s, the loop reads no empty file.

## Fix

The dispatch tests patch the airdromes generator and the reference download, like the other generators, and a guard test asserts that a `--all` dispatch run leaves every file under `veaf_libs/data` untouched — so a generator added to `--all` later without its patch fails here, not at random elsewhere.

## Not done

- `airfield_positions` does not get an `or {}`: a `None` there means a corrupt shipped file, and failing loud is right.
- The generators still write in place rather than atomically: only a developer runs them, never concurrently with a reader.

## Tickets

- [01 — patch the airdromes generator in the dispatch tests](tickets/01-patch-airdromes-generator.md)
