# FIX-COMBATZONE-ZONE-TYPE-SILENT — a combat zone can find no units and say nothing

Status: ✅ done

Shipped in 6.15.16, with `FIX-COMBATZONE-RENAME-OPTION` — one branch, one PR, both being combat-zone
work on the same file and the same doc pages. Closed outright: unit tests cover it and nothing here
needs DCS.

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

## The sweep the DoD asked for, and what it found

Not one site — **three**, and not the ones this PRD guessed. `veafSanctuary` does not read a zone's
type at all, and the MCP's `edit_zone` only carries the two values as documentation. The real siblings
are runtime modules with the identical `if 0 … elseif 2 … end` and no `else`:

| Site | What silence looks like there |
|---|---|
| [`veafCombatZone.lua:1803`](../../src/scripts/veaf/veafCombatZone.lua:1803) | the zone activates, has nothing to kill, and the first watchdog tick declares it won |
| [`veafAirWaves.lua:822`](../../src/scripts/veaf/veafAirWaves.lua:822) | `humanUnits` stays **nil**, so no player is ever detected and the wave never triggers |
| [`veafQraCore.lua:727`](../../src/scripts/veaf/veafQraCore.lua:727) | zero units in the zone, so the QRA never scrambles — indistinguishable from a design choice |

All three fail the same way: nothing happens and nothing says so. Fixing one and merely recording the
other two would have been the convenient narrowing of a general instruction — so the branch moved into
one shared helper and all three call it.

## Scope

`veaf.getUnitsInTriggerZone(zoneName, unitNames, moduleId)` owns the branch and logs an error naming the
zone and the value. No fallback shape is guessed — picking circular for an unknown type would put the
silent wrong answer back one level down.

It returns **nil** for a zone it cannot read, not an empty table: "unusable" and "legitimately empty"
are different answers, and a caller that cannot tell them apart is how this defect started. The
`moduleId` argument sends the error to the log of whoever asked, which is what makes sharing the branch
better than copying the `else` three times.

## Definition of done

- [x] An unexpected or nil `triggerZone.type` logs an error naming the zone and the value
- [x] The zone is not silently treated as empty
- [x] A Lua test covering nil and an unknown type
- [x] Sibling readers of `triggerZone.type` grepped, and what was found recorded here — **three sites,
      all three fixed**, and the two the PRD guessed at turned out not to read the type at all
