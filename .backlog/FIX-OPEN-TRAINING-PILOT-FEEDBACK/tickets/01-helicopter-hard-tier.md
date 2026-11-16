# 01 — A real hard tier for the helicopter training

Status: ✅ done

Files: in each of the six Open Training repositories (Caucasus, Falklands, Marianas, Persian Gulf, Sinai, Syria), the groups of the helicopter combat zones and their `briefing:` in `mission.yaml`.

## What to do

- Find where each tier's defences are placed (Mission Editor groups under the zone's prefix, or spawn commands) before changing anything; the layout may differ between Caucasus and the five `H1/H2/H3` missions.
- Apply D1: medium takes today's hard content (AAA + IR short-range), hard adds radar-guided short-range systems (SA-15 Tor, SA-19 Tunguska, SA-8 Osa), a few drawn out of the list.
- Place the new systems on clear ground, at a range from the targets that leaves a helicopter a way in by terrain masking: the point is training, not a wall.
- Rewrite the three briefings (D3).

## Done when

- In each of the six missions, the hard tier spawns at least one radar-guided short-range system and the medium tier no longer is AAA only.
- The briefings say what each tier holds.
- Each mission is rebuilt; the `Publish-OT` stays with David.

## Outcome (2026-11-16)

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
