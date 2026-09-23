# 03 — A selective pull command

Status: ✅ done

## Problem

A maker who owns a catalogue gets nothing new, ever. He needs to see what the shipped one has that
he does not, and take what he wants — *"de manière sélective, pas brutalement tous les defaults"*.

## Work

A third sub-command beside `extract-aircraft-groups` and `inject-aircraft-groups`
(`veaf_tools/commands/aircraft_groups.py`).

- With no argument: report the delta. What the shipped catalogue has and the mission's file does
  not, by group name, grouped by coalition. Read-only.
- `--add "<name>" [--add …]`: copy those entries in.
- `--add-new`: copy in every entry the mission's file does not have.
- **Never touches an entry the mission already owns**, even when the shipped one differs. His
  versions stay his. Say so in the report — an entry present on both sides is listed as kept, not
  hidden.
- Ids are not a concern here: the file is a catalogue, and `FIX-DYNSLOT-WIRING` ticket 01 makes
  injection reallocate on collision.

`_merge_over` already exists for this shape, with the opposite polarity (the incoming entry wins).
Either give it a direction argument or write the mirror beside it; do not silently flip it — the
extractor's `--merge` depends on today's behaviour.

## Tests

- Delta on a mission file missing 24 entries → the 24 are listed, the shared ones reported as kept.
- `--add` with one name → that one entry appears, nothing else moves.
- `--add-new` → every missing entry appears, and an entry the maker had with different content is
  **unchanged**.
- `--add` with a name the shipped catalogue does not have → a clear error, nothing written.
- A maker who deleted an entry on purpose and runs neither flag keeps it deleted.
