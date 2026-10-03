# 02 — a dynamic-slot helicopter gets its CSAR menu

Status: ✅ done — verified in game 2026-10-03

[#989](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/989), Tripack 2026-09-22: no CSAR
radio menu in a UH-1, while the MAYDAY and the downed pilot showed CSAR running.

## Cause

`csar.addMedevacMenuItem` adds the menu to `csar.getGroupId(unit)`, and that function has looked the
unit up in `veaf.getUnitRecordById` since CSAR left MiST (#845, 2026-08-30, shipped in 6.18.0). That is
the **editor snapshot**, which by its own docstring answers nothing for a unit created at runtime — and a
dynamic slot is one. MiST's `mist.DBs.unitsById`, which it replaced, grew at every birth. So a
dynamic-slot helicopter got `nil`, hence no menu, and none of the messages CSAR sends to its group
(`delayedHelpMessage`, `displayMessageToSAR`). The VEAF configuration was not the cause:
`veaf.lua` already forces `enableAllslots = true`, so the UH-1H type is enough.

Not confirmed on Tripack's own files (they are on Discord), so "dynamic slot" is the inference from the
code, which R22 checks.

## What was done

- `csar.getGroupId` reads `_unit:getGroup():getID()`, the live group. `vendored.yaml` names the
  adaptation in CSAR's `manual_steps`.
- `test_a_dynamic_slot_helicopter_gets_its_csar_menu` (`test_csar_init.lua`) builds a UH-1 the editor
  never placed and asserts the `CSAR` submenu lands on its group id; it failed before the change with
  no menu at all.
