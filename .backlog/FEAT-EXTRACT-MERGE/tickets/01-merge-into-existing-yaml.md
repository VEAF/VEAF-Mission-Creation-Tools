# 01 — Merge into an existing YAML

Status: ✅ done

Type: feat · Files: `src/python/veaf-tools/aircrafts_injector/aircrafts_injector_worker.py`,
`src/python/veaf-tools/veaf_tools/commands/aircraft_groups.py`

## The change

`_write_structure` replaces the file. It must be able to read what is there, merge the extraction
over it, and report what it replaced.

Merge rule, decided: **the mission wins** on a group of the same name, in the same
category / coalition / country. Anything the file holds and the mission does not is preserved
byte-for-byte in meaning. Every replaced group is named in the output.

## Definition of done

- [x] Extracting into a file that holds groups the mission does not have keeps them
- [x] A group present in both is replaced by the mission's version
- [x] Every replacement is **named** in the command output — a silent overwrite of a hand edit is
      the failure this lot exists to prevent
- [x] Extracting into a file that does not exist behaves as today
- [x] An unreadable or malformed target file fails clearly instead of being silently overwritten
- [x] Works for both families (`--kind spawnable` and `--kind dynamic-template`) — the meeting
      named the dynamic templates, but both go through `_write_structure`
- [x] Tests assert the **file content after two successive extractions**, not the in-memory
      structure

## Watch out

`test/python/testlib/upstream_miz.py` builds a synthetic `.miz` (scripts, theatre, staged loaders)
and may be the shortest path to a two-mission test without a real archive. It does not currently
emit aircraft groups — extend it there rather than starting a second fixture builder, if it fits.
