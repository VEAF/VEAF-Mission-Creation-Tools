# FIX-OPEN-TRAINING-PILOT-FEEDBACK — Helicopter hard tier and QNH in inHg

Status: ✅ done · archived 2026-11-24

David, 2026-11-15, after flying the Open Trainings:

1. "The helicopter training in hard mode is really the medium level. The real hard mode would be with Tors or Tunguskas and the like."
2. "The radio menus must be reordered: the combat zone menu should not be at the very bottom, on the second page."
3. "For the weather display, whether when you arrive in an aircraft or when you ask for the ATIS, we need the QNH in inches of mercury as well as in hectopascals."

4. "The northern helicopter training zone of Syria, near YF69, is rotten: it is in the middle of a forest. Training zones should not be in forests, units spawning hidden in a wood make no sense."

## Point 2 is already done, not yet shipped

FEAT-RADIO-MENU-ORDER (✅ 2026-11-10) fixed the order of the root menus: combat zones come second, right after the campaign menu, in every language.
It sits under `[Unreleased]` in `CHANGELOG.md`: the last release is 6.36.0 (2026-11-05), so no Open Training carries it yet.
It reaches the players with the next VMCT release followed by a `Publish-OT`. Nothing to do in this lot.

## Point 1 — the helicopter tiers

Six Open Trainings carry three helicopter tiers (Caucasus: `Kobuleti - hélicoptères - facile/moyen/difficile`; Falklands, Marianas, Persian Gulf, Sinai and Syria: `H1/H2/H3 Hélico <place> — facile/moyen/difficile`).
On Caucasus, measured in its `mission.yaml`: easy = inert targets, medium = easy + two light AAA pieces out of four (ZU-23, Shilka), hard = medium + three IR short-range systems out of SA-13, SA-9 and MANPADS.
No radar-guided short-range system anywhere: the "hard" tier is what a helicopter crew meets on an ordinary day.

## Point 3 — the QNH

`veafWeatherData:toStringPressure` (`veafWeather.lua`) prints only the units of the unit system it is given.
The default system (`Icao`) and the ones for Caucasus airfields (`IcaoMetric`) and French army helicopters (`Metric`) list hPa only; the `Faa` family lists inHg only; `MetricEastern` lists mmHg only.
So a pilot in a non-US aircraft, or reading an ATIS on Caucasus, gets no inHg — and a US aircraft gets no hPa.
The METAR line already carries both (`Q1013/29.92`).

## Decisions — proposed 2026-11-15, defaults until David says otherwise

| # | Question | Default (reco) |
|---|---|---|
| D1 | The new tier ladder | Keep three tiers. **Medium** becomes what hard is today (AAA + IR short-range). **Hard** becomes medium + radar-guided short-range: SA-15 Tor, SA-19 Tunguska, SA-8 Osa, drawn like today (a few out of the list). The current medium (AAA only) disappears: easy (nothing) → medium (AAA + IR) is a fair step for a helicopter |
| D2 | Which units the QNH shows | **hPa and inHg in every unit system**, the eastern one keeping mmHg as a third. One line, the same for everybody, whatever the aircraft: the request is "as well as", and a US aircraft lacking hPa is the same defect seen from the other side |
| D3 | Briefings | Each changed tier's `briefing:` in the six `mission.yaml` is rewritten to say what is really there |

## Tickets

| # | Ticket | Status |
|---|---|---|
| 01 | [A real hard tier for the helicopter training](FIX-OPEN-TRAINING-PILOT-FEEDBACK.md) | ✅ |
| 02 | [The QNH in hPa and inHg everywhere](FIX-OPEN-TRAINING-PILOT-FEEDBACK.md) | ✅ |
| 03 | [Training ranges out of the forests](FIX-OPEN-TRAINING-PILOT-FEEDBACK.md) | ✅ |

Ticket 03 (point 4) is mission work in the same repositories, with a look in game on Syria where the forest probe is blind.
Ticket 01 is mission work in the six Open Training repositories (`VEAF-Open-Training-Mission-<theatre>-v6`), ticket 02 is Lua runtime in VMCT (`src/scripts/veaf/veafWeather.lua`, luaunit tests).
They are independent: 02 ships with the next VMCT release, 01 with the next `Publish-OT` of each mission.

## Tickets, in full

## 01 — A real hard tier for the helicopter training

Status: ✅ done

