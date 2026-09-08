# 01 — the IADS never enrols a group DCS has already destroyed

Status: ✅ done
Type: fix

The root cause of [#946](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/946).

## The defect

[`initializeIADS`](../../../src/scripts/veaf/veafSkynetIadsHelper.lua) enrols the map:

```lua
local dcsGroups = coalition.getGroups(coa)
for _, dcsGroup in pairs(dcsGroups) do
  ...
  veafSkynet.addGroupToNetwork(networkName, dcsGroup, forceEwr, pointDefense, alreadyAddedGroups, true)
```

`coalition.getGroups` can return a group DCS has destroyed. The repository already says so, in the
Skynet compatibility layer, right above the guard that exists **there**
([`skynet-iads-compiled.lua`](../../../src/scripts/community/skynet-iads-compiled.lua)):

> `coalition.getGroups` can hand back a group that has been destroyed, and asking such a group for
> its units raises.

Nothing on the VEAF side guarded, and this loop runs one second after every combat zone has destroyed
the groups standing inside it. Whatever the listing is still carrying at that moment became a SAM
site whose units are gone, hence a site counted in `Raddest` for the rest of the mission.

## Where the guard went, and why not here

`veafSkynet.dcsObjectStillExists` was written for it — with the DCS quirk in its docstring rather than
a restatement of what `isExist` does — and the call sits at the top of
`veafSkynet.addGroupToNetwork`, **not** in this loop. That function is the single door every caller
goes through: the start-up enrolment, the deferred birth-event handler, the radio menu and the
`_skynet` markers. One guard there covers four callers; one guard here would have covered one and
left the dynamic path — the one most likely to be handed a corpse, since it fires on a delay — open.

`not dcsObject.isExist` is deliberate and phrased as `forEachLiveGroup` phrases it: a handle that
cannot answer the question must not take the whole enrolment down with it.

## Definition of done

- [x] `veafSkynet.dcsObjectStillExists` exists, its docstring carrying the **why** — the DCS quirk
      and the combat-zone ordering, not the mechanics of `isExist`
- [x] the start-up enrolment no longer enrols a group DCS has released, and no longer dies on one
- [x] a group that exists is still enrolled exactly as before — the control case
- [x] Lua tests per ticket 04, verified to fail with the guard removed (4 of them drop)
- [x] `stylua --check src/scripts/veaf/ test/lua/` clean
