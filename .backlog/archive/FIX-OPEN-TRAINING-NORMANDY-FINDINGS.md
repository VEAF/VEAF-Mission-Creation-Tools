# FIX-OPEN-TRAINING-NORMANDY-FINDINGS — what building the Normandy 1944 Open Training v6 through the MCP found

Status: ✅ done — tickets 01–06 and 08–14 done, 07 closed unmeasured (David, 2026-10-14: « on verra bien en jeu »), 15 measured: not a defect · archived 2026-11-24

Asked by David on 2026-10-13. The Normandy (WW2, 6 July 1944) Open Training v6 was built from scratch with the Open Training prompt (`.prompts/new-open-training-mission.fr.md`), the `veaf-mission-mcp` actions and the tools of `develop` (6.29.0), in `VEAF-Open-Training-Mission-Normandy-WW2-v6`. The prompt asks for a « Retours pour VMCT » block; this lot is that block. Every finding below was written down from the build; **read again in the code of `develop` before the work, six turned out to be wrong in part** (02, 06, 09, 11, 12, and 01's list of files), and each ticket says what was corrected.

It is the first WW2 mission built this way: the findings are mostly what an era with no tanker, no helicopter and no SAM, and aircraft with no named loadout, does to tools written for a modern theatre.

Findings first, in the order they did harm:

- the loadout oracle knows no WW2 module aircraft, and the AI bombers' bombs are only in the install's database (01), so every WW2 flight was either armed by hand or warned about (02);
- the shipped catalogue and the CAS tables ignore the era: 51 modern jets injected in a 1944 mission, a Bradley and an M4 rifleman in front of a Tiger (03, 04), and `list_shortcuts` says nothing about era (05);
- a Fw 190 cannot tune the VHF band the plan gives it (06) and the red slot templates may hold no cannon ammunition (07);
- the data and the commands around the DCS session: Normandy parking (08), a sweep that waits forever on a dead server (09), a limitations list too big for a tool result (10), a geocoder with no bounds for 8 theatres (11);
- the prompt itself (12);
- an alias whose `country` is in no coalition spawns neutral and stops a whole zone on `networkName nil` (14), and a native convoy that drives at 5.1 m/s whatever its route says (15, to measure);
- a group frequency of 251 MHz that the Mission Editor refuses on a P-51D or a Fw 190 client group, which the build never sees (13).

Not filed, already known and only recalled: `create_combat_zone` writes 20 km/h and an « Off Road » first point on convoy routes (Sinai retours 13; fixed here by editing the table, tools/gen_17_convois.py), the elevation grid being not shipped (Sinai 3), the missing `slim` step after `capture-map --parking` (Sinai 8), « Appuyez sur Entrée pour quitter… » from `inject-bridge` when called by a script (Sinai 10). `land.findPathOnRoads` finds no road from Vire: not VMCT, a property of the Normandy map.

| # | Ticket | Status |
|---|--------|--------|
| 01 | [`list_payloads`: module aircraft and AI bombers](FIX-OPEN-TRAINING-NORMANDY-FINDINGS.md) | ✅ |
| 02 | [« no weapons » on a gun fighter; `loadout_from` a gun-only template](FIX-OPEN-TRAINING-NORMANDY-FINDINGS.md) | ✅ |
| 03 | [The spawnables catalogue ignores the era](FIX-OPEN-TRAINING-NORMANDY-FINDINGS.md) | ✅ |
| 04 | [WW2 tables of `veafCasMission`](FIX-OPEN-TRAINING-NORMANDY-FINDINGS.md) | ✅ |
| 05 | [`list_shortcuts` has no era; WW2 radar and artillery aliases](FIX-OPEN-TRAINING-NORMANDY-FINDINGS.md) | ✅ |
| 06 | [A radio role for a Fw 190 (38.4-42.4 MHz only)](FIX-OPEN-TRAINING-NORMANDY-FINDINGS.md) | ✅ |
| 07 | [Red WW2 slot templates carry `gun: 0`](FIX-OPEN-TRAINING-NORMANDY-FINDINGS.md) | 🚫 |
| 08 | [Ship the Normandy parking capture](FIX-OPEN-TRAINING-NORMANDY-FINDINGS.md) | ✅ |
| 09 | [`terrain-sweep` and a dead `dcs-serve`](FIX-OPEN-TRAINING-NORMANDY-FINDINGS.md) | ✅ |
| 10 | [`describe_known_limitations` by area](FIX-OPEN-TRAINING-NORMANDY-FINDINGS.md) | ✅ |
| 11 | [`theatre-bounds.yaml` covers four theatres](FIX-OPEN-TRAINING-NORMANDY-FINDINGS.md) | ✅ |
| 12 | [The prompt for eras with no support aircraft](FIX-OPEN-TRAINING-NORMANDY-FINDINGS.md) | ✅ |
| 13 | [`add_air_group` writes 251 MHz: the Mission Editor refuses to save a WW2 player group](FIX-OPEN-TRAINING-NORMANDY-FINDINGS.md) | ✅ |
| 14 | [A `country` that belongs to no coalition makes a battery spawn neutral](FIX-OPEN-TRAINING-NORMANDY-FINDINGS.md) | ✅ |
| 15 | [A native convoy in a combat zone drives at 5.1 m/s](FIX-OPEN-TRAINING-NORMANDY-FINDINGS.md) | 🚫 |

Riskier than the rest, said in advance: 01 (new data from the install, two sources), 06 (the packer's band logic), 07 (needs DCS before a line is written).

Left to David: the Normandy elevation grid (1.2 MB) is not delivered, as no theatre ships its grid (ticket 08); the names of the six WW2 aliases (ticket 05); whether a Fw 190's primary frequency should be the first plan channel that fits it (ticket 06); the WW2 spawnable templates, which need the editor's own export (ticket 03).

One branch, one PR.

Source: the session that built the mission, `tools/retours-vmct.md` and the build logs of the mission folder.

What the lot changed and could not be run here is in [DCS-CHECKS.md](FIX-OPEN-TRAINING-NORMANDY-FINDINGS.md).

## Tickets, in full

## 01 — `list_payloads` knows no WW2 aircraft, and no module aircraft at all

Status: ✅ done
Type: fix (data)
Files: `veaf_build/dcs_data/payloads.py`, `src/python/veaf-tools/veaf_libs/data/payloads.yaml`, `veaf_libs/dcs_payloads.py`, tests

### What happens

`list_payloads` answers « DCS has no named loadout for 'P-51D' » for P-51D, P-51D-30-NA, P-47D-30, P-47D-40, SpitfireLFMkIX, MosquitoFBMkVI, Bf-109K-4, FW-190A8, FW-190D9 (every WW2 module aircraft), and for the two AI bombers a Normandy mission needs, Ju-88A4 and B-17G. The tool's own description says « a module aircraft has none here: give it pylons or loadout_from » — and the shipped `veafSpawn-*` / dynamic-slot templates of these types carry `pylons: {}`, so `loadout_from` fails too (« the group 'P-51D Template' carries no pylons »).

Cause, read in the code: `payloads.py` reads only `MissionEditor/data/scripts/UnitPayloads/` (`PAYLOADS_SUBDIR`). Module aircraft keep theirs under `CoreMods/<module>/UnitPayloads/`: on this workstation `c:/jeux/DCS World/CoreMods/WWII Units/UnitPayloads/` holds `P-51D.lua` (« Fuel75*2 », « HVAR*6,Fuel75*2 »…), `P-47D-30.lua`, `P-47D-40.lua`, `SpitfireLFMkIX.lua`, `MosquitoFBMkVI.lua`, `Bf-109K-4.lua`, `FW-190A8.lua`, `FW-190D9.lua`, `A-20G.lua`. The AI bombers have no such file: their stations are only in the install's `db.Units.lua` (`Ju-88A4`: pylons 1 and 3 `SC_501_SC500`, pylon 2 `{JU88A4TORP_10xSC50_on_InvCountedAttachmentPoints}`; `B-17G`: pylon 1 `{12xM64}`).

The Normandy Open Training read the two bombers' CLSIDs from `db.Units.lua` by hand (`tools/gen_10_joueurs.py` of the mission folder).

### What ships

- `update-dcs-data --payloads` also walks `CoreMods/*/UnitPayloads/*.lua` (same parser), keyed by `unitType` as before.
- For AI types with no payload file, a second source: the stations of `db.Units.lua`. One default per station is not a « named loadout » — either list the CLSIDs per station so an agent can build `pylons`, or name a few obvious defaults. Pick the cheaper; say which.
- `list_payloads` with no type lists these types too; the module-aircraft sentence of its description goes.
- Regenerate `payloads.yaml` from a full install (Core + CoreMods) and commit it.

### Done when

`list_payloads(unit_type="P-51D")` names `Fuel75*2` and `HVAR*6,Fuel75*2` with their pylons; `add_air_group(unit_type="P-51D", payload="HVAR*6,Fuel75*2")` writes the eight stations. Ju-88A4 and B-17G answer with at least their bomb loads.

### Done

`update-dcs-data --payloads` also walks `CoreMods/**/UnitPayloads`; the table went from 45 to 129 types (2 164 loadouts, nothing lost or changed). The files are not all data: seven module files compute their CLSIDs from `local` names (AH-64D, F-100D, three F-14A, F-14B, MiG-29 Fulcrum), which the parser cannot read; the generator lists them and leaves those types out, after neutralising the `tasks` tables that hold identifiers (that read five more).

Two corrections to the finding: the files sit under `CoreMods/aircraft/<module>/UnitPayloads` and `CoreMods/WWII Units/UnitPayloads`, and the Spitfire has **no** loadout file anywhere in the install (it stays without a named loadout). The AI bombers' stations are in `db.Units.lua`, which the generator does not read (a 39 MB dump of this workstation, not something every install has): the cheaper source chosen is a small hand-written file, `veaf_libs/data/payloads-ai-bombers.yaml` — `Ju-88A4` « SC500*2,SC50*10 » and `B-17G` « M64*12 », the loads the Normandy raids fly — merged by `dcs_payloads` and bundled in the executable.

## 02 — « no weapons » warning on a gun-armed fighter, and `loadout_from` refuses a gun-only template

Status: ✅ done
Type: fix
Files: `veaf_mission_mcp/add_air_group.py` (l. 294), `veaf_mission_mcp/aircraft_payload.py` (l. 162-172), tests

### What happens

1. `add_air_group` warns « group 'X' has task 'CAP' and no weapons: it will not fight without a loadout » for every WW2 fighter given no pylons. A P-51D, a Spitfire, a Bf 109 or a Fw 190 fights with its guns: the written unit carries `payload.gun = 100` and `pylons = {}` (checked in `src/mission/mission` of the Normandy Open Training). `create_qra` and `create_cap_mission` repeat the warning per group — 20 QRA groups and 5 CAP templates, 25 warnings the maker learns to ignore, which hides a real one (a Ju-88A4 with no bombs).
2. `loadout_from` raises « the group 'P-51D Template' carries no pylons » for a template whose empty pylons are legitimate (guns only).

### What ships

- The no-weapons test also counts the gun: a unit whose `payload.gun` is positive is armed. State the rule in the action's description.
- `loadout_from` a group with no pylons but a `gun` copies « no pylons » (and the gun and fuel it carries) instead of refusing; it still refuses a group that does not exist.

### Done when

`add_air_group` for a P-51D `task: CAP` with no payload returns no warning; the same for a Ju-88A4 `task: Ground Attack` with no pylons still warns. `loadout_from: "P-51D Template"` succeeds.

### Done

The rule the ticket proposed (« `payload.gun` positive means armed ») is wrong: `build_aircraft_payload` writes `gun: 100` for **every** aircraft, so it would also have silenced the warning for an F-15C given no missiles (FIX-OPEN-TRAINING-SYRIA-FINDINGS ticket 01, which a test holds). The rule is by type: a WW2 gun fighter (`GUN_FIGHTERS` in `add_air_group.py`: P-51D, P-47D, Spitfire, Bf 109, Fw 190, Mosquito, I-16, La-7, F4U-1D) with the gun is armed; a Ju-88A4 or B-17G with no bombs, and a modern jet with no missiles, still warn. `loadout_from` a group with aircraft but no pylons copies « no pylons »; a group found nowhere, or with no aircraft, is still refused.

## 03 — The shipped `spawnables.yaml` catalogue puts 51 modern jets into a WW2 mission

Status: ✅ done — the WW2 set is not shipped (known limitation)
Type: fix
Files: `mission_builder/mission_builder_worker.py` (l. 1377, the `spawnable_aircrafts` step), `src/defaults/mission-folder/src/spawnables.yaml`, the build log message, tests

### What happens

A mission with `mission.era: WW2` and an empty `src/spawnables.yaml` gets « 51 groupes aériens injectés » from the shipped catalogue: F-15C, F-14A, Mirage 2000, F-5, MiG-21/23/25, F1EE, MQ-9… (`pull-aircraft-groups` lists them). None exists in 1944, and none of the catalogue is a WW2 aircraft, so the `-cap`, `-escort` and `_spawn` templates a WW2 mission offers are all anachronisms. The Normandy Open Training switched the step off (`pipeline: spawnable_aircrafts: false`) and has no spawnable template at all.

### What ships

- The build reads `mission.era` for this step: under `WW2`, an empty `spawnables.yaml` injects nothing, and the log says why (« catalogue livré : aucun appareil de l'époque WW2 »); under `COLD_WAR`, only the types the catalogue marks for it.
- The catalogue entries carry an `era` (or a list), so the filter is data, not code.
- A WW2 set — at least P-51D, P-47D, Spitfire LF IX, Bf 109 K-4, Fw 190 A-8/D-9, Ju 88 A-4 and B-17G, as `veafSpawn-*` templates — ships with the tools (needs ticket 01 for the loadouts).

### Done when

A WW2 folder built with the default pipeline has no modern aircraft in its `.miz`, and the log names the era rule.

### Done

`aircrafts_injector.catalogue.AIRCRAFT_ERAS` says which era each type of the shipped catalogue exists in (a type not listed is kept in every era, and a test enumerates the shipped catalogue so none can be missing); the build filters the **shipped** fallback only — a `src/spawnables.yaml` the maker wrote is injected as written. Under `WW2` it injects nothing and says so (`pipeline.console.aircraft_no_era`); under `COLD_WAR` it drops the MQ-9. `MissionBuilderWorker.mission_era()` gives the era (`mission.era`, else the detected one).

Not done: the WW2 `veafSpawn-*` set. A template carries the editor's ROE and reaction options, which cannot be written from a table without checking them in DCS, and the dynamic-slot catalogue already gives players the WW2 aircraft. Written down as the known limitation `no-ww2-spawnable-aircraft-templates`.

## 04 — WW2 tables of `veafCasMission` reuse modern infantry and a Bradley

Status: ✅ done
Type: fix (data)
Files: `src/scripts/veaf/veafCasMission.lua` (`INFANTRY_TYPES`, `INFANTRY_IFV_TYPES`), the test that sweeps the tables

### What happens

For `veaf.ERA.WW2` the tables are almost right (armour: Sd.Kfz 251/234, Pz IV, Tiger, Panther; Sherman, Cromwell, Churchill; trucks: Opel Blitz, Willys, CCKW), except:

- `INFANTRY_TYPES[BLUE|RED][WW2]` is the **modern** list: blue `Soldier RPG`, `Soldier M249`, `Soldier M4 GRG`, red `Paratrooper RPG-16`, `Infantry AK ver3`, `Infantry AK ver2`. The database has `soldier_wwii_us`, `soldier_wwii_br_01` and `soldier_mauser98`.
- `INFANTRY_IFV_TYPES[BLUE][WW2]` tiers 3 to 5 are `M-2 Bradley`. `M2A1_halftrack` is the tier 1-2 entry; tier 3+ should be heavier WW2 vehicles (`M8_Greyhound`, `Daimler_AC`), not a Bradley.

So `-infantry`, `-combat` and the `_spawn infantrygroup` family put an M4-armed modern rifleman, or a Bradley, in front of a Tiger.

### Done when

The era sweep (the test that checks every entry against the database) also checks that no `WW2` entry is a type dated after 1945 — give the database an era per unit, or keep a short WW2 allow-list in the test. The tables above are corrected.

### Done

`INFANTRY_TYPES[BLUE|RED][WW2]` are now `soldier_wwii_us` / `soldier_wwii_br_01` and `soldier_mauser98`; `INFANTRY_IFV_TYPES[BLUE][WW2]` tiers 3 to 5 are `M8_Greyhound` and `Daimler_AC`. One correction: tiers 1-2 hold `APC M2A1 Halftrack`, the display name of `M2A1_halftrack` (the lookup takes either). The era sweep gained `test_every_ww2_entry_is_a_type_of_the_era`, with a short allow-list of WW2 types; it was checked to fail against the old tables.

### Also measured: WW2 anti-aircraft guns cannot move

On 2026-10-13, in DCS, `Unit:getDesc().speedMax` of every WW2 anti-aircraft type of the database is **0**: `flak18`, `flak30`, `flak36`, `flak37`, `flak38`, `flak41`, `bofors40`, `QF_37_AA`, `M1_37mm`, `M45_Quadmount` (against `Pz_IV_H` 10.6, `Sd_Kfz_251` 14.7, `Sd_Kfz_7` 13.9, `Sd_Kfz_234_2_Puma` 25, `M2A1_halftrack` 20 m/s). A convoy group holding one ran at 4-5 m/s instead of the 11 m/s written on its route (three convoys, 586 m in 120 s). `generateAirDefenseGroup-*-WW2-*` and any convoy whose `defense` adds air defence therefore build WW2 convoys that crawl; the era tables should give WW2 convoys no AA (or armed light vehicles), and the guide should say so.

Not done in this lot: the DCA of the WW2 convoys (the era tables still give a convoy `defense` pieces that cannot move). It goes with ticket 15, which measures the convoy speed.

## 05 — `list_shortcuts` gives no era, and WW2 has no radar or artillery alias

Status: ✅ done
Type: feat (small)
Files: `veaf_libs/data/veaf-units.yaml`, `veaf_mission_mcp/oracle.py` (list_shortcuts), the action's description, the authoring skill

### What happens

Building a WW2 mission through the MCP, an agent must discover by experiment which aliases follow `mission.era`. `-aaa`, `-samSR`, `-samLR`, `-samVLR`, `-armor`, `-transport` do (`generateAirDefenseGroup-<SIDE>-WW2-<n>` groups exist: flak 18/36/37/38/41, KDO Mod 40, Flakscheinwerfer, Bofors, QF 3.7, M45) — but the output says « Random SAM battery », « Random medium range air defense group », and nothing about era. The ones that do **not** follow it and give modern equipment in a WW2 mission:

- `-blue_ewr` (FPS-117 dome), `-ewr` (55G6), `-dogear`: no alias for the units WW2 does have, `FuMG-401` (Freya), `FuSe-65` (Würzburg), `Allies_Director`;
- `-arty` (M-109), `-mlrs`, `-grad`…: the WW2 field guns `LeFH_18-40-105`, `Wespe124`, `Pak40`, `M2A1-105`, `M12_GMC` have no alias;
- `-convoy`, `-hv_convoy_red`, `-attack_convoy_red` use « RU supply convoy » groups.

The Normandy Open Training placed radars and field guns as native groups of literal types.

### What ships

- Each `commands` / `groups` entry of `list_shortcuts` carries `eras` (the eras its output is correct for, or `follows_era: true`); the authoring skill says to read it.
- WW2 aliases for radars and artillery (names to settle with David): `-freya`, `-wurzburg`, `-flak88`, `-lefh`, `-pak40`, `-wespe`.
- `validate` warns when a `#command` / `#veafInterpreter` alias is not correct for `mission.era`.

### Done when

`list_shortcuts` can be filtered by era; the WW2 radars and field guns have aliases; `validate` flags `-sa6` in a WW2 mission.

### Done

`veaf_libs/shortcut_eras.py` reads the era of a shortcut from what it runs, so a new alias cannot be left unlabelled: `follows_era` (the `_spawn` kinds that go through `veafCasMission.generate*`, `convoy` and `_cas`), `ww2`, `post_ww2`, `era_free`, `unknown` (`-jtac`, `-afac`, `-cargo`: not measured, so not claimed). `list_shortcuts` carries it on every unit, group and command, and takes `era` to filter. `validate` warns about a `#command` or `#veafInterpreter` of a `post_ww2` shortcut in a WW2 mission (a warning, not an error: an unknown one is not claimed). Six WW2 aliases with the names the ticket proposed — `-freya`, `-wurzburg`, `-flak88`, `-lefh`, `-pak40`, `-wespe` — German, one battery each; the names are the ticket's, to be confirmed.

Corrections: `-blue_ewr` and `-dogear` are `blue-ewr` and `dogear` in `veaf-units.yaml`; `-convoy` does follow the era (`spawnConvoy` calls the transport and armour generators), while `-hv_convoy_red` and `-attack_convoy_red` do not.

Not verified in DCS: the six aliases resolve to their unit or group (a test holds that), but none has been spawned in game. They name no country, so they take the coalition of the unit that carries them (`country GERMANY` hit ticket 14's case on a Third Reich mission).

## 06 — A Fw 190 tunes 38.4-42.4 MHz only: the plan has no role for it

Status: ✅ done — narrowed; the proposed feature rests on a wrong premise
Type: feat
Files: `presets_injector/presets_injector_worker.py` (l. 323), `presets_injector/data/dcs-radio-layouts.yaml`, `doc/developer/radio-preset-projection.en.md`, tests

### What happens

`primary_2` is « the warbirds' single radio », VHF band. The build log for the Normandy Open Training says: « FW-190A8 (121.5 MHz, primary limited to 38.4–42.4 MHz), FW-190D9 (…) : le canal 1 est hors de la plage de fréquence principale accordable de l'appareil ; le groupe conserve donc sa propre fréquence (les préréglages sont injectés normalement) ». So a red Fw 190 flies on its default radio, whatever the plan says, and the kneeboard lists VHF frequencies the aircraft cannot tune. The Bf 109 K-4 (38-156), P-51D, P-47D, Spitfire and Mosquito (38-156 or 100-156) are fine; the tower FM frequencies of the Normandy airfields are 38.4-42.4 MHz — exactly the Fw 190's band (`describe_airfield_channels`: every base has `fm`).

The mission worked around it with a manual `presets_assignments` (`FW-190A8`/`FW-190D9` → a `radios_collection` of type `fm` carrying the red bases' `fm` frequencies, `tools/gen_12_presets.py`).

### What ships

- A role for an aircraft whose only radio is narrower than the VHF band: the packer takes the channel's `fm` frequency when the radio's range only covers it (`radio-specs`: `FW-190A8` `min 38.4 max 42.4`), instead of dropping the channel and keeping the group's own frequency.
- The log line says which frequency the type got, not only what it could not.

### Done when

With a red `primary_2` list of bases, a Fw 190 slot gets the bases' FM frequencies without a hand-written assignment; a P-51D still gets VHF.

### Done

The finding is mostly wrong. A Fw 190's radio is a FuG 16 Z that tunes **38–156 MHz** as presets (`radios[0].ranges`); only the group's *primary frequency* is limited to 38.4–42.4 MHz (`human_radio`). So the plan's VHF channels are injected and tunable — the build log says « les préréglages sont injectés normalement » — and nothing the kneeboard lists is out of the aircraft's reach. What stays true is that channel 1 cannot become the primary frequency, and the group keeps its own.

The log line now says what the type got, not only what it did not: `FW-190A8 (134.0 MHz, primary limited to 38.4–42.4 MHz, stays on 38.4 MHz)`. The harm the Normandy session actually met is ticket 13: the group's own frequency was 251 MHz, which the editor refuses.

Left to David: whether the first plan channel that *fits* the primary range (a base's FM tower frequency, 38.4–42.4) should become the Fw 190's primary instead of its default. It is a packer design change (the role carries `fm` channels that are skipped for promotion today), not a defect, and nothing in the build needs it.

## 07 — The red WW2 dynamic-slot templates carry `gun: 0`

Status: 🚫 wontfix — closed by David on 2026-10-14 (« on verra bien en jeu »): not measured, templates unchanged; the known limitation `ww2-slot-templates-carry-gun-zero` stays and says what to check
Type: investigate, then fix
Files: `src/defaults/mission-folder/src/dynamic-slot-templates.yaml`, the generator of the catalogue

### What happens

In the shipped catalogue the blue WW2 templates (`P-47D Template`, `P-51D Template`, `Spitfire Template`, `Mosquito Template`…) carry `payload.gun = 100`, and the red ones — `Bf-109K4 Template Red`, `FW-190A8 Template Red`, `FW-190D9 Template Red` — carry `payload.gun = 0` (fuel 296, 409 and 388). A dynamic slot is spawned from its template: if `gun` is the gun-ammunition percentage, a red WW2 pilot takes off with no cannon ammunition. A group built by `add_air_group` for the same types gets `gun = 100` (checked in the Normandy mission), so the AI is armed and the player may not be.

Not established: whether DCS reads `gun` for the Bf 109 and Fw 190 at all (their guns may be set by the pylons or a `settings` table), which is why this ticket starts with a test in the game: a red slot from the template, a red slot from `add_air_group` with `gun = 100`, `Ctrl+Shift+W`-style loadout screen and a trigger-happy five seconds.

### Done when

The first sentence of the cause is a fact (measured in DCS), and the red templates carry what the Mission Editor writes for a default Bf 109 K-4 / Fw 190 A-8 / D-9.

### Checked, not done

The shipped `dynamic-slot-templates.yaml` read on 2026-10-13: the finding is wider than written. `gun: 0` is on the `Bf-109K4`, `FW-190A8`, `FW-190D9`, `F4AU-1D` and `TF-51D` templates on **both** sides (ten groups); the P-47D, P-51D, Spitfire, Mosquito, I-16 and La-7 templates carry 100. Whether DCS reads `gun` for these types is still the open question, so nothing was changed: the templates are the editor's own export, and a guess at their shape would be written into every mission.

Written down as the known limitation `ww2-slot-templates-carry-gun-zero`, with the in-game check that settles it (a slot from the template, the loadout screen, a burst of fire). If the ammunition is zero, set `gun: 100` on the ten templates.

## 08 — Ship the Normandy parking capture and (decide) the elevation grid

Status: ✅ done — the elevation grid is still David's decision
Type: data
Files: `src/python/veaf-tools/veaf_libs/data/parking/Normandy.json` (new), `veaf_build/dcs_data/airbase_dumps/parking/Normandy.json`, known limitation `no-parking-data-outside-three-theatres`, `veaf_libs/terrain_elevation.py`

### What happens

`describe_known_limitations` says no ramp or runway start works through the MCP outside Caucasus, Persian Gulf, Syria and Sinai (Falklands data exists as an untracked file in the checkout). On Normandy every QRA starts in the air and a client slot at a parking needs a hand edit, until someone runs the capture.

Captured on 2026-10-13 with `veaf-tools dcs capture-map --parking` (3 716 stands on 90 airfields), slimmed with `veaf_build.dcs_data.parking.slim_dump` and installed in this workstation's checkout, **untracked** (`parking/Normandy.json`, 411 574 bytes): with it `create_qra` starts from the runway, and `add_air_group(start="parking-hot", airfield="Tangmere")` gives stand 8. Same state as `SinaiMap.json` was in FEAT-SINAI-PARKING-DATA.

Two things the Normandy session also hit, both already in the Sinai retours (entry 8, entry 3):

- `capture-map --parking` writes the raw format that `add_air_group` does not read; the maker has to call `slim_dump` from a VMCT checkout by hand. The command could write the slim file or say how.
- The elevation grid is not shipped (« a theatre weighs some 5.5 MB at 250 m »): `Normandy.terrain` is 1.2 MB here (3 061 121 cells, ground 0-667 m). Deciding whether to ship the grids is the Sinai ticket's question; the Normandy file is the smallest one so far.

### Done when

`Normandy.json` (parking) is committed and the known-limitation list says four-plus-two theatres; the decision on the grid is written down.

### Done

`veaf_libs/data/parking/Normandy.json` is committed (3 716 stands on 90 airfields, checked by a test); the known limitation `no-parking-data-outside-three-theatres` says six theatres. `capture-map --parking` now ends with the command that slims the dump (`veaf-build update-dcs-data --parking`, from a VMCT checkout), instead of leaving the maker with a raw file `add_air_group` does not read. The raw dump itself is not committed, as for Sinai.

Decision left to David, as for Falklands: the Normandy elevation grid (1.2 MB, the smallest so far) is **not** delivered; no theatre ships its grid today.

## 09 — `terrain-sweep` waits forever on a `dcs-serve` that died, and re-keys a mission the maker already opened

Status: ✅ done — first and third bullets; the second rests on something that is not in the code
Type: fix
Files: `veaf_tools/commands/clear_ground.py` (l. 362 and the wait loop), `veaf_libs/locales/fr.json` (`cmd.clear_ground_sweep.serve_running`), `veaf_libs/dcs_serve_launcher.py`, tests

### What happens

On 2026-10-13, `veaf-tools dcs terrain-sweep Normandy` found a `dcs-serve` on :8080 (« dcs-serve tourne déjà sur http://127.0.0.1:8080 : il est utilisé tel quel »), wrote the survey mission and waited for the bridge. That `dcs-serve` — started by another session — exited a few minutes later. The sweep process stayed alive, silent, for about twenty minutes while DCS's bridge logged « no connection for 30s — retrying » against a closed port. Nothing in the sweep's output said the server was gone.

When the maker (and I) relaunched the sweep with `--dcs-serve <exe> --config <yaml>`, it started a fresh `dcs-serve`, **generated a new API key** and **rewrote `veaf-survey-Normandy.miz`** with it: the copy the maker already had open in DCS carried the old key and could not connect; the maker had to reload the mission. The message did say « sa clé d'accès a été générée », not that an open mission is now stale.

### What ships

- The wait loop checks the server every few seconds; if it stops answering, say so once (« dcs-serve ne répond plus sur … ») and either restart it (when the command launched it) or exit with the command to relaunch.
- Reuse the key already in the configuration file when the file exists, so a rewritten survey mission keeps the key the open one has; when the key must change, write « rechargez la mission d'arpentage dans DCS » in the instructions.
- A timeout on the wait (`--wait` exists for `clear-ground-check`; `terrain-sweep` has none) with a message at half time.

### Done when

Killing `dcs-serve` during a sweep gives a one-line message within 15 s; relaunching does not invalidate an open survey mission.

### Done

The wait loop asks `is_serving` when a call fails: a `dcs-serve` that no longer answers stops the sweep at once with `cmd.clear_ground_sweep.serve_gone` (the wait polls every 3 s), and the wait says once, at half time, that the survey mission has not answered. It serves every command that opens a survey session, not `terrain-sweep` alone.

Corrections: `terrain-sweep` **has** a `--wait` (900 s by default) and a deadline, which is what ended the twenty minutes; and the survey mission does not carry the API key — `build_survey_mission` takes none, the key is the client's credential for `dcs-serve`, and `ensure_config` already keeps the key of an existing `dcs-serve.yaml` in the working folder. A relaunch that started a *new* server in another folder got a new key, but nothing was written into the open mission. So there is no « rewritten mission with a stale key » to fix, and no « reload the survey mission » to say. Not done either: restarting the server when the command launched it — it exits with the command to relaunch.

## 10 — `describe_known_limitations` is 74 000 characters: it overflows the agent's tool result

Status: ✅ done
Type: feat (small)
Files: `veaf_mission_mcp/actions.py` (`describe_known_limitations`), `veaf_libs/data/known-limitations.yaml`, the authoring skill

### What happens

The Open Training prompt tells the agent to read the limitations first. The result is 73 957 characters over 591 lines (`veaf_tools_version 6.29.0`): the client refuses it (« exceeds maximum allowed tokens ») and saves it to a file, which the agent reads back in 300-line pieces — about 19 000 tokens, of which a WW2 Normandy mission needs perhaps ten entries. Ticket 14 of FIX-OPEN-TRAINING-SYRIA-FINDINGS did the same for `list_catalog`.

### What ships

- `describe_known_limitations(area=…, theatre=…, full=false)`: by default the `id`, `kind`, `area`, `title` and the one-sentence workaround of each entry (about 8 000 characters); `area` filters (`spawning`, `air-defence`, `players`, `radio`, `mcp`, `runtime`, `pipeline`, `scripting`); `full` returns today's text; `describe_known_limitations(id=…)` returns one entry.
- The prompt says: read the short list, then the entries of your areas.
- Entries that only concern one theatre (`no-parking-data-outside-three-theatres`, `marianas-placement-checks-nothing`) carry `theatres: [...]` so `theatre=` drops the others.

### Done when

The default call fits comfortably in a tool result and each long entry is one call away.

### Done

`describe_known_limitations` with no argument returns a short listing — `id`, `kind`, `area`, `title`, and the count of each area — about 12 400 characters instead of 74 000. The ticket's « about 8 000 characters with the one-sentence workaround » does not hold: the titles alone are 6 000. `area`, `kind` or `id` (one or a list) return the entries in full; `theatre` drops the entries whose `theatres` list does not name it (`no-parking-data-outside-three-theatres` and `marianas-placement-checks-nothing` carry one); `full` returns everything. The skill, the Open Training prompts and the developer doc say to read the short list first.

## 11 — `theatre-bounds.yaml` has four theatres: `geocode` resolves « Omaha Beach » in Iowa without a warning

Status: ✅ done
Type: fix (data)
Files: `src/python/veaf-tools/veaf_libs/data/theatre-bounds.yaml`, `veaf_mission_mcp/geo.py` (l. 125-143), tests

### What happens

`theatre-bounds.yaml` lists `caucasus`, `syria`, `persiangulf`, `marianaislands`. For any other theatre `bounds is None`, so `geocode` sends no Nominatim `viewbox` (geo.py l. 142-143) and sets `in_theatre_bounds = True` (`bounds is None or …`). On Normandy: `Omaha Beach` → « Omaha Beach, Okoboji, Dickinson County, Iowa » (x 5 595 880, y −6 634 842), `in_theatre_bounds: true`, no warning. The same hole shows on Sinai (« El Qantara » → Lebanon, « Mount Sinai » → New York: Sinai retours entry 5), Germany CW, Falklands, Afghanistan, Nevada and The Channel. Every other Normandy place resolved correctly because the names were unambiguous; the one that was not went unnoticed until the x was read.

### What ships

- The missing boxes: `normandy` (lat 48.3-51.7, lon -2.9-3.0, from the airfield extents: x −118 842…229 644, y −166 232…205 059), `sinaimap`, `germanycw`, `falklands`, `afghanistan`, `nevada`, `thechannel`, `marianaislandswwii`. Derive them from `airdromes.yaml` with a margin rather than typing them.
- A theatre with no box returns `in_theatre_bounds: null` and a warning « no bounds for this theatre — the point is not checked », not `true`.
- A test asserts every theatre of `dcs-maps.yaml` has a box.

### Done when

`geocode("Omaha Beach")` on a Normandy folder returns a point in Calvados; a theatre with no box warns.

### Done

Nine boxes added, derived from the airfield extents of `airdrome-positions.yaml` with one degree of margin: Afghanistan, GermanyCW, Iraq, Kola, MarianaIslandsWWII, Nevada, Normandy, SinaiMap, TheChannel. Correction: the file had **five** theatres, `falklands` included, and the missing ones were nine — Iraq and Kola were not in the ticket's list. A test asserts every theatre of `dcs-maps.yaml` has a box, and that each derived box holds its airfields. A theatre with no box returns `in_theatre_bounds: null` and a warning instead of `true`.

## 12 — The Open Training prompt assumes a modern theatre; WW2 needs its own rules

Status: ✅ done
Type: doc
Files: `.prompts/new-open-training-mission.fr.md`, `.prompts/new-open-training-mission.en.md`

### What happens

Building the Normandy 1944 mission from the prompt, most sections had to be re-read against the era, and each reading was a decision the prompt did not make:

- **4.3 support**: « au moins 2 ravitailleurs, au moins 1 AWACS ». 1944 has none, and DCS has no WW2 tanker or AWACS. The Normandy mission places none (and says so in the briefing) rather than an E-3 or a KC-135.
- **4.1 / 4.11 FARP, CTLD, CSAR, `ctld-config.yaml`, drones laser, carriers (« toujours deux porte-avions »)**: no WW2 helicopter, no WW2 carrier in the module list. The modules are switched off (`CTLD: false`, `CSAR: false`, `CARRIER: false`, `SKYNET: false`), not left on for nobody.
- **4.5 / 4.6 air defence and training families**: « SAM courte, moyenne, longue portée », « SEAD », « hélicoptères ». The WW2 equivalents are flak (20, 37, 88 mm: `-aaa`, `-samSR`, `-samLR`, `-samVLR` all follow `mission.era`), the SEAD family becomes antiflak, the helicopter family becomes close air support; the 3 × 3 shape and `includes:` are unchanged. Skynet and its EWR have no meaning; Freya/Würzburg radars are native groups (ticket 05).
- **4.8 QRA, 4.9 CAP**: « emport (pylons, payload, loadout_from) » — gun-only fighters have none to give (tickets 01, 02).
- **4.12, 4.13**: scenarios work (Ju 88 raid, B-17G escort, recce intercept); the F10 drawings and OSM maps work unchanged.

### What ships

A section « Époques sans ravitailleur, sans hélicoptère ou sans SAM » (and the English twin) that says, for WW2 (and for Cold War where it differs): what to leave out, what takes its place, which modules to disable, how to write the briefing about it. Also in §1: ask the era **before** the template, since it changes the template's answer (`full` is for a modern theatre).

Add to §0.3 (« Retours pour VMCT »): the DCS session the build needs — a terrain sweep and a parking capture are two commands run **together**, with `dcs-serve` started once.

### Done when

A WW2 map built from the prompt needs no unwritten decision about tankers, helicopters or SAMs.

### Done

Section 4.14 « Époques sans ravitailleur, sans hélicoptère ou sans SAM » in both prompts, as a table (what the prompt asks, what WW2 has, what to do) and the rule for `post_ww2` aliases; § 0.3 says the terrain sweep and the parking capture run together with one `dcs-serve`; § 0.2 says to read the short listing of the known limitations first. Correction: the era was already asked **before** the template (questions 2 and 3); what was missing was saying why, and what the template becomes in WW2 — added.

## 13 — `add_air_group` writes 251 MHz on every group: the Mission Editor refuses to save a WW2 player group

Status: ✅ done
Type: fix
Files: `veaf_mission_mcp/add_air_group.py`, `veaf_mission_mcp/aircraft_identity.py` (or wherever `frequency` is set), `presets_injector/data/dcs-radio-specs.yaml`, tests

### What happens

Seen by David on 2026-10-13 opening the Normandy test mission in the Mission Editor and saving it: « Mission cannot be saved due to errors! TEST P-51D Tangmere: Invalid frequency 251 MHz — Arène rouge Fw 190 A-8: Invalid frequency 251 MHz — Arène rouge Fw 190 D-9: Invalid frequency 251 MHz ».

`add_air_group` gives every group `frequency = 251.0`, `modulation = 0` (read in `src/mission/mission`). The editor checks a **player** group's frequency against the radio of its type: P-51D 100-156 MHz, Fw 190 38.4-42.4 (`dcs-radio-specs.yaml`, `human_radio.min_mhz/max_mhz`), so the three client groups above cannot be saved. A modern UHF aircraft accepts 251; a mission built by the build alone (no save in the editor) runs, which is why the build, `validate` and 1 800 lines of checks did not see it.

The Normandy folder fixes it after the fact with `tools/fix_frequencies.py` (rewrites the table with `human_radio.default_mhz`: 35 groups).

### What ships

- `add_air_group` (and `add_player_slot`) set the group frequency to the type's `human_radio.default_mhz` when the type is in `dcs-radio-specs.yaml`, falling back to 251.0 only for a type with no spec; clamp into `[min_mhz, max_mhz]` otherwise.
- `validate` reports a group whose frequency is outside every range of its type's radios (warning for AI, error for a `Client`/`Player` group).

### Done when

A P-51D and a Fw 190 `Client` group created by `add_air_group` carry 124.0 and 38.4 and save in the Mission Editor without error; `validate` flags a P-51D at 251.

### Done

`veaf_mission_mcp/aircraft_radio.py`: a new group takes 251 MHz **when its airframe can tune it**, else the type's own `default_mhz` (124 for a P-51D, 38.4 for a Fw 190) — the ticket's « always `default_mhz` » would have moved a F-16 from 251 to 305 MHz for no reason. `add_air_group`, `add_player_slot` and the composites (`create_qra`, `create_cap_mission`) use it; an explicit frequency the airframe cannot tune is refused for a `Client` or `Player` group and warned about for an AI one. `validate` warns (not an error: the preset step rewrites a player group's frequency, so the source table is not always the last word) about a group whose frequency its airframe cannot tune.

Not done: the Mission Editor was not opened on a built mission; the claim is that the three groups of the report now carry 124.0 and 38.4, which a test holds.

## 14 — A `country` that belongs to no coalition makes a battery spawn neutral and stop on `networkName nil`

Status: ✅ done
Type: fix
Files: `src/scripts/veaf/veafSpawnCore.lua` (l. 455-472, the Skynet block), `src/scripts/veaf/veafSpawnGround.lua` (`spawnAirDefenseBattery`), `src/scripts/veaf/veafSpawnParser.lua` (l. 104-106, `country`), `veaf_tools` validate, tests

### What happens

Measured in DCS on 2026-10-13, Normandy Open Training test mission (LOCAL_TEST build), probing the training zones one level at a time with `veafCombatZone.ActivateZone`:

| zone | units alive | statics |
|---|---|---|
| `combatZone_Bocage_Easy` (natives and statics only) | 9 | 3 |
| `combatZone_Bocage_Medium` (adds `-aaa` and `-armor` carriers) | 1 | 1 |
| `combatZone_Aurigny_Easy` (one `-samSR` carrier) | 0 | 0 |

`dcs.log`, after each battery logs its units, then every ~19 s: `ERROR VEAF-SCHEDULER|E|: error in scheduled function … attempt to concatenate local 'networkName' (a nil value)` (`veafSkynet.addGroupToNetwork`, the `debug("ADD GROUP START … [" .. networkName .. "]")` line). The zone's later elements never spawn.

Cause, read from the log line `spawnAirDefenseBattery(czName=…, country=GERMANY, side=0, …)` and checked in the running mission with `coalition.getCountryCoalition`: the carrier names read `#command="-samSR, country germany"`. `Germany` (id 6) is in **no coalition** of this mission (neutral, 0). Its red coalition holds `Third Reich` (id 66, `country.id.THIRDREICH`). So the spawn side is 0; `veafSpawnCore.lua` l. 457-459 then does `networkName = veafSkynet.defaultIADS[tostring(options.side)]` — no default network for side 0 — and calls `addGroupToNetwork(nil, …)`. The same carrier names with `country thirdreich` are what the mission now uses. (A first diagnosis blamed the disabled SKYNET module; it was wrong — the error is identical with the module on, and the mission runs with it off.)

Nothing at authoring or build time says the country is wrong: `validate`, the build and `veaf-config.lua` pass, and `country germany` is the natural spelling of a German battery. The documented example of the prompt, `country russia`, only works because Russia happens to be in the red coalition of the missions built so far.

### What ships

- `veafSpawnCore` (Skynet block): when `networkName` is nil, skip the declaration with one `warning` (« no default network for side %s: the group is spawned and not declared to Skynet »), instead of erroring; so a zone never loses its remaining elements to it.
- `spawnAirDefenseBattery` and the other `_spawn … country X` paths: when `country X` is in no coalition, say so in the log (`warning`) and take the side of the carrier unit (the guide already says « a fake-unit spawns in its own coalition »).
- `validate` warns when a `#command` / `#veafInterpreter` name carries `country X` and X is in no coalition of the mission (the build writes the coalitions: use them), naming the countries that are.
- The prompt (ticket 12) and the authoring skill: « the country of an alias must be one of the coalition's countries; for a Third Reich mission it is `thirdreich` ».

### Done when

A WW2 folder whose carriers say `country germany` activates its zones with every element spawned, one warning logged; `validate` flags `country germany` in a Third Reich mission and names `thirdreich`.

### Done

`veaf.resolveSideAndCountry` (`veaf.lua`): a `country X` in no coalition spawns in the coalition of the command's own unit, with a country of that coalition, and one `warning` naming both; used by the spawn core, so every `_spawn … country X` path gets it (the CAS-mission path, `veafCasMission.lua`, still reads the side itself). The Skynet block of `veafSpawnCore` skips the declaration with a warning when the side has no default network, instead of calling `addGroupToNetwork(nil, …)`. `validate` warns about a `#command` or `#veafInterpreter` whose `country` is in no coalition of the mission, naming the countries that are (`thirdreich` and `Third Reich` are the same country). The authoring skill and the Open Training prompt say the country must be one of the coalition's.

Tested with Lua mocks (the helper, three cases) and Python (the validator), then in DCS on 2026-10-13, Normandy test mission, by `veafInterpreter.execute` on the red side: `-samSR, country germany` (coalition 0 here) spawns its battery red under `cjtf red` with the warning `country [GERMANY] is in no coalition of this mission`; `-samSR, country thirdreich` spawns under Third Reich with no warning; with the red side's default Skynet network removed for the test, the battery spawns, one `no default Skynet network for side 1` warning is logged and no `networkName nil` error follows. A whole zone activating with `country germany` carriers was not run.

## 15 — A native convoy in a combat zone drives at 5.1 m/s whatever speed its route says

Status: 🚫 wontfix — not a defect: measured in DCS, the convoy reaches its written speed after about three minutes
Type: investigate
Files: `src/scripts/veaf/veafCombatZone.lua`, `src/scripts/veaf/veafDcsSpawner.lua` (l. 315, 504-508), `src/scripts/veaf/veafGroundAI.lua`, `veaf_mission_mcp/create_combat_zone.py`

### What happens

Measured in DCS on 2026-10-13 on the Normandy test mission (LOCAL_TEST build), three convoys activated through `veafCombatZone.ActivateZone`. Route written in the mission table (checked in the built `.miz`): every point `On Road`, `speed = 11.1` m/s, `speed_locked = true`. Units alive in the group: the first convoy had a `flak38` (`speedMax` 0 — ticket 04); it was removed and the three groups rebuilt with only mobile vehicles (`Pz_IV_H` 10.6, `Sd_Kfz_251` 14.7, `Blitz_36-6700A` 25, `Sd_Kfz_234_2_Puma` 25 m/s). Re-measured on the rebuilt mission, `ConvoiCoutances`, `Unit:getVelocity()` of every unit at 40, 85 and 130 s: the lead vehicles hold **5.1 m/s** (the other units start one after another and then follow at 4.9-7 m/s). Over 120 s the leader of each convoy covered 571, 737 and 572 m: 4.8-6.1 m/s, i.e. about 18 km/h, below every unit's `speedMax`.

5.14 m/s is exactly 10 knots; the Sinai Open Training measured 2-3 m/s against 5.6 written (FIX-OPEN-TRAINING-SINAI retours 13, « 20 km/h »). Whatever it is, the speed in the route is not what the group drives at once the zone respawns it: either the respawn (`VeafGroupSpawn:respawn()` → `veafDcsSpawner.addGroup`, lines 315 and 504-508, `unit.speed = unit.speed or defaults.speed`) writes its own speed on the units and points, or the ground AI re-tasks the group.

### What ships

1. Find where the speed is overwritten: dump the group table `veafDcsSpawner.addGroup` hands to `coalition.addGroup` for a native convoy (log it at `trace`), and compare with the mission's.
2. Keep the route's speed for a native vehicle group respawned by a zone, as the route is already kept.
3. A test that spawns a convoy zone and asserts the table passed to `coalition.addGroup` keeps the route speed.

### Measured instead of fixed

Measured in DCS on 2026-10-13, Normandy test mission, scripts of the branch (dev mode); nothing was changed in the end.

- A convoy zone's leader holds 4-6 m/s for the first two minutes and the **rear vehicles start at 0 m/s** (units 3 to 9 at 0.0-2.2 m/s after 20 s, 100-210 m behind the leader). At about 60 s the column is 460 m long and still ragged; at about 200 s every vehicle of `combatZone_ConvoiLisieux` runs at **10.0-11.1 m/s**, spaced 30 m apart. The probe read the speed 15, 75 and 135 s after activation: it measured the column forming up, not a cap.
- One `Blitz_36-6700A` alone on the same route, spawned through `veaf.addGroup`, reaches **9.3 m/s after 15 s and 11.1 m/s after 45 s** — with the route's speeds locked and without.
- So the route's speed is not overwritten, the road does not cap it, and the lock hypothesis of this ticket (`speed_locked` lost by `getGroupRoute`) was tested and is **false**: a locked route sent to the running convoy changed nothing, and the code written for it was removed.

What remains true: a convoy spawned in a zone takes about three minutes to drive at its speed, because its vehicles start in a column that DCS unwinds slowly; and the WW2 anti-aircraft guns cannot move (ticket 04), which does slow a convoy that holds one for good.

The Normandy folder's `tools/probe_zones.py convois` reads at 15, 75 and 135 s: it should read after four minutes (it would then have shown 10-11 m/s).

## Attached file — DCS-CHECKS.md

### DCS checks — FIX-OPEN-TRAINING-NORMANDY-FINDINGS

What the lot changed and could not be run in DCS here. Done on 2026-10-13 and removed from the table: ticket 15 (see its file: not a defect) ticket 14's three checks (`country germany` spawns red as `cjtf red` with the warning, `country thirdreich` spawns without one, a side with no Skynet network spawns with the `no default Skynet network` warning and no `networkName nil` error) and ticket 05's six aliases (each spawns its radar or battery on the red side, country CJTF Red, with the spawn data of the branch).
Run them on the Normandy test mission (LOCAL_TEST build, `--dev-mode` so it reads the built `veaf-scripts.lua`), one at a time; the answer is in the last column.
`dcs.log` is `C:\Users\David\Saved Games\DCS\Logs\dcs.log`.

| # | Ticket | Do | Expect | If not |
|---|---|---|---|---|
| F | 07 | Take a slot from the `FW-190A8 Template` (then `Bf-109K4`, `TF-51D`): loadout screen, then fire a burst | cannon ammunition shown and fired | zero: set `gun: 100` on the ten templates (known limitation `ww2-slot-templates-carry-gun-zero`) |
| G | 13 | Open the built mission in the Mission Editor and save it | saves without `Invalid frequency` | |
