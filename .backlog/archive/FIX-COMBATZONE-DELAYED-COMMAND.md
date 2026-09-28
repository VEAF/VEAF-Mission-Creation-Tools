# FIX-COMBATZONE-DELAYED-COMMAND — a delayed command's group outlives its zone

Status: ✅ done · archived 2026-09-28

Verified in game on 2026-08-22: check 8 of `verify-mission-c` — a delayed `#command` dies with its zone. The mission's `DelayZone` carries one fake unit per delay mechanism side by side, which is what made the difference observable rather than argued.

Written, unit-tested and shipped in 6.15.9. Waiting on check 8 of `verify-mission-c`, which needs DCS
started — see [DCS-SESSION-TODO.md](../../DCS-SESSION-TODO.md).

Origin: `CHORE-ISSUE-VERIFY-SESSION` check 8, confirmed in DCS by David on 2026-08-18. Closes
[#66](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/66), open since the v5 era.

## The defect, and it is visible in the code

A combat zone can carry a VEAF command on a fake unit — `#command="-samsr!30"`, the `!30` being a
delay. The zone runs it through `veafInterpreter.execute`, passing a `spawnedGroups` table it then
iterates to register what was created (`veafCombatZone.lua:1117`).

With a delay, `veafShortcuts.ExecuteAlias` hands the work to `mist.scheduleFunction` and **returns
immediately** (`veafShortcuts.lua:540`). The table is still empty when the zone reads it. The group
appears 30 seconds later, registered nowhere — so `VeafCombatZone:desactivate()`, which destroys
`getSpawnedGroups()`, cannot destroy it. The SAM survives the zone that spawned it.

The zone's own `#spawndelay=30` does not have the problem: it delays `spawnElement`, which registers
the group on the way through. Two delay mechanisms, one broken — the verification mission carries
**both**, side by side, so the difference is observable rather than argued.

## What ships — neither of the two shapes this PRD proposed

The PRD offered a callback threaded through `ExecuteAlias` (preferred) or the zone owning the delay
itself, and asked for the choice to be written down. Reading the code turned up two facts that ruled
out both.

**The table is not lost.** It is passed by reference into the deferred call and *is* filled thirty
seconds later ([`veafShortcuts.lua:541`](../../src/scripts/veaf/veafShortcuts.lua:541)). Nobody reads it
again. So this is a notification problem, not a plumbing one.

**And there are three deferring paths, not one** — this PRD's premise, "the delayed-alias path", is
only the first:

| Path | Where |
|---|---|
| an alias delay (`-samsr!30`) | [`veafShortcuts.lua:541`](../../src/scripts/veaf/veafShortcuts.lua:541) |
| a spawn's `delay` option | [`veafSpawnCore.lua:268`](../../src/scripts/veaf/veafSpawnCore.lua:268) |
| a spawn's repeats | [`veafSpawnCore.lua:302`](../../src/scripts/veaf/veafSpawnCore.lua:302) |

So a zone also lost the groups of every repeat past the first. That kills the "zone owns the delay"
option, which would have fixed one path of three — `#command="-spawn …, delay 30"` goes through
`veafSpawnCore` and would have stayed lossy. And the threaded callback would have cost a seventh
parameter on two dispatchers, **nine registered command handlers** sharing one signature, and two more
functions — for a defect with exactly **one** insertion point.

`table.insert(spawnedGroups, …)` appears **once in the whole repository**
([`veafSpawnCore.lua:451`](../../src/scripts/veaf/veafSpawnCore.lua:451)), so the notification went
there: `veaf.collectSpawnedGroup` inserts and notifies, `veaf.registerSpawnedGroupsHook` records the
interest, and the zone registers a hook instead of iterating. All three paths fixed, no signature
touched.

The hook lives in a weak-keyed registry rather than on the table, because eleven call sites iterate
group tables with `pairs`. A metatable `__newindex` was **measured and rejected**: in Lua 5.1
`table.insert` bypasses it entirely.

## Definition of done

- [x] A group spawned by a delayed `#command` is registered with its zone and destroyed on deactivation
- [x] The same now holds for a spawn's `delay` option and for its repeats
- [x] `#spawndelay` keeps working exactly as it does now — untouched; it delays the zone element, which
      registers on the way through
- [x] A group appearing *after* its zone was deactivated is destroyed rather than registered
- [x] Lua tests covering both delay mechanisms — 20 new ones, mutation-checked (suppressing the
      notification fails 5 of them)
- [ ] Re-run check 8 of `verify-mission-c`: the zone `DelayZone` already carries one fake unit per
      mechanism
- [ ] #66 closed citing the reproduction and this cause

---

## Tickets, in full

## 01 — A caller learns about a group whenever it is created, not only synchronously

Status: ✅ done
Type: fix

Closes [#66](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/66), open since the v5 era,
confirmed in DCS by David on 2026-08-18.

### The defect

A combat zone can carry a VEAF command on a fake unit — `#command="-samsr!30"`, the `!30` being a
delay. The zone passes a `spawnedGroups` table down and iterates it on the next line to register what
was created ([`veafCombatZone.lua:1160-1170`](../../src/scripts/veaf/veafCombatZone.lua:1160)):

```lua
local spawnedGroups = {}
veafInterpreter.execute(zoneElement:getVeafCommand(), position, zoneElement:getCoalition(), nil, spawnedGroups)
for _, newGroup in pairs(spawnedGroups) do
```

With a delay, the work is handed to `mist.scheduleFunction` and the call returns immediately. The table
is empty when the zone reads it, so the group is registered nowhere — and
`VeafCombatZone:desactivate()`, which destroys `getSpawnedGroups()`, cannot destroy it. The SAM
outlives the zone that spawned it.

### What the investigation changed, and it decides the fix

**The table is not lost — it is passed by reference into the deferred call** and *is* filled 30 seconds
later ([`veafShortcuts.lua:541-545`](../../src/scripts/veaf/veafShortcuts.lua:541)). Nobody reads it
again. So this is a notification problem, not a plumbing one.

**And there are three deferring paths, not one.** #66 measured the first; the other two have the same
shape and nobody had noticed:

| Path | Where |
|---|---|
| an alias delay (`-samsr!30`) | [`veafShortcuts.lua:541`](../../src/scripts/veaf/veafShortcuts.lua:541) |
| a spawn's `delay` option (`allowStartDelay`) | [`veafSpawnCore.lua:268`](../../src/scripts/veaf/veafSpawnCore.lua:268) |
| a spawn's repeats (`repeatCount` / `repeatDelay`) | [`veafSpawnCore.lua:302`](../../src/scripts/veaf/veafSpawnCore.lua:302) |

A combat zone therefore also loses the groups of every repeat past the first.

### Which shape was chosen, and why — the PRD asked for this to be written down

The PRD offered a callback threaded through the chain (preferred) or the zone owning the delay itself.
**Neither.** Measured against the code:

- **The zone owning the delay** fixes only the alias path. `#command="-spawn group, name sa6, delay 30"`
  goes through `veafSpawnCore` and would still be lossy — as would every repeat.
- **A callback threaded through the chain** costs a seventh parameter on
  `veafInterpreter.execute` → `veafCommands.execute` → **9 registered command handlers** sharing the
  `(pos, event, bypass, fromMarker, groups, route)` signature → `veafShortcuts.executeCommand` →
  `ExecuteAlias`. That is a wide change for a defect that has **one** insertion point.

Because `table.insert(spawnedGroups, …)` appears **exactly once in the whole repository**
([`veafSpawnCore.lua:451`](../../src/scripts/veaf/veafSpawnCore.lua:451)), the notification can live
at the insertion instead of in the signatures:

- `veaf.collectSpawnedGroup(tbl, groupName)` inserts **and** notifies whoever registered interest in
  that table.
- `veaf.registerSpawnedGroupsHook(tbl, fn)` records that interest.
- The zone registers a hook instead of iterating, and its hook runs whether the group appears now or
  in thirty seconds. All three deferring paths are fixed at once, and no signature changes.

**The hook is not stored on the table.** It lives in a separate registry keyed by the table itself,
with `__mode = "k"` so a finished collection is collectable. That matters: eleven call sites iterate
group tables with `pairs`, and a `tbl.onSpawn` field would show up in every one of them.

**A metatable `__newindex` on the table was measured and rejected**: in Lua 5.1 `table.insert` bypasses
`__newindex` entirely (only a plain assignment triggers it), so an observer would have seen nothing.
Verified with the local Lua 5.1 rather than assumed.

### Definition of done

- [ ] A group spawned by a delayed `#command` is registered with its zone and destroyed on deactivation
- [ ] The same holds for a spawn's `delay` option and for its repeats
- [ ] `#spawndelay` keeps working exactly as it does now — it delays `spawnElement`, which registers on
      the way through, and must not be touched
- [ ] A caller that registers no hook keeps today's behaviour (the table is still filled)
- [ ] Lua tests covering both delay mechanisms, since the fix must not make the working one worse
- [ ] Re-run check 8 of `verify-mission-c`: the zone `DelayZone` already carries one fake unit per
      mechanism

---
