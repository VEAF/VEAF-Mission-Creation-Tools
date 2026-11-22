# 02 — A garrison's SAM in a group of its own

Status: ⬜ ready
Type: fix

## To do

- **First, measure in DCS** (through the bridge, on David's DCS; no player needed): a Hawk site (sr, tr, ln, pcp) spawned alone as one group, and the same site inside a mixed group of some 30 units (armour, AAA, MANPADS, trucks), each with a target aircraft flown through its reach. Write down which fires, and how fast. Same for one of the red medium-range systems (SA-11 or SA-6).
- If the mixed group does not fire: when a zone's garrison is composed (`veafCampaign.composeGarrison`, `veafCampaign.lua` line 777, and the `medium_range_sam` / `long_range_sam` generators around line 872), every air defence system made of separate radars and launchers gets **its own DCS group** in the garrison, recorded in the save like the zone's other groups. Self-contained vehicles (Avenger, Gepard, Tor, Tunguska, Strela, Roland ADS…) may stay in the main group.
- Saves already on the server hold such systems in the main group: split them at load (the save keeps every unit's type and position), so Hatay's Hawk and the batteries drawn on 2026-11-22 at Aleppo and Bassel Al-Assad work without a redraw. Say in the ticket how the split is named and that `veafCampaign.unitIndex`, the kill payment and `[CAMPAIGN AIRDEF]` still find every unit.
- If the measure shows the mixed group fires, stop: write what it showed, and the ticket looks for the real cause (alarm state, skill, terrain masking at Hatay) before changing anything.
- Add the measure to `known-limitations.yaml` (`kind: dcs`, value and date), then regenerate `docs/agents/dcs-runtime-traps.md`.
- Tests: a composed garrison puts each multi-unit SAM in a group of its own; a loaded save with a Hawk in the main group comes out split; the garrison's price and its kill payment are unchanged.
- Docs: CHANGELOG entry.

## Done when

The measure is written down, and a zone's radar air defence fires at an enemy aircraft in its reach; with tests.

## In-game check

On the Campagne server: a `[CAMPAIGN FLIGHT]` line where a Hawk at Hatay, or an SA-11 / SA-6 / SA-3 at Aleppo or Bassel Al-Assad, kills an aircraft, or the `[CAMPAIGN AIRDEF]` missile count of its launchers going down.
