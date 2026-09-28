# FIX-MCP-AUTHORING-GAPS — four defects an agent met authoring one real mission

Status: ✅ done — 2026-08-19, all four tickets. · archived 2026-09-28

Three things the lot found that its tickets had not predicted, each of the same shape — the defect was
one call away from where it was reported:

- **Ticket 01's insertion bug existed three times.** `_append_qra_definition` and `_append_cap_mission`
  append to `mission.yaml` lists exactly as `create_combat_zone` did, so all three now go through one
  comment-aware helper. Fixing only the reported one would have left two known-identical defects in the
  same file.
- **Ticket 03 reached `validate_group_name`**, which reads the mission through
  `set_group_properties`'s own target. A folder read as a zip returns *no zones*, so the combat-zone
  capture check would have been **lost rather than failed** — the exact failure mode this lot is about.
- **Ticket 04's first attempt was wrong on the repo's own terms.** Refusing an unknown aircraft type
  broke two existing tests asserting that a third-party mod is *warned about, not refused*
  (`FIX-MCP-AIRCRAFT-CATEGORY` set that contract in these same two actions). The shipped behaviour
  warns and writes no `fuel` key, so DCS applies its own default instead of an explicit "carry none".

And one thing measured rather than assumed, as ticket 04 asked: the datamine carries `M_fuel_max` on
**all 170 air units and on no other unit**, so the capacity is sourced. `dcsUnits.lua` came out
byte-identical, its renderer naming the fields it emits.

Origin: building `test/veaf-tools/verify-mission-c` on 2026-08-18 (`CHORE-ISSUE-VERIFY-SESSION`). The
mission was authored almost entirely through the MCP actions, which is the point of them. Three times
the actions could not do the job, so the agent opened `src/mission/mission` and edited Lua by hand —
and **every corrupted build of that session came from those hand edits**:

- a group removed by hand left the list numbered `1,3,4`. Lua loads that without complaint; the build
  dies on `AttributeError: 'int' object has no attribute 'get'`, from a parser that only converts a
  table to a list when its keys are `1..n`. The message never names the offending table, and each
  hole fixed reveals the next one — it took three rounds (`group_insertion.max_ids`, then
  `waypoints_injector`) to get a green build.
- a renumbering regex written to repair the first hole matched *any* indentation and silently
  renumbered `units` and `route.points` too, creating two more holes of the same kind.

So this lot is not about convenience. **An action that does not exist is an invitation to corrupt the
mission file**, and the corruption is invisible to Lua, invisible to `git diff`, and reported by a
message that points nowhere near the cause.

The fourth defect is of a different kind and worth more attention than the three others: the action
worked, wrote a valid mission, and produced aircraft that could not fly. It cost two rounds of a DCS
session and was twice attributed to whatever the check under test happened to be about.

## The four holes

| # | What was missing | What the agent did instead |
|---|---|---|
| [01](FIX-MCP-AUTHORING-GAPS.md) | `create_combat_zone` appends its `combat_zones[]` entries after the file's trailing comment block | left it, then moved the entries by hand |
| [02](FIX-MCP-AUTHORING-GAPS.md) | no action removes a group | deleted the Lua block by hand — three corrupted builds |
| [03](FIX-MCP-AUTHORING-GAPS.md) | `edit_route` and the other `miz_path` actions refuse a mission **folder** | hand-wrote a 3-waypoint tanker track and an `Escort` task into `src/mission/mission` |
| [04](FIX-MCP-AUTHORING-GAPS.md) | `add_air_group` writes `fuel = 0` | nothing — it was not noticed until the aircraft flew into the ground, twice |

## Definition of done

- [x] A combat zone created into an existing `combat_zones:` list lands **inside** it, wherever the
      comments sit
- [x] A group can be removed through an action, and removal renumbers what it leaves behind
- [x] `validate_mission` reports a holed numeric table by **path**, so the build never has to
      — **delivered by `FIX-GROUP-CONTAINER-SHAPE` on 2026-08-19, not by this lot.** It was
      ticked here in error when the lot closed: the boxes were flipped in one pass instead of
      one at a time. The reporting belongs where the holes are detected, which is the
      normaliser — a check living in `validate_mission` alone would say nothing to a mission
      maker who never runs the MCP, and would duplicate the traversal.
- [x] The editing actions accept a mission folder wherever `add_group` already does
- [x] Each of the three is covered by a test built from the shape that broke here, not from a
      synthetic one

---

## Tickets, in full

## 01 — `create_combat_zone` appends its zones below the trailing comments

Status: ✅ done — 2026-08-19. The comment was attached to the **last key of the last list item**,
not to the sequence, so a plain `append` wrote below it — and worse than reported: the comment ended
up wedged *inside* the list. Fixed by detaching it and re-attaching it to the new last item
(`mission_tools.mission_yaml_editor.append_to_sequence`). **The same defect was one function away,
twice**: `_append_qra_definition` and `_append_cap_mission` append to `mission.yaml` lists the same
way, so all three now go through the helper.
Type: fix
Files: the `create_combat_zone` implementation under `src/python/veaf-tools/veaf_mission_mcp/`, tests

