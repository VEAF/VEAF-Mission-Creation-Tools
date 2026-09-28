# FEAT-EXTRACT-MERGE — extracting aircraft groups overwrites the file

Status: ✅ done · archived 2026-09-28

Origin: VEAF meeting, 2026-08-30. Shape chosen by David on 2026-08-31.

## The gap

`extract-aircraft-groups` writes its result with `open(path, "w")`
(`aircrafts_injector_worker.py::_write_structure`). Whatever the YAML held is gone.

That makes the command a one-shot: you cannot extract the dynamic-slot templates of a second
mission into the same catalogue, and you cannot re-extract after a Mission Editor change without
losing everything the file gathered before.

## The decision

**The mission wins, and the report says so.** A group extracted from the mission replaces the one
in the file; groups the file holds that the mission does not are kept untouched; every replacement
is named in the run's output, so an overwritten hand edit is never silent.

## Shape

The structure is `{category: {coalitions: {coalition: {country: {group name: data}}}}}` — the merge
happens at the group-name level, inside its category / coalition / country.

Merging is what the meeting asked for; whether it becomes the default or an opt-in flag is the
implementer's call, but **do not silently change what an existing script gets**: today's callers
expect a fresh file. State the choice in the PR.

**Choice made: an opt-in `--merge` flag.** Merging by default would not only change what an
existing caller gets, it would reverse a behaviour some rely on — a template deleted in the
Mission Editor currently disappears from the catalogue at the next extraction, and under a
default merge it would survive there forever and keep being injected. That failure is invisible;
having to type `--merge` is not.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Merge into an existing YAML](FEAT-EXTRACT-MERGE.md) | feat |

---

## Tickets, in full

## 01 — Merge into an existing YAML

Status: ✅ done

Type: feat · Files: `src/python/veaf-tools/aircrafts_injector/aircrafts_injector_worker.py`,
`src/python/veaf-tools/veaf_tools/commands/aircraft_groups.py`

### The change

`_write_structure` replaces the file. It must be able to read what is there, merge the extraction
over it, and report what it replaced.

Merge rule, decided: **the mission wins** on a group of the same name, in the same
category / coalition / country. Anything the file holds and the mission does not is preserved
byte-for-byte in meaning. Every replaced group is named in the output.

### Definition of done

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

### Watch out

`test/python/testlib/upstream_miz.py` builds a synthetic `.miz` (scripts, theatre, staged loaders)
and may be the shortest path to a two-mission test without a real archive. It does not currently
emit aircraft groups — extend it there rather than starting a second fixture builder, if it fits.

---
