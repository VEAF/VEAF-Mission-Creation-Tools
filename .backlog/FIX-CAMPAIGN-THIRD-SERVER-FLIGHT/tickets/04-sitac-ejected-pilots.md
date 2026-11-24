# 04 — The sitac shows the ejected pilots

Status: ✅ done
Type: feature

## Decided

David, 2026-11-19, following the reco of the Foothold comparison (PRD): ejected pilots on the map, to help the rescue.

## To do

- VMCT: the `sitac` block gets an `ejectedPilots` list in Foothold's shape — `playerName`, `latitude`, `longitude`, `altitude`, `lostCredits` — from the pilots on the ground that `veafCSAR` tracks (player pilots; an AI pilot only if CSAR rescues those too), with the credits held that the pilot loses if nobody picks him up (`veafCampaignEconomy.held`).
- A pilot rescued or picked up leaves the list at the next write.
- foothold-sitac: the VEAF reader fills the model Foothold's ejected pilots use.

## Done when

An ejected player appears on the sitac where he landed and leaves it once rescued, with tests on both sides.

## Implemented (2026-11-19)

`veafCampaign.sitacEjectedPilots()` reads `csar.woundedGroups`, players' side only, AI pilots included (CSAR rescues them too); `lostCredits` is what the economy recorded at the ejection (`veafCampaignEconomy.lostAtEjection`). The credits held are lost at the ejection in our economy: a rescue does not give them back, unlike Foothold. Tests: both Lua suites.

## To check in game

An ejected player appears on the sitac where he landed, and leaves it once picked up.
