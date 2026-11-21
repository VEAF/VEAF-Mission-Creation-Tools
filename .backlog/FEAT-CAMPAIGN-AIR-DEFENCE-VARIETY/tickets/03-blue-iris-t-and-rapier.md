# 03 — The IRIS-T SLM and the Rapier for blue

Status: ⬜ ready
Type: feature

## To do

- A VEAF group for the IRIS-T SLM in `veaf-units.yaml`, alias `iristslm` (and `iris-t`): one `CHAP_IRISTSLM_STR` radar, one `CHAP_IRISTSLM_CP` command post, three or four `CHAP_IRISTSLM_LN` launchers, a supply truck, laid out as the NASAMS group is. Read the three units' entries in `CoreMods/tech/Currenthill Assets Pack/Database/Vehicles/` (ranges, which unit is the search radar) before laying it out, and write what was read in the yaml comment.
- The spawn command: `-iristslm` works like `-nasams`, with its price (`veafSpawn` / the spawn price table); the marker help and `doc/` list it.
- The shop's zone upgrades (`veafCampaignEconomy.UPGRADES`): add `iristslm` (modern era) and a Rapier (cold war and modern) from the existing groups `rapier_radar` / `rapier_optical` (choose one, or the radar one in the modern era), priced as the others are (the units' spawn price × `economy.credits_per_point`, drawn by `upgradeOffer`); the menu titles in both languages.
- The pilots' names: `air_defence_names.py` (`_SYSTEMS`: "IRIS-T SLM" medium, "Rapier" short).
- Skynet: check that it handles the IRIS-T SLM's radar as a search/track radar; say what was found.
- Era: `ESCORT_TYPES_REPLACED_BY_ERA` or the upgrade's `eras` keep the IRIS-T SLM (in service 2022) out of the cold war.
- Docs: the shop's table in `PERSISTENT_CAMPAIGN.md` / `.en.md`, the spawn page, the theatre dossier's player guide (the shop section).
- Tests: the group exists and spawns; the upgrades are offered in their eras, priced, and placed; the guide lists them with their price.

## Done when

On a blue zone of a modern campaign, a player can buy an IRIS-T SLM or a Rapier upgrade from Campaign → Boutique, and `-iristslm` spawns the battery; with tests.

## In-game check

1. Campaign → Boutique → améliorations: IRIS-T SLM and Rapier are listed with their price.
2. Buy the IRIS-T on a blue zone: the battery appears, its radar turns, and it fires on a red aircraft that comes within range.
