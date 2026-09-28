# FIX-GROUP-CONTAINER-SHAPE — eight places assume a group container is a list

Status: ✅ done — 2026-08-19, both tickets · archived 2026-09-28

Origin: hit while building the #290 verification mission on 2026-08-17. Same family as
`FIX-WAREHOUSES-LIST-FORM`, one table over.

## What happened

Removing the last group of a coalition left `country["vehicle"]["group"]` as an **empty container**
rather than removing the key. The build then died on a raw traceback:

```
coalition_placeholder.py:136
  country.setdefault("vehicle", {}).setdefault("group", []).append(group)
AttributeError: 'dict' object has no attribute 'append'
```

`setdefault` returns the **existing** value, so the `[]` default never applies: the code gets whatever
is there and calls `.append` on it. An empty dict, or a dict-shaped container, and the build stops with
no message a mission maker can act on.

## Why it is not a one-off

`warehouses.airports` had exactly this shape problem this morning, for the same underlying reason: a
Lua table reaches Python as a **list** when its keys are a contiguous `1..N` and as a **dict**
otherwise, and every reader here picks one and assumes it. Grepped, **eight** sites assume the list
shape for a group container:

| File | Line |
|------|------|
| `mission_builder/coalition_placeholder.py` | 136 |
| `mission_tools/group_insertion.py` | 88, 223 |
| `aircrafts_injector/aircrafts_injector_worker.py` | 698, 1130, 1140, 1181 |
| `waypoints_injector/waypoints_injector_worker.py` | 296 |

A mission is dict-shaped as soon as its group keys are not contiguous — which a hand edit, a
third-party tool, or a deletion produces. None of these eight would say anything useful about it.

## The family is wider than group containers — measured 2026-08-18

Building `verify-mission-c` produced three holed tables, and only the first was a group container:

| Table | How it broke | Where the build died |
|---|---|---|
| `…plane.group` numbered `1,3,4` | a group deleted by hand | `group_insertion.max_ids` |
| `…group.1.units` numbered `[3]` | a repair regex keyed on indentation alone | same |
| `…group.1.route.points` numbered `[2]` | same regex | `waypoints_injector._inject_waypoints_into_group` |

Two consequences for this lot:

- **Normalising `group` containers alone would not have saved that build.** `units` and
  `route.points` are sequences read the same way, by readers that assume a list just as the eight
  listed below do. Whatever normalisation lands should cover the sequence-shaped tables of a mission,
  not one key.
- **The error never names the table.** Each hole surfaced at a different subsystem, the second one in
  a waypoint injector that had nothing to do with the edit. A hole check reporting the offending
  **path** — cheap, and independent of the normalisation itself — is what turns three debugging rounds
  into one line of output. `FIX-MCP-AUTHORING-GAPS` ticket 02 asks for it in `validate_mission`; it
  may well belong here instead. Decide, and cross-reference.

## Scope

Normalise **at load**, the way `FIX-WAREHOUSES-LIST-FORM` did for airfields: a `group` container comes
back from `read_miz` / `read_mission_folder` in one known shape, and the eight readers stop guessing.
That fix is already written and reviewed for warehouses, so this is the same shape of change with the
same argument behind it.

Two things to decide, and to write down:

- **Which shape wins.** Warehouses normalised to a **dict keyed by id**, because DCS keys airfields by
  airdrome id. A group container is a plain sequence, so the honest normal form here is probably a
  **list** — the opposite choice, for a good reason. Say why.
- **Round-trip identity.** The warehouses fix was safe because a dict keyed `1..N` and the list it came
  from serialise **identically** under the build's settings. Measure the same thing here before
  touching anything: if the two forms serialise differently, every untouched mission's diff moves.

Also: an empty container should not exist. Whoever removes the last group should remove the key — worth
a small helper, since this lot exists because I did it by hand and got it wrong.

## The decisions, answered — 2026-08-19

### The normal form is a **list**, and here is why it differs from the warehouses choice

Measured before anything was written, with the settings `write_miz` passes to `luadata.serialize`:

| Question | Answer |
|---|---|
| Does a list serialise like the contiguous `1..N` dict it came from? | **Yes, byte-identical** |
| Does a holed dict serialise with its holes? | **Yes** — `[1]`, `[3]` come back out as written |
| What does the parser return for each? | list → `list`, contiguous dict → `list`, **holed dict → `dict`** |

