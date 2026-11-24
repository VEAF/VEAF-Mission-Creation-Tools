# 02 — A garrison's SAM in a group of its own

Status: 🧑 waiting-human — measured on 2026-11-22, no code change; David's call on the Hawk
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

## State (2026-11-22, the implementing session)

**Not measured: DCS was not running.** No `DCS.exe` process on DAVID-BUREAU, nothing on the fiddle hook (port 12080) nor on the bridge (8080).
Nothing was changed in the garrison code: the ticket says to measure first, and to split only if the mixed group stays silent.

What the code and the server log narrow down, measured:

- **The red medium- and long-range batteries are already groups of their own.** `VeafCampaignZone:drawGarrison` (`veafCampaign.lua`, the `batteries` table) places each `medium_range_sam` / `long_range_sam` battery as its own group, saved under its own name.
  The Campagne server's log has `group [Aleppo medium-range SAM] reinforced` (2026-11-22 16:19 UTC).
  So the SA-11 / SA-6 / SA-3 drawn on 2026-11-22 are not concerned by the mixed-group hypothesis.
- **The only multi-unit SAM drawn inside the main group is the blue Hawk.** `composeGarrison` puts `generateAirDefenseGroup` in the garrison's one group, and among its templates only `generateAirDefenseGroup-BLUE-5` holds a SAM of separate pieces (Hawk sr, pcp, tr, 3 ln, plus Chaparral, Gepard, lorries).
  `BLUE-4` holds a Roland Radar with Roland ADS, which are self-contained (Roland ADS has 4 kills in the log); the red templates hold only self-contained vehicles and a Dog Ear radar.
  The server log knows a single group at Hatay, `Hatay garrison`.

So the split, if the measure calls for it, concerns only the Hawk of `BLUE-5` (and a `garrison_list` that would declare a multi-unit SAM).

## Measurement procedure (to run with DCS up)

1. Launch any Syria mission in DCS, unpaused, with the fiddle hook installed (it is: `Saved Games/DCS/Scripts/Hooks/dcs-fiddle-server.lua`).
2. Send [`measure/sam-in-mixed-group.lua`](../measure/sam-in-mixed-group.lua) to the hook (`env=default`, Lua base64-encoded in the path, Basic auth `veaf` with `%USERPROFILE%\dcs-fiddle-token.txt`).
   It spawns a Hawk site alone and the same site inside a 30-odd-unit mixed group, 60 km apart, each with a red An-26B flown over it at 4,000 m.
3. Every minute for ten minutes, send the `measure-result.lua` block at the end of that file: missiles left on each site's launchers, each target alive or down, the shots seen.
4. Read: site A fires and site B does not → the hypothesis holds, split the Hawk into its own group (the "To do" above). Both fire → stop, the cause is elsewhere (alarm state, skill, masking at Hatay). Neither fires → the test is wrong (positions, target), fix it before concluding.
5. Write the result into `known-limitations.yaml` (`kind: dcs`, value and date) and regenerate `docs/agents/dcs-runtime-traps.md`.

The script was written without DCS and never run: its positions may need moving off a town or a ridge.

## Measured (2026-11-22 evening, David's DCS, through the bridge)

**The mixed-group hypothesis is refuted: in this setup the Hawk did not fire, in a group of its own or not.** David, 2026-11-22: Hawks fire in his other missions, Foothold's `Blue SAM HAWK` among them (Mission Editor group, same composition as `BLUE-5`, skill High, a route, launchers turned to cover all around). So something in how these Hawks were spawned differs; not found yet.

Bench 1, an empty Syria mission (`veaf-mesure-sam-Syria.miz`), single player then server mode: nothing fired at all, not even the NASAMS control, against an **unarmed** An-26B at 4,000 m or a **clean** Su-25T at 3,000 m passing overhead. A Hawk site alone, the same inside a 33-unit mixed group, a full Hawk with CWAR, a NASAMS with and without a route: 0 missiles fired. The search radars detected the targets; the Hawk tracking radars never came on. Likely, not proven: DCS air defence does not engage an aircraft carrying no weapon. The script of this file flies an unarmed target, so it cannot measure anything.

Bench 2, a copy of the deployed campaign mission (`Campagne_Oronte.miz`, hash 3C5785A232E7, with the bridge prepended to `veaf-scripts.lua`), run in server mode with no save, so every zone drew a fresh garrison. Hatay's garrison: one group of 74 units, its Hawk with sr ×1, cwar ×2, tr ×3, pcp ×1, ln ×9. Targets: red CAS strikes from the campaign's own `veafCampaignOps.spawnFlight` (air start at Jisr al-Shughur, two Su-25 with FAB-250, UB-13 and R-60), flown at Hatay.

| Hawk | Nearest pass of the armed Su-25 | Hawk missiles fired | The rest of Hatay's garrison |
|---|---|---|---|
| inside Hatay's garrison group (as on the server) | 3.0 km | 0 of 27 | Gepard and Avenger fired |
| the same 16 Hawk units moved into a group of their own, same positions | 2.6 km | 0 of 27 | Gepard, Avenger, Linebacker fired (319 shots) |
| a standard Hawk (sr, tr, pcp, 3 ln) alone, 8 km north of Hatay | about 8 km | 0 of 9 | – |
| control: a NASAMS (radar, command post, 2 LN) alone, 8 km east of Hatay | about 8 km | **5 fired** (at the strike and at the campaign's own MiG-27K SEAD) | – |

In every case the Hawk search radar was on and the tracking radars never came on. The NASAMS placed by hand fires, so the bench works with armed targets.

Consequence for this ticket: splitting the Hawk into its own group changes nothing; no code change. The fix is to stop relying on the Hawk: the blue level-5 template (`generateAirDefenseGroup-BLUE-5`) and every other place that spawns a Hawk need another system. That choice is David's; written in the PRD's state.

Not measured: whether the Hawk is broken in DCS for everyone, or only with these compositions; the DCS version of David's install and of the server were not compared.

### Second run, and the server's log (2026-11-22, late evening)

- An exact copy of Foothold's `Blue SAM HAWK` (19 units, skill High, its headings, a route), spawned by script in CJTF Blue 8 km from Hatay in the same measuring mission, against the same kind of armed CAS strike: **0 missiles, its tracking radars never on**. A Turkish copy could not be spawned (no Turkey in the mission).
- **The Campagne server's own log contradicts "the Hawk never fires"**: on 2026-11-20 at 20:40 UTC a campaign `Hawk ln` fired two `MIM-23K Hawk` at a Su-25 (`type=shot`, `initiator_unit_type=Hawk ln`). So a garrison Hawk does fire on the server. What the measuring bench lacks is still unknown.
- The same log shows red's SEAD killing the blue Hawk's radars again and again: `Hawk sr` / `Hawk cwar` dead on 2026-11-19 (×4), 2026-11-21 (×2), 2026-11-22 15:48 UTC (`Hawk sr`). A Hawk whose search radar is dead is blind. Whether Hatay's was alive at 15:38 UTC on 2026-11-22, when David saw the Su-25 come to 3 NM, is not known.

Next step, cheaper than a bench: at the next flight, read the Campagne log for `initiator_unit_type=Hawk ln` shots and for `Hawk sr` deaths, and set them against the red strikes on Hatay. No code change before that.
