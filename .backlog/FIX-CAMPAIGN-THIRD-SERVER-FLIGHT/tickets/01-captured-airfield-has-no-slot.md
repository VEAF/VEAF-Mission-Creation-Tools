# 01 — A captured airfield offers no slot

Status: ⬜ ready
Type: fix

## Found

David, 2026-11-19: "On a capturé Ménag, mais on peut pas spawner dessus." Menagh (airfield Minakh) was taken by blue at 20:13 UTC.
The build enables Dynamic Slots only on the airbases that belong to a coalition at build time: the default of `src/warehouses.yaml` is "every airbase assigned to this coalition" (`warehouses_injector_worker.py`, the branch with no `airports:` list). Minakh was neutral at build, so it has no `dynamicSpawn` and no aircraft in its warehouse; when the campaign gives it to blue in flight (`setAirbaseCoalition`), DCS changes its side and there is no slot to open.
Every red airfield of the campaign is in the same case for blue: Taftanaz, Aleppo, Kuweires, Abu al-Duhur, Bassel Al-Assad, Hama.

## To do

- For a persistent campaign, `campaign next` writes the player side's `airports:` list in the mission's `warehouses.yaml` with **every airfield zone** of the campaign, whatever its owner at the start: the injector configures a listed airport whatever its coalition (`_resolve_airport_id`, the explicit branch). Decide the enemy side's list the same way if it has players one day.
- Measure in game that DCS opens the dynamic slots of an airbase whose coalition changes during the mission (Foothold relies on it; not measured on ours). If it does not, find what does (a warehouse refresh after `setCoalition`, the slot's own coalition), and write it in `known-limitations.yaml`.
- Until it ships: the Oronte campaign gets the list by hand in its template and mission folder, rebuilt and redeployed (the fixed file name makes it a file swap).

## Done when

An airfield captured by blue in flight offers blue dynamic slots in the next evening's check, and a test shows `campaign next` writing every airfield zone in the list.
