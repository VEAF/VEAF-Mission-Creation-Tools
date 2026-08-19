# FIX-COMBATZONE-ZONE-TYPE-SILENT — a combat zone can find no units and say nothing

Status: ⬜ ready

Origin: closing [#67](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/67) on 2026-08-17.
The feature that issue asked for (polygon trigger zones) works; this is the hole found beside it,
which belongs to no issue and would have died with the closure.

## The defect

`veafCombatZone.lua:1518-1522`:

```lua
if triggerZone.type == 0 then -- circular
  units = mist.getUnitsInZones(unitsNames, { self:getMissionEditorZoneName() })
elseif triggerZone.type == 2 then -- quad point
  units = mist.getUnitsInPolygon(unitsNames, triggerZone.verticies)
end
```

No `else`. Any other value of `triggerZone.type` — including **nil** — leaves `units` at its initial
value, so the zone finds **zero units** and the code carries on as though the zone were simply
empty. Nothing logs, nothing warns.

## What it costs, honestly

**This is a robustness defect, not a reported bug.** DCS ships two trigger-zone types and both are
handled, so no mission maker has hit it. Two ways it becomes real:

- `triggerZone.type` is **nil** — a hand-edited mission, a zone written by a tool, a DCS version that
  renames the field. The `if` then falls through silently.
- DCS adds a third type. The zone stops working with no symptom pointing at the type.

The reason to fix it now is the failure *mode*, not its likelihood: a combat zone with no units does
not error — it activates, reports nothing to kill, and (if `completable`) deactivates on the first
watchdog tick announcing "all enemies destroyed". Exactly the shape of the bug
`FIX-CONVERT-V5-SILENT-LOSSES` ticket 03 just fixed from the other end.

## Scope

One ticket. Add the `else`: log an error naming the zone and the unexpected type, and treat the zone
as unusable rather than as empty. Do **not** guess a fallback — picking circular for an unknown type
would put the silent wrong answer back, one level down.

Check while there whether the same shape exists elsewhere: `veafSanctuary` and the MCP's
`edit_zone` both read a zone's type, and the grep is cheaper than the next investigation.

## Definition of done

- [ ] An unexpected or nil `triggerZone.type` logs an error naming the zone and the value
- [ ] The zone is not silently treated as empty
- [ ] A Lua test covering nil and an unknown type
- [ ] Sibling readers of `triggerZone.type` grepped, and what was found recorded here