Files: in each of the six Open Training repositories (Caucasus, Falklands, Marianas, Persian Gulf, Sinai, Syria), the groups of the helicopter combat zones and their `briefing:` in `mission.yaml`.

### What to do

- Find where each tier's defences are placed (Mission Editor groups under the zone's prefix, or spawn commands) before changing anything; the layout may differ between Caucasus and the five `H1/H2/H3` missions.
- Apply D1: medium takes today's hard content (AAA + IR short-range), hard adds radar-guided short-range systems (SA-15 Tor, SA-19 Tunguska, SA-8 Osa), a few drawn out of the list.
- Place the new systems on clear ground, at a range from the targets that leaves a helicopter a way in by terrain masking: the point is training, not a wall.
- Rewrite the three briefings (D3).

### Done when

- In each of the six missions, the hard tier spawns at least one radar-guided short-range system and the medium tier no longer is AAA only.
- The briefings say what each tier holds.
- Each mission is rebuilt; the `Publish-OT` stays with David.

### Outcome (2026-11-16)

In each mission, the old hard groups (SA-13, SA-9, SA-18) were renamed into the medium tier without moving, and the hard tier got radar-guided markers in one `#spawngroup`, two of them drawn per activation.
Each launcher stands beyond the targets, away from the FARP, at the nearest point that keeps every blue base with slots out of its DCS range with 1 km to spare; `check_portees.py` then checked the tanker tracks and the other training families (VERDICT 0 in the five missions that have it).

| Mission | Hard tier radar launchers | Note |
|---|---|---|
| Caucasus (Kobuleti) | SA-15, SA-19, SA-8, 1.8–2 km south | Kobuleti airbase 12 km north-east |
| Falklands (Port Howard) | SA-15, SA-19, SA-8, 1.5 km south-west | |
| Marianas (Talofofo) | SA-15 4.5 km north, SA-19, SA-8 | the sea everywhere else at the distance a Tor needs from FARP Merizo |
| Persian Gulf (Berlin) | SA-19 ×2, SA-8 | no Tor: FARP Berlin is 6.3 km from the targets |
| Sinai (Arad) | SA-15, SA-19, SA-8 | the Tor sits halfway between the Texaco 2 and Arco 2 tracks, 12.5 km from each |
| Syria (Ceyhan) | SA-19 and SA-8, both always | no Tor within 3.5 km of the targets out of FARP Ceyhan's reach; the old `samgroup, defense 3`, which rolled an Osa one time in five, became two SA-13 markers in the medium tier |

The briefings are rewritten in each `mission.yaml` and in the generators that own them (`gen_07_entrainement.py`, `gen_06_entrainement.py`).
The one-shot scripts stay in each repository's `tools/` (`gen_07e_difficile_radar.py`, `gen_06e_kobuleti_radar.py`, `fix_ceyhan_range.py`).
The Reaper orbiting each range at 3,000 m now meets a Tor or an Osa on the hard tier; its asset note already says it can be shot down there.

## 02 — The QNH in hPa and inHg everywhere

Status: ✅ done

Files: `src/scripts/veaf/veafWeather.lua` (`veafWeatherUnitSystem.Systems`, `veafWeatherData:toStringPressure`), `test/lua/`, the weather page of `doc/` (FR and EN), `CHANGELOG.md`.

### What to do

- Apply D2: every pressure shown to a pilot (slot welcome message, weather menu, ATIS, combat zone weather) carries hPa and inHg; `MetricEastern` keeps mmHg as well.
- Check every caller of `toStringPressure` and of the `Pressures` list, including the carrier ATIS (`veafCarrierOperations.lua`, which picks `FaaNavy` or `MetricEastern`).

### Done when

- A luaunit test shows, for each unit system, the pressure string with both hPa and inHg, and fails on today's code.
- The doc page that describes the weather report says so.

## 03 — Training ranges out of the forests

Status: ✅ done

Files: the training combat zones of the Open Training repositories, starting with Syria.

### What happened

David, 2026-11-15: the northern helicopter range of the Syria Open Training, near YF69 (`H1/H2/H3 Hélico Ceyhan`, 8 km east of the Ceyhan FARP), stands in the middle of a forest; its units spawn hidden in the trees, which makes no sense for a training range.
It is the same defect as the Akamas range (moved 2026-11-12): on Syria the DCS probe behind `clear-ground-check` does not see some forests (`disposition-blind-to-akamas-forest` in `known-limitations.yaml`), so a clean check proved nothing there.

### What to do

