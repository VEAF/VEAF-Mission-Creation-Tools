# 06 — The sitac shows the AWACS and the tankers

Status: ✅ done
Type: feature

## Decided

David, 2026-11-19, following the reco of the Foothold comparison (PRD): the support aircraft on the map, where Foothold gives its tankers' settings.

## To do

- VMCT: the `sitac` block gets a `support` list — name, kind (AWACS, tanker boom, tanker basket), side, position, altitude, frequency and TACAN, alive or not — for the assets `veafSupport` places (`dynamic.support.assets`), so a pilot sees where to find the tanker without asking.
- foothold-sitac: the VEAF reader draws them with their frequency; Foothold's `tankers` model is reused where it fits, extended where it does not (Foothold gives settings, not positions).

## Done when

The sitac shows the AWACS and the two tankers at their current orbit, with their frequencies, with tests on both sides.

## Implemented (2026-11-19)

`veafCampaign.sitacSupport()` lists the players' side's assets of `modules.SUPPORT.assets`: position now, kind (`awacs`, `tanker_boom`, `tanker_basket`, `tanker_both`, `tanker`), frequency and TACAN from `veaf.getTankerData`; one destroyed is listed by name, `alive = false`. Tests: `test_veafCampaignSitac.lua`.

## To check in game

The sitac shows the AWACS and the two tankers on their orbit, with the frequencies of the Mission Editor.
