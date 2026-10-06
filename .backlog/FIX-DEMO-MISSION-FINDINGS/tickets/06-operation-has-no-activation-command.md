# 06 — A combat operation cannot be activated from its menu

Status: ✅ done
Type: fix (or doc — decide in the plan)
Files: `src/scripts/veaf/veafCombatZone.lua` (`VeafCombatOperation:updateRadioMenu`, l. ~2897 and ~2913; `OperationRadioMenuName = nil`, l. 114), `doc/mission-maker/scripts/veafCombatZone*.md`, tests

## What happens

An operation's radio menu only offers « Infos » and the briefings: the activate / deactivate commands are commented out.
There is no « Opérations » submenu either: the operation sits directly under ZONES DE COMBAT, while the docs describe one.
An operation that is not `active_at_start` can therefore only be activated by script or `-zonestart`.

## Measured

Demo mission review and in-game run, 2026-10-05: `Op_Tkvarcheli` had no activation entry; `veafCombatZone.ActivateZone("Op_Tkvarcheli")` works.

## Options

a. restore the (secured) activate / deactivate commands on the operation's menu — reco, it is what a combat zone offers
b. keep it, and say in the docs how an operation is activated (`active_at_start`, `-zonestart`)

## Demo workaround to remove

« Démo : actions » menu with `demo.activateOperation()` / `demo.desactivateOperation()` in `src/scripts/mission-script.lua`.
