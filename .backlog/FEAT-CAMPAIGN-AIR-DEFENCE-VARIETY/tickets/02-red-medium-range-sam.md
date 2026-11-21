# 02 — A medium-range SAM for red

Status: ⬜ ready
Type: feature

## To do

- A zone option `medium_range_sam` (bool), next to `long_range_sam`, on a zone and on a size class (`models.py` `SizeClass`, `ZoneDefinition`; the validator in `campaign_manager.py`), with its own cap and spacing block `medium_range_sams` (`cap`, `spacing`) as `long_range_sams` has. Defaults: estimates to tune after an evening, written as such in the code (for instance a cap of 3 per side and 60 km apart).
- The runtime: where `veafCampaign.lua` places a zone's long-range battery (around line 856), a zone with `medium_range_sam` gets a battery drawn from a new `veafCasMission.MEDIUM_RANGE_AIR_DEFENSE_GROUPS`, by side and era:
  - red, modern: `sa11`, `sa6`, `sa3`;
  - red, cold war: `sa6`, `sa3`;
  - blue: `hawk`, `nasams` in the modern era, `hawk` in the cold war (a blue zone with the option gets one too, as `long_range_sam` does).
  Name the group `<zone> medium-range SAM`, as the long-range one is `<zone> long-range SAM`, so `intelligence.py` and the sitac can tell it.
- Everything that already reads `long_range_sam` to know a zone's air defence reach reads the medium one too: `veafCampaignOps` (`ASSUMED_LONG_RANGE` / `ASSUMED_SHORT_RANGE`, around line 1248: the AI's CAP and strikes keep out of it), `intelligence.py` (`main` / `outpost`), `mission_deck.py`, `air_defence_names.py` ("SA-11 (SAM moyenne portée)").
- A zone captured keeps or loses its battery as a long-range one does today.
- The Oronte campaign (`D:\dev\_VEAF\tmp\dynamic-syria\campaign.yaml`) is not changed by this lot: the control session sets `medium_range_sam` on two or three red zones when it deploys, as Hama has `long_range_sam`.
- Docs: `PERSISTENT_CAMPAIGN.md` / `.en.md` and the campaign authoring page (the zone options), both languages; `src/defaults` if a default campaign shows the zone options.
- Tests (Python and Lua): the option parsed and validated (cap, spacing, bad value); a zone with it draws a battery of its era; the AI's reach reads it; the dossier names it.

## Done when

A campaign that sets `medium_range_sam` on a red zone gets an SA-11, SA-6 or SA-3 battery there, capped and spaced, and the AI and the briefings know its reach; with tests.

## In-game check

On the Campagne server, a red zone with `medium_range_sam`: the `[CAMPAIGN AIRDEF]` line shows the battery's launchers; an F-16 with a HARM sees its radar on the RWR from about 40 km.
