# FIX-GROUP-CONTAINER-SHAPE — eight places assume a group container is a list

Status: ⬜ ready

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

## Definition of done

- [ ] A dict-shaped or empty group container no longer breaks the build
- [ ] Normalisation happens once, at load, not in eight readers
- [ ] Round-trip identity **measured** and recorded, as it was for warehouses
- [ ] A mission that nobody touched builds byte-identically
- [ ] The chosen normal form, and why it differs from the warehouses choice, written here