So the parser already hands back a list whenever the keys are contiguous, which is what makes a list
the free choice here: an untouched mission is unchanged. `FIX-WAREHOUSES-LIST-FORM` chose a **dict keyed
by id** because DCS keys `warehouses.airports` by **airdrome id** — that key carries information. A group
container's key carries nothing but position, so the sequence is the honest form. Opposite choices, same
reasoning applied to different data.

### Round-trip identity, measured — and one claim the PRD implied that does not hold

**The normalisation changes zero bytes.** Asserted over all five mission folders under
`test/veaf-tools/`: serialising a mission with the normalisation applied produces the same bytes as
serialising it without, and none of the repository's missions is holed to begin with.

But *"a mission that nobody touched builds byte-identically"* was already false before this lot, for an
unrelated reason: `write_mission_folder` re-serialises through `luadata` with `sort=True`, so it
reorders keys and re-indents whatever it is handed — as DCS does on every save. A raw diff of an
original against VEAF's output has never been meaningful. What the tests pin instead is the narrower
property that actually matters: **the normalisation adds no change of its own**, and a second write
produces the same bytes as the first.

### The trap: this had to be path-scoped

`payload.pylons` is keyed **by station number** — a real FA-18C carries 1, 4, 5, 6 and 9, and
`describe_units` says so in its own description. Normalising every numeric-keyed dict would have turned
that into positions `1..5` and **silently moved every weapon**. A new silent data-destroyer, of exactly
the family this lot exists to stop. The spec therefore enumerates the sequences from the readers that
already treat them as such, and anything absent from it is left alone.

### A fourth defect, found on the way

`add_group._patrol_task` built its task table as `{"1": …}`, which `luadata` renders as `["1"]` — a
**string** key. Every real mission in this repository writes `[1]`, and in Lua those are different
entries with `#t` at zero for the string one, so a patrol loop written that way is invisible to
anything iterating the list. Found because the normaliser reported it as a holed table. Fixed at the
source, and a digit-string key is now read as its position rather than reported.

### Where the hole reporting belongs — decided

**Here**, not in `validate_mission` alone. `FIX-MCP-AUTHORING-GAPS` asked for it there; a check living
only in the MCP would say nothing to the mission maker who never runs it, and would duplicate the
traversal. The normaliser detects, and both the build and `validate` surface what it found.

## Definition of done

- [x] A dict-shaped or empty group container no longer breaks the build
- [x] Normalisation happens once, at load, not in eight readers
- [x] Round-trip identity **measured** and recorded, as it was for warehouses
- [x] A mission that nobody touched builds byte-identically
- [x] The chosen normal form, and why it differs from the warehouses choice, written here

---

## Tickets, in full

## 01 — Normalise a mission's sequence tables once, at load

Status: ✅ done — 2026-08-19. `mission_tools.sequence_normalisation` normalises on the read path,
so the eight readers stop guessing without eight edits. The path-scoping earned itself: a blanket
"every numeric-keyed table" would have renumbered `payload.pylons` and moved every weapon to a
different station.
Type: fix
Files: `src/python/veaf-tools/mission_tools/miz_tools.py` (the read path), a new normaliser module,
tests

### The three measurements this ticket is built on

Taken 2026-08-19, with the settings `write_miz` actually passes to `luadata.serialize`
(`indent="  "`, `always_provide_keyname=True`, `sort=True`), before touching anything:

| Question | Answer |
|---|---|
| Does a list serialise like the contiguous `1..N` dict it came from? | **Yes, byte-identical** |
| Does a holed dict serialise with its holes? | **Yes** — `[1]`, `[3]` come back out as written |
| What does the parser return for each? | list → `list`, contiguous dict → `list`, **holed dict → `dict`** |

So the parser already hands back a list whenever the keys are contiguous. A reader assuming a list is
right on every well-formed mission and wrong only on a holed one — which is why eight of them have
survived, and why the failure appears at a random subsystem rather than at the edit.

### The chosen normal form: a **list**

The opposite of `FIX-WAREHOUSES-LIST-FORM`'s choice, and for a reason worth writing down: DCS keys
`warehouses.airports` by **airdrome id**, so the key carries information and normalising to a dict
preserves it. A group container's key carries nothing but **position**, so the sequence is the honest
form — and it is already what the parser returns in the nominal case, which is what makes an untouched
mission byte-identical.

