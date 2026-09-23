# 01 — Use the shipped catalogue when the mission file is absent or empty

Status: ✅ done

## Problem

The build reads `src/dynamic-slot-templates.yaml` and `src/spawnables.yaml` from the mission folder
and nowhere else. A folder without them injects nothing; a folder with a stale copy injects the
stale copy. The shipped catalogue sitting in `published/src/defaults/mission-folder/src/` is never
consulted at build time.

## Work

For each of the two aircraft-group steps, resolve the catalogue in this order:

1. the mission folder's file, when it exists **and carries at least one group**;
2. otherwise the shipped one, under `published/src/defaults/mission-folder/src/`, the same path
   `prepare` already resolves (`_defaults_source_candidates`).

An empty file (`airplanes: { coalitions: {} }`, the 62-byte placeholder two mission folders on this
machine already carry) counts as absent. Say so in the file's own header comment: a maker must not
read the empty skeleton as a way to disable the step — `dynamic_slot_templates: false` is.

The build line must name which catalogue it used and where it came from. Today it prints the path,
which is enough as long as the path is the real one.

## Tests

- No local file → the shipped catalogue is injected, and the step reports the shipped path.
- Empty local file → same.
- Local file with one group → only that group is injected, the shipped one is not consulted.
- `dynamic_slot_templates: false` → nothing is injected, whatever exists on disk.