- Move the three Ceyhan helicopter tiers to open ground, keeping the distance from the FARP short, and check the new spot by eye in game (F10 view or smoke on each unit), as was done for Akamas.
- Then go through every other training zone of the Syria Open Training the same way: the probe being blind, only a look in game tells.
- On the other theatres, run `clear-ground-check` on every training zone; any zone whose check is doubtful, or that a player reports, gets the same look in game.
- Widen the known limitation: it is not only the Akamas forest, and the Ceyhan range is a second measured case.

### Done when

- No unit of an Open Training training zone spawns in a wood, checked by eye on Syria and by `clear-ground-check` elsewhere.
- `known-limitations.yaml` names Ceyhan as a second case and `docs/agents/dcs-runtime-traps.md` is regenerated.

### Outcome so far (2026-11-16)

- Known limitation widened in #1280: `disposition-blind-to-akamas-forest` names the Ceyhan forest, where `clear-ground-check` of 2026-11-12 had called the range's 8 vehicles clear; `dcs-runtime-traps.md` regenerated.
- Syria: the whole Ceyhan family (three trigger zones, every target and marker of the three tiers, the Reaper 1 orbit, the F10 circle and label) moved by one vector, from 8.8 km east of FARP Ceyhan to 8.7 km due south of it, centre (212316, 2506), in the plain between Körkuyu and Kurtkulağı (`tools/fix_ceyhan_range.py` of the Syria repository). OpenStreetMap shows farmland at both places, the old one included, so it says nothing about DCS's trees: the new place waits for David's look in game.
- Syria, in passing: the F10 circle and label of the Akamas range had stayed at its old place when the range moved on 2026-11-12; they now sit on its zones.
- The other theatres: no Mission Editor vehicle of a training zone moved; the new hard-tier launchers are `#command` markers, which `clear-ground-check` does not read and which the runtime settles itself. The check of every training zone needs DCS running, so it waits for David.
- Syria, checked in game (2026-11-16): the first new place, due south of the FARP, stood in a forest too, seen on the F10 map, which draws the forests the probe misses.
  The range moved a second time, onto the open hills east of Körkuyu, 10.7 km south-east of FARP Ceyhan (`tools/move_ceyhan_open.py`, Syria `37a9086`), picked on David's F10 capture set to 9.28 m per pixel; his F10 capture of the activated hard tier shows every unit on open ground.
- The known limitation now says the F10 map in "Map" mode shows those forests.

- `veaf-tools dcs forest-check` (FEAT-FOREST-CHECK, #1285 and #1287) replaced `clear-ground-check` for this: it reads the forests from the map files, without DCS. David's Mission Editor captures of Akamas Medium-Armor (in a wood) and Karpas Medium-SA15 (on its edge) agreed with it (2026-11-16).
- Run on the six Open Trainings, training groups and `#command` markers included (2026-11-16):

  | Open Training | Training groups or markers in or next to a forest | Done |
  |---|---|---|
  | Sinai, Falklands, Persian Gulf | none | nothing to move |
  | Syria | Akamas (Easy BMPs and convoy, Medium-Armor), Karpas (Medium-SA15, Hard-EWR) | 7 groups shifted 35 to 400 m, `tools/fix_forest_check.py`, Syria `5395b1e` |
  | Caucasus | Kobuleti Medium-sr-2, Akhalkalaki Medium-aaa-1, Gori Hard-ewr | 3 groups shifted 150 to 300 m, Caucasus `1a1799c` |
  | Marianas | Talofofo, NWF and Rota: 41 of 44 groups and markers, in the jungle | 44 groups into the nearest clearings of their zone circle, 10 m to 3.1 km, Marianas `a5918de` |

- Marianas: no rigid shift clears a whole range (NWF has about 3 % of its circle clear at 50 m around), so each group went to its own clearing, 100 m from any other: nothing of forest or water within 100 m of a Medium/Hard spawn marker (75 m where no 100 m clearing exists), 50 m of an Easy target. The Talofofo Hard Tor (H4-1) stays outside its circle on purpose, 12.9 km from FARP Merizo for its 12 km range.
- Each rebuilt and rechecked: `check_portees` finds no weapon in reach of what it must not reach, and no training unit or marker is left in a forest.
- Out of this ticket, `forest-check` also lists sanctuary groups, air defences and other combat zones in forests (Caucasus: Lazarevskoye, Psebay, Beslan; others on Syria, Marianas, Falklands, Persian Gulf); they are not training ranges and were left as they are.
