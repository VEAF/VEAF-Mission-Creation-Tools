# 02 — A teleport stops carrying the editor's cold-and-dark

Status: ✅ done

Type: fix

## The defect

Ticket 05 added `uncontrolled` and `hidden` to the mission record so a **clone** and a **respawn**
would carry what the Mission Editor set — correct, and what MiST's editor database did.

But `veafDcsSpawner.getCurrentGroupData`, which the **teleport** verb reads, starts from that same
record and overwrites only `name`, `groupId`, `category` and `units`. So both fields now flow into a
teleport, where MiST did the exact opposite: for any group it had not created itself — i.e. every
editor group — it forced them off ([`mist.lua:1040`](../../../src/scripts/community/mist.lua)):

```lua
if gfound == false then
  newTable.uncontrolled = false
  newTable.hidden = false
end
```

Verified: `grep` of the merged tree confirms the record now carries both, and nothing on the teleport
path clears them.

## What a mission maker sees

An aircraft parked cold and dark in the editor, moved by `_move group`, `veafSpawnObjects` or an
escort teleport, arrived flyable up to 6.19.0 and arrives cold now. A group hidden from the F10 map
stays hidden after being moved.

David's call, 2026-09-07: restore the previous behaviour. Nobody asked for the change, and an aircraft
that arrives unusable is hard to diagnose from the cockpit.

## The fix

`getCurrentGroupData` clears `uncontrolled` and `hidden` after copying the record — MiST's rule, at
MiST's place. Not by removing them from the record, which would undo ticket 05 for the clone and the
respawn that need them.

## Definition of done

- [x] A teleported editor group is submitted controlled and visible, whatever the editor set
- [x] A **clone** and a **respawn** still carry both fields — one test per verb, so the three cannot
      be collapsed into one behaviour by the next reader
- [x] `stylua --check` clean; `luacheck` via CI; Lua coverage floor per the ratchet
