# FIX-CSAR-HANDLE-EJECT-ARGUMENT — CSAR hands a player name to a function that indexes a unit

Status: ⬜ ready

Found on 2026-08-22 while shipping
[`FIX-CSAR-SPAWNS-ON-WATER`](../FIX-CSAR-SPAWNS-ON-WATER/PRD.md), because that lot had to reproduce the
call and looked at what it does.

## The defect

`csar.addCsar` (`CSAR.lua:384`) calls:

```lua
csar.handleEjectOrCrash(_playerName, false)
```

`handleEjectOrCrash(_unit, _crashed)` (`CSAR.lua:628`) immediately does `_unit:getName()`,
`_unit:getPlayerName()` and `_unit:getID()`. A **player name is a string**, so this raises
*"attempt to index a string value"*.

It is invisible today because `csar.csarMode` defaults to **0**, and both branches of the function are
gated on mode 1 or 2. A mission that sets the mode — which is the whole point of the setting, disabling
an aircraft or a pilot for `disableTimeoutTime` minutes after an ejection — gets an error instead of the
sanction it asked for.

Every other caller passes a unit: `csar.handleEjectOrCrash(_unit, true)` from the crash handler. Only
`addCsar` passes the name.

## Not ours to patch in place

`CSAR.lua` is vendored `adapted` (`vendored.yaml`), so an edit here is erased by the next update. Two
honest routes:

1. **Upstream.** This one is a plain bug, not a VEAF policy — unlike the over-water placement — so it
   belongs in a PR to ciribob, and in the VEAF fork meanwhile.
2. **Replace `csar.handleEjectOrCrash`** from `veaf.csar_initialize_replacement`, tolerating both a unit
   and a name. Cheap, and it protects VEAF missions now.

`FIX-CSAR-SPAWNS-ON-WATER` already wraps its own call in a `pcall` so its new path is not the one that
dies from this, which is a guard rather than a fix.

## Definition of done

- [ ] Decide between the upstream PR and a local replacement — with David, since it is his fork
- [ ] A mission with `csarMode` 1 or 2 gets the disablement it asked for, tested
- [ ] The `pcall` guard in the over-water wrapper revisited once the call cannot raise
