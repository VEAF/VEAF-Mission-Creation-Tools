# 02 — `addGroupToNetwork` guards its own entry

Status: ✅ done
Type: fix

## Why the guard cannot live in the init alone

`initializeIADS` is one of four ways a group reaches a network. The others are the birth-event
handler (`_integrateDynamicSpawn`, on every spawn while `dynamic_spawn` is on), the radio menu, and
the `_skynet` marker commands. All four end in
[`addGroupToNetwork`](../../../src/scripts/veaf/veafSkynetIadsHelper.lua:763), and the dynamic path
is the one most likely to be handed a corpse: it fires on a **deferred** schedule
(`DelayForDynamicIntegration`), so a group that was spawned and destroyed inside that second — a
combat zone activated and deactivated in quick succession, a `#spawndelay` element whose zone went
down — arrives already dead.

## A second, smaller defect on the same three lines

```lua
function veafSkynet.addGroupToNetwork(networkName, dcsGroup, ...)
  veaf.loggers.get(veafSkynet.Id):debug("ADD GROUP START [" .. dcsGroup:getName() .. "] ...")

  if not dcsGroup then
    veaf.loggers.get(veafSkynet.Id):error("No group to find to add to network")
    return false
  end
```

The `nil` guard sits **after** the dereference that would raise. It has never been able to fire.
Same function, same family of defect (a DCS handle trusted without being checked), so it is fixed
here rather than filed as a separate lot — but it is a guard being made reachable, not a change of
behaviour: a `nil` group still returns `false`, it just no longer raises on the way.

## The fix

At the top of the function, before anything dereferences the handle: refuse a `nil` group, and
refuse a group DCS no longer holds, through the ticket-01 helper. `debug`, not `error`, for the
vanished case — a spawn that died before its integration ran is ordinary mission life, not a fault.

## Definition of done

- [x] the `nil` check precedes every dereference and still returns `false`
- [x] a destroyed group returns `false` and adds nothing, from any caller
- [x] a live group behaves exactly as before — the three existing `TestVeafSkynetAddGroupToNetwork`
      cases stay green untouched
- [x] Lua tests per ticket 04
