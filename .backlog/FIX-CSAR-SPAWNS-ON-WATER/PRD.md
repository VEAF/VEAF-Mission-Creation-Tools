# FIX-CSAR-SPAWNS-ON-WATER — the downed pilot is placed 50 m away and nobody checks what is there

Status: ⬜ ready

Follow-up to [`FEAT-SMOKE-CSAR-WATER`](../FEAT-SMOKE-CSAR-WATER/PRD.md), which shipped the assertions
that measure this. Addresses [#245](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/245).

## The defect, read in the code

`csar.spawnGroup` (`src/scripts/community/CSAR.lua:1041`):

```lua
_group.units[1] = csar.createUnit(_pos.x + 50, _pos.z + 50, 120, "Soldier M4")
```

A **fixed +50/+50 offset with no surface test**. A pilot ejecting over water, or 50 m from a shoreline,
is placed wherever that arithmetic lands. `veaf.findSpawnPoint` — which knows about water and scenery
since `FEAT-SCENERY-AWARE-SPAWN` — is never consulted. Same shape as `FIX-FARP-ESCORT-PLACEMENT`.

## Do not edit the vendored file

`CSAR.lua` is vendored `adapted` from `VEAF/DCS-CSAR` (`vendored.yaml`), and its documented update
procedure is *"pull the latest ciribob CSAR.lua, re-apply the VEAF adaptations"*. An edit made here is an
adaptation nobody recorded, and **the next update erases it**.

The clean path: `veaf.csar_initialize_replacement` (`veaf.lua:5467`) already replaces `csar` functions
from VEAF code — `csar.logError`, `csar.logInfo`, `csar.logDebug`, `csar.logTrace`. Replacing
`csar.spawnGroup` there survives a vendored update and touches no third-party file.

## Open question for the implementation

**What should a pilot over open ocean do?** Moving him to the nearest land could be kilometres away,
which is not a rescue mission any more — it is teleportation. Leaving him on the water may be right if
CSAR supports a raft, and wrong if it does not. Worth settling before coding: the sensible default is
probably "nearest dry point within a bounded radius, otherwise leave him where he is", so a ditching at
sea stays a ditching at sea instead of becoming a walk inland.

## Definition of done

- [ ] Run the two `csar-avoids-water` checks first: they say what actually happens today
- [ ] The over-ocean question settled, with David
- [ ] `csar.spawnGroup` replaced from `veaf.csar_initialize_replacement`, not patched in the vendored file
- [ ] The two harness checks pass, and stay as the regression guard
- [ ] Lua tests over the replacement, since the harness needs DCS and unit tests do not
