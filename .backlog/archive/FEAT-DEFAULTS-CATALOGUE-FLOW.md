# FEAT-DEFAULTS-CATALOGUE-FLOW — a shipped catalogue that never reaches an existing mission

Status: ✅ done · archived 2026-09-28

Opened 2026-09-22, alongside [`FIX-DYNSLOT-WIRING`](FIX-DYNSLOT-WIRING.md) and sequenced
after it. Where that lot fixes the wiring, this one fixes how a catalogue is **produced** and how it
**reaches** a mission.

## Measured

`prepare` copies `src/defaults/mission-folder/` into the mission folder, and never replaces an
existing file without being told to. So `src/dynamic-slot-templates.yaml` is a **full 351 KB
duplicate**, frozen on the day the folder was created. A new folder prepared today gets all 128
templates; a folder prepared in June keeps its 104 and will keep them forever.

The `F-14BU Template` entered the catalogue on 2026-09-21 (`b03ac841`) and shipped in v6.24.0, tagged
the same evening. A mission maker who updates the tool still does not get it, because the tool is not
where his catalogue lives. That is the shape of the report this investigation started from.

Two mission folders on this machine already show the drift: `VEAF-Demo-Mission` and
`VEAF-Open-Training-Mission-Caucasus` both carry a 62-byte empty placeholder while the shipped
catalogue is 351 KB.

## Decision

David, 2026-09-22, in two steps — the second corrects the first:

- the shipped catalogue is used automatically when the mission folder has **no file, or an empty
  one** (a new mission, or one that never configured this);
- when the maker **has** a file, it stands alone. Nothing is merged behind his back;
- and he gets an explicit, **selective** way to pull in what the shipped catalogue has and he does
  not — entry by entry, never overwriting one he already owns. *"il faut un moyen pour le Mission
  Maker de reprendre les nouveaux defaults — mais de manière sélective, pas brutalement tous les
  defaults."*

This is the ADR 0005 model (framework data in `published.zip`, per-mission file as a delta) with one
deliberate difference: the merge is **not** automatic, and the existing entry wins.

## Scope

| # | ticket | |
|---|---|---|
| 01 | [Use the shipped catalogue when the mission file is absent or empty](FEAT-DEFAULTS-CATALOGUE-FLOW.md) | |
| 02 | [`prepare` stops laying down a full copy](FEAT-DEFAULTS-CATALOGUE-FLOW.md) | |
| 03 | [A selective pull command](FEAT-DEFAULTS-CATALOGUE-FLOW.md) | |

## Definition of done

- A mission folder with no aircraft catalogue builds with the shipped one, and the build says which
  it used.
- A mission folder with its own catalogue builds exactly as it does today.
- A maker can list what the shipped catalogue has that he does not, and take named entries or all
  the missing ones, with his own entries untouched.
- Documentation in both languages, `nav` entries included, and `docs-check` green.

---

## Tickets, in full

## 01 — Use the shipped catalogue when the mission file is absent or empty

Status: ✅ done

### Problem

The build reads `src/dynamic-slot-templates.yaml` and `src/spawnables.yaml` from the mission folder
and nowhere else. A folder without them injects nothing; a folder with a stale copy injects the
stale copy. The shipped catalogue sitting in `published/src/defaults/mission-folder/src/` is never
consulted at build time.

### Work

For each of the two aircraft-group steps, resolve the catalogue in this order:

1. the mission folder's file, when it exists **and carries at least one group**;
2. otherwise the shipped one, under `published/src/defaults/mission-folder/src/`, the same path
   `prepare` already resolves (`_defaults_source_candidates`).

An empty file (`airplanes: { coalitions: {} }`, the 62-byte placeholder two mission folders on this
machine already carry) counts as absent. Say so in the file's own header comment: a maker must not
read the empty skeleton as a way to disable the step — `dynamic_slot_templates: false` is.

The build line must name which catalogue it used and where it came from. Today it prints the path,
which is enough as long as the path is the real one.

### Tests

- No local file → the shipped catalogue is injected, and the step reports the shipped path.
- Empty local file → same.
- Local file with one group → only that group is injected, the shipped one is not consulted.
- `dynamic_slot_templates: false` → nothing is injected, whatever exists on disk.

---

## 02 — `prepare` stops laying down a full copy

Status: ✅ done

### Problem

`prepare` copies the whole `src/defaults/mission-folder/` tree, so a new mission folder receives a
351 KB duplicate of the dynamic-slot catalogue and a 286 KB duplicate of the spawnables. That copy
is what freezes: it is read by every later build and nothing ever refreshes it.

Once ticket 01 is in, the copy buys nothing — an absent file already means "use the shipped one".

### Work

- `prepare` writes the empty skeleton for the two aircraft catalogues instead of the full file.
- The skeleton carries a header comment saying what it means: empty = *I add nothing to the shipped
  catalogue*, not *I want nothing*; and pointing at the pull command of ticket 03.
- Existing folders are untouched — `prepare` already never overwrites without being told.

### Tests

- `prepare` on an empty folder → the two catalogues are the skeleton, and a build of that folder
  injects the shipped catalogue in full (the ticket 01 path).
- `prepare` on a folder that already has a populated catalogue → it is kept, as today.

---

## 03 — A selective pull command

Status: ✅ done

### Problem

A maker who owns a catalogue gets nothing new, ever. He needs to see what the shipped one has that
he does not, and take what he wants — *"de manière sélective, pas brutalement tous les defaults"*.

### Work

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

### Tests

- Delta on a mission file missing 24 entries → the 24 are listed, the shared ones reported as kept.
- `--add` with one name → that one entry appears, nothing else moves.
- `--add-new` → every missing entry appears, and an entry the maker had with different content is
  **unchanged**.
- `--add` with a name the shipped catalogue does not have → a clear error, nothing written.
- A maker who deleted an entry on purpose and runs neither flag keeps it deleted.

---
