# 12 — The air defence of a zone is too light

Status: ⬜ ready
Type: fix

## Found

David, 2026-11-17: only short-range infrared SAMs, "pas très réaliste"; a base like Aleppo should have SA-15, Tunguska, SA-8, "le genre de SAM qu'on a un peu partout normalement".
A zone's air defence comes from its size class (`DEFAULT_SIZE_CLASSES`, `campaign_manager/models.py`): `airfield` = defence 3 → `generateAirDefenseGroup-RED-3` (Strela-10, Strela-1, Shilka, ZSU-57, S-60); `outpost` = defence 1 (Shilka alone).
SA-8 (Osa) comes at level 4, SA-15 (Tor) and Tunguska at level 5 (`veaf-units.yaml`), with a die of ±1 at the draw (`generateAirDefenseGroup`). An airfield of level 3 also draws a single air defence group (`composeGarrison`: two above level 3).

## To do

- New defaults: reco `airfield` defence 5, `outpost` defence 3; a campaign may still lower them with `size_classes:` (`CAMPAIGN.md`). The modern era only; the cold-war and WW2 variants keep their own tables.
- The Oronte campaign: its `campaign.yaml` follows, and its **red garrisons already recorded in the save are redrawn** — removed from the state so the next load draws them free with the new levels (`veafCampaign.lua`, the load path: a placed, owned zone without a garrison draws one, from no reserve in mission 1). An operation on the live server: server empty, the state's diff shown to David first, his go.
- The tests of the size classes and the doc (`CAMPAIGN.md` and `.en.md`) follow.

## Done when

A red airfield of the next evening has an SA-8 or better and a Tunguska or Tor, and an outpost an SA-9/13 or better.