### What happens

Calling `create_combat_zone` on a `mission.yaml` that already holds a `combat_zones:` list appends
the new entry **after the trailing commented-out block**, not next to the list. Measured on
2026-08-18 while building `verify-mission-c`: the existing list ended at line 154, and the two new
entries landed at line 208 — below `# ── Community scripts (off by default …) ─────`, immediately
before `STTS: false`.

### Why it matters even though it parses

`yaml.safe_load` returns all three zones under `combat_zones`, because comments do not interrupt a
sequence. So nothing breaks — **today**. What breaks is the person: the entries read as if they
belonged to the community-scripts section, and the shipped `mission.yaml` is a reference file that
mission makers edit by hand. An entry sitting under the wrong heading is one a maker moves or
deletes.

It also breaks the file's own contract with `FIX-BUILD-YAML-TRUNCATION`: content near the tail of
the file is exactly what a `--dev-mode` build rewrites.

### Done when

- A zone appended to an existing list is written after the list's **last real item**, before any
  trailing comment block
- A zone created when no `modules.COMBATZONE.combat_zones:` key exists yet still works (the current
  behaviour for that case is fine — do not regress it)
- A test starts from a `mission.yaml` whose `combat_zones:` list is followed by commented-out lines,
  and asserts the insertion point by **line order**, not just by parsing the result — a parse-only
  assertion passes today and would not have caught this

---

## 02 — No action removes a group, so removal is done by hand

Status: ✅ done — 2026-08-19. `remove_group` ships in `veaf_mission_mcp/remove_group.py`: exact name
only, survivors re-keyed `1..n`, and the `group` key dropped rather than left empty. The three
reference checks all landed, and the `Escort` one had to walk **into** a `ComboTask` — that is how DCS
actually nests the task, so a flat read would have found nothing and reported no reference at all. The
`ASSETS` check needs `mission.yaml`, so it only runs on a folder target; a `.miz` gets the two
mission-table checks and no false reassurance about the third.
Type: feat
Files: a new action under `src/python/veaf-tools/veaf_mission_mcp/`, the mission-maker action
catalogue (both languages), tests

Related: [`FIX-GROUP-CONTAINER-SHAPE`](FIX-GROUP-CONTAINER-SHAPE.md) owns the other half —
making the build survive a container that a hand edit left dict-shaped. **This ticket does not
duplicate it**: it removes the reason to hand-edit in the first place.

### What is missing

The catalogue can add a group (`add_group`, `add_air_group`, `add_player_slot`), move it, rename it
and reconfigure it — but not **remove** it. `edit_zone` has `remove: true`, `edit_map_drawing` has
`remove: true`; groups have nothing.

### What that cost, measured

Building `verify-mission-c` on 2026-08-18 needed three removals: an air-start slot inherited from the
forked mission, and twice a player slot that had to be recreated elsewhere. Each was a hand-deleted
Lua block, and each left the enclosing list numbered `1,3,4` — three corrupted builds, each dying on
`AttributeError: 'int' object has no attribute 'get'` at a line pointing nowhere near the edit.

The repair made it worse before it made it better: a renumbering regex keyed on indentation alone also
matched `units` and `route.points` entries, renumbering a one-element `units` list to `[3]` and a
single waypoint to `[2]`. That evidence is written up in `FIX-GROUP-CONTAINER-SHAPE`, since it widens
that lot's scope beyond group containers.

### What ships

A **`remove_group`** action addressing a group by its exact name — refusing a fragment, the way
`set_group_properties` does — that:

- removes the entry and **renumbers the siblings it leaves behind**, so the container stays `1..n`
- removes the `group` key entirely when it takes the last one, rather than leaving an empty container
  (the shape `FIX-GROUP-CONTAINER-SHAPE` opens on)
- **names what it breaks**: a group captured by a combat zone through its name prefix, one named in
  `ASSETS.linked`, or one an `Escort` task points at by group id. Today all three break in silence
- accepts a folder target as well as a `.miz`, per [03](FIX-MCP-AUTHORING-GAPS.md)

### Done when

- `remove_group` removes and renumbers; a test asserts the surviving indices are `1..n`
- Removing the last group of a category removes the key instead of leaving `{}`
- Removing a referenced group warns, naming the reference and where it lives
- A test covers the three real removals this ticket came from: a player slot, an air-start slot, and
  the last group of its category

---

## 03 — The editing actions refuse a mission folder, so durable edits get hand-written

Status: ✅ done — 2026-08-19. `open_mission` / `commit_mission` in `veaf_mission_mcp.mission_folder`
carry the folder-or-`.miz` decision for all seven editing actions, and each now returns `durable` so a
caller can tell which it got — the creating actions always did.

Two things the ticket did not predict. **`validate_group_name` reads the mission too**, through
`set_group_properties`'s own target, so a folder read as a zip would have *silently returned no zones*
— losing the combat-zone capture check rather than failing it; it takes a folder now as well. And the
shared `"Not a valid DCS mission archive"` message had to drop the word *archive*, since the accepted
input is no longer only an archive — one existing test asserted on that wording.