### The trap: this must be path-scoped, not "every numeric-keyed table"

`payload.pylons` is keyed **by station number** — a real FA-18C carries stations 1, 4, 5, 6 and 9, and
`describe_units` says so in its own description. Normalising every numeric-keyed dict to a list would
turn `{1, 4, 5, 6, 9}` into positions `1..5` and **silently move every weapon to a different station**:
a new silent data-destroyer, of exactly the family this lot exists to stop.

So the normaliser descends an **explicit spec** of the mission's sequence tables, enumerated from the
readers that already treat them as sequences rather than guessed:

`coalition.<side>.country` · `…country.<category>.group` · `…group.units` · `…group.route.points` ·
`…points.task.params.tasks` (nested, a `ComboTask` holds tasks) · `triggers.zones` ·
`…zones.verticies` · `drawings.layers` · `…layers.objects`

`verticies` is not a typo here: it is **DCS's own misspelling**, and the key a mission file really
carries — every mission under `test/veaf-tools` writes `verticies`, none writes `vertices`. The
correctly spelled key is accepted beside it in case DCS ever repairs its own. (The VEAF MCP's
`vertices` parameter is spelled properly, because that one is our naming rather than the file
format's — which is what makes the pair look like an inconsistency.)

Anything not on that list — `payload.pylons` first among them — is left exactly as it is.

### Done when

- A dict-shaped or holed container is a list by the time any reader sees it
- Normalisation happens **once**, on the read path, not in the eight readers
- `payload.pylons` is provably untouched, station numbering included
- A mission nobody touched round-trips byte-identically, asserted with
  `testlib.writer_preservation.assert_round_trip_identical`
- The eight sites listed in the PRD stop being wrong, without eight edits

---

## 02 — Name the holed table, by path

Status: ✅ done — 2026-08-19. Holes are reported by path — a `validate` warning and a build-time
log line, both through `t()`. Two corrections came out of building it, both caught by this lot's own
principle: an empty container is normalised to an empty **list** rather than having its key removed
(`tasks = {}` is what DCS writes on every waypoint with no task, so dropping it would change a mission
nobody touched), and re-serialising a locale JSON to add one key reordered 17 lines of it.
Type: feat
Files: the normaliser from ticket 01, its callers, tests

### Why closing a hole cannot be silent

Normalising a holed container **renumbers** it: `[1], [3]` becomes `[1], [2]`. That is the right
outcome — it repairs what a hand edit broke, and it is what lets the build finish — but it is still a
change to the file, and this lot exists because writers that change what they were not asked to are
how three defects reached production unnoticed. A normaliser that silently closes holes would be one
more of them.

### What the silence cost, measured 2026-08-18

Building `verify-mission-c` produced three holed tables, and each surfaced somewhere else:

| Holed table | Where the build died | Related to the edit? |
|---|---|---|
| `…plane.group` numbered `1,3,4` | `group_insertion.max_ids` | yes |
| `…group.1.units` numbered `[3]` | same | no |
| `…group.1.route.points` numbered `[2]` | `waypoints_injector._inject_waypoints_into_group` | **no** |

Three debugging rounds, and the message named the table in none of them —
`AttributeError: 'int' object has no attribute 'get'` points at the reader, never at the data.

### What ships

The normaliser reports each hole it closed as a **path**:

```
coalition.blue.country[1].plane.group: keys 1, 3, 4 -> 1..3
coalition.blue.country[1].plane.group[1].units: keys 3 -> 1..1
```

Surfaced where a person will see it: a build-time warning, and in the MCP's `validate_mission` result.

### Where this belongs — decided

`FIX-MCP-AUTHORING-GAPS` ticket 02 asked for the same reporting in `validate_mission`. It belongs
**here**, because here is where the holes are detected — a check living in `validate_mission` alone
would say nothing to the mission maker who never runs it, and would duplicate the traversal. The MCP
surfaces what the normaliser found rather than looking for it a second time. Cross-referenced in that
lot's ticket.

### Done when

- Every hole closed is reported with its full path and its before/after keys
- A build over a holed mission prints them rather than dying, or dying without saying where
- A well-formed mission reports nothing at all — no noise on the nominal path
- `validate_mission` surfaces the same list rather than re-deriving it

---
