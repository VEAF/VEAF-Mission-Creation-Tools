# 01 — A captured airfield offers no slot

Status: ✅ done
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

## Implemented (2026-11-19)

`prepare_next_mission` calls `open_every_campaign_airfield` (`campaign_manager/next_mission.py`) for a persistent campaign: every airfield zone goes under the player side's `airports:` in the mission's `src/warehouses.yaml`, an entry already there keeps its settings, a side the file does not declare is left without slots; a base the mission gives the side outside the campaign's zones is listed by its id, since an explicit list replaces "every base of the side" (found by the review). `NextMissionReport.slot_airbases` lists them. Tests: `TestEveryAirfieldOffersSlots` in `test_campaign_persistent.py`.
The enemy side's list is left as it is: it has no players. Its block, when declared with no list, restocks the airfields it holds after the player side, and links a type both sides have a template for to its own: written in `known-limitations.yaml` (`campaign-enemy-side-restocks-listed-airfields`).

## To check in game

1. Rebuild the Oronte mission with `campaign next`, and check `src\warehouses.yaml` lists the seven airfields under `blue.airports`.
2. Capture a neutral or red airfield in flight (or set it blue from the admin menu).
3. Open the blue slot list: the airfield offers dynamic slots. If it does not, write the measurement in `known-limitations.yaml` (`kind: dcs`).