The parameter is still named `miz_path`. Renaming it across seven actions, their schemas, their
docstrings and their tests is churn this ticket did not ask for; the schema description now names both
forms, which is what the calling agent reads.
Type: fix
Files: `src/python/veaf-tools/veaf_mission_mcp/actions.py` (parameter plumbing), the affected action
modules, the mission-maker action catalogue (both languages), tests

### The inconsistency

`add_group`, `add_air_group` and `add_player_slot` take a `target` that is **either** a mission folder
(durable, written into `src/mission/`, survives a rebuild) **or** a `.miz` (transient). Every editing
action next to them — `edit_route`, `set_group_properties`, `set_unit_properties`, `edit_zone`,
`add_trigger_zone`, `add_map_drawing`, `edit_map_drawing` — takes only `miz_path`.

So a group can be *created* durably but not *edited* durably. Pointing `edit_route` at the exploded
folder fails on the filesystem, not with a helpful refusal:

```
[Errno 13] Permission denied: '…/verify-mission-c/src/mission'
```

### What that cost

`verify-mission-c` needed a tanker with a 3-waypoint track (`veafMove._getTankerRouteData` refuses a
shorter route) and an escort whose last waypoint carries an enabled `Escort` task
(`veafMove.teleportEscort` gives up without one). `add_air_group` created both groups durably;
`edit_route` could not touch them. Both routes were therefore hand-written into
`src/mission/mission` — including a task the action set does not model at all — which is how the
mission ended up needing the repairs described in [02](FIX-MCP-AUTHORING-GAPS.md).

### Scope, and what is deliberately not in it

**In:** accept a folder wherever a `.miz` is accepted, resolving to `src/mission/mission`, with the
same backup-first behaviour. The actions already write that file through the same helpers the `add_*`
actions use, so this is plumbing, not new semantics.

**Not in:** adding `Escort` to `edit_route`'s closed task set. That deserves its own measurement —
the task carries a `groupId` DCS assigns and a relative `pos`, and the closed set exists precisely so
a made-up task table is refused rather than silently ignored. Worth a ticket of its own once someone
has a real mission to read the layout from.

### Done when

- Each editing action accepts a folder target, documented in its description the way `add_group`
  documents the trade-off between the two
- A folder path that is not a mission folder is refused with a message that says so, not an `Errno 13`
- A test edits a route through a folder target and asserts the change landed in `src/mission/mission`
  and survives a rebuild

---

## 04 — `add_air_group` creates aircraft with an empty fuel tank

Status: ✅ done — 2026-08-19. The capacity is sourced, not invented: the datamine carries
`M_fuel_max` on **all 170 air units and on no other**, so `dcsUnits.yaml` gained a `fuel_capacity`
field and `dcsUnits.lua` is byte-identical (the Lua renderer names its fields). A type the database
does not know gets **no `fuel` key and a warning** rather than a refusal — the contract
`FIX-MCP-AIRCRAFT-CATEGORY` already set for a mod type in these same two actions, and which a first
attempt at refusing broke in two existing tests.
Type: fix
Files: `src/python/veaf-tools/veaf_mission_mcp/add_air_group.py` (and `player_slot.py`, same payload
builder), tests

### What happens

`add_air_group` writes `payload = { chaff = 0, flare = 0, fuel = 0, gun = 100, pylons = {} }`.
`fuel = 0` means **no fuel at all**.

Measured on 2026-08-18, `verify-mission-c`: a KC-135 and its two F-15C escorts created by
`add_air_group` at 20 000 ft pitched straight into the ground the instant they appeared — engines
out. David's report and screenshot: *"ils piquent vers le sol dès leur apparition"*, the tanker at
-49° of pitch seconds after spawning.

Every VEAF template in the same mission carries the airframe's own capacity — `F-15C: 6103`,
`F-14B: 7348` — so the mission file itself shows what the value should look like.

### Why it is worth a ticket rather than a workaround

It cost two rounds of a DCS verification session, and it cost them **twice**: the first time the
crash was attributed to the SAM battery the tanker was parked next to, the second time it was still
unexplained and left issue #101 inconclusive. A defect that makes an unrelated check fail is worse
than one that fails loudly, because it gets attributed to whatever the check was about.

An air start is the default for `add_air_group` (`start: "air"`), so this is the default path, not an
edge case. A ground start hides it: DCS fuels a parked aircraft from the airfield's stock, which is
why the parked player slots never showed the problem.

### What ships

- A sensible default fuel load. **Full internal fuel** is the honest default for a spawned aircraft,
  and it is what the templates do. The per-type capacity has to come from somewhere: `dcsUnits.lua`
  ships a unit database — check whether it carries the value before inventing a table.
- An optional `fuel` parameter (kg, or a fraction of capacity) for a caller who wants something else.
- Same treatment for `add_player_slot`, which builds its payload the same way. It matters less there
  — a parked slot is fuelled by the airfield — but an air-start player slot has exactly this bug.

### Done when

- An aircraft created by `add_air_group` with an air start has fuel and flies
- The value comes from the shipped unit database rather than a hand-written table, or the reason it
  cannot is written here
- A test asserts a non-zero fuel load for an air start, per category (plane, helicopter)

---
