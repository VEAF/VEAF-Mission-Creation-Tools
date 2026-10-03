# 01 — channel collections are generated from the reference, not typed

Status: ✅ done

`src/defaults/mission-folder/src/presets.yaml` carries `airports-caucasus`, `airports-syria` and
`airports-persian-gulf`, written by hand. `veaf_libs/data/airfield-frequencies.yaml` carries the
truth, extracted from DCS. The two have drifted, and four theatres never got a collection at all.

## Measured (2026-10-01)

| collection | channels | reference | state |
|---|---|---|---|
| `airports-caucasus` | 8 | 21 | 7 right, 13 airfields with no channel |
| `airports-syria` | 60 | 81 | 29 right, Sanliurfa **251.6** where DCS says **252.7** |
| `airports-persian-gulf` | 29 | 26 | not one name matches the reference |
| GermanyColdWar / Normandy / Sinai / MarianaIslands | — | 119 / 86 / 54 / 5 | nothing |

`update-dcs-data --airfield-freqs` was re-run against the installed DCS: 392 airfields, 7 theatres,
**0 drift**. The reference is sound; only the step after it is missing.

## Done when

- `veaf-build update-dcs-data --airfield-freqs` regenerates **both** the reference and one
  `airports-<theatre>` collection per theatre it holds, in the defaults. Running it twice in a row
  changes nothing the second time.
- A generated collection carries, per airfield, what the reference has — UHF, VHF and FM — and the
  TACAN suffix the hand-written ones use (`Batumi / 16X`) wherever that is known; if TACAN is not in
  the reference, say where it comes from or drop it rather than losing it silently.
- **Names are settled, and the Persian Gulf case decides the rule.** Its 29 channels match none of
  the 26 reference names; establish whether these are other airfields, other spellings, or a theatre
  renamed in DCS, and make the generated name the one the reference uses. A hand-written channel
  that no longer matches anything is reported, not dropped in silence.
- Sanliurfa is 252.7 and nothing else still says 251.6.
- A test fails if a committed collection diverges from the reference — the drift this ticket exists
  to end must not come back. The reference itself stays out of CI (it depends on which maps are
  installed), but the *derivation* can be checked offline.
- The authoring prompt and `doc/` say that a mission takes the collection of its theatre, and never
  writes frequencies by hand. The v6 Open Training prompt is where the invented `270.x` series came
  from on two missions.

## Known trap

A theatre absent from the installed DCS must leave its collection **alone**, not empty it: the
reference only holds what the machine running the command has installed, and the file is shared.

## Done (2026-10-01), and what waits for DCS

- Capture: `veaf-build update-dcs-data --airfield-freqs --capture --dcs-path <DCS>` runs the Mission
  Editor's own logic in the fiddle hook's GUI environment and writes
  `veaf_build/dcs_data/airfield_freq_dumps/<Theatre>.json`, TACAN folded in from `Beacons.lua`. Run
  against mocks of `terrain` and `DCS` under Lua 5.1 (both sources, abandoned fields filtered); **never
  run against a live DCS yet**.
- Generation: `veaf-build update-dcs-data --airfield-freqs` rebuilds reference + collections from the
  committed dumps, rewriting only what sits between the two markers of the default `presets.yaml`;
  idempotent (tested). A theatre without a dump is not touched — the known trap holds by construction.
- Guard test: the committed reference and collections must equal what the committed dumps derive.
- **Waiting:** one capture per theatre (blank missions in `Saved Games/DCS/Missions/VEAF-capture-frequences/`),
  then one generation. Until then the default `channel_lists` names `Sochi-Adler` / `Sukhumi-Babushara`,
  which the hand-written collections do not have: 9 tests red, all from that.
- **Not done, David's decision:** the Open Training prompt's rule that a silenced-ATC mission uses its own
  base frequencies (see PRD).

## Captured (2026-10-01)

David ran the guided command over the six remaining maps in one go (Caucasus was its test run):
396 airfields with at least one frequency over 7 theatres — Caucasus 21, GermanyCW 119, MarianaIslands 5,
Normandy 89, PersianGulf 27, SinaiMap 54, Syria 81 — and 52 TACAN. No airdrome anywhere has a terrain
`frequency` field; every list came from `DCS.getATCradiosData`, which on Persian Gulf returns four bands
where `radio.lua` holds one. Sanliurfa is 252.7. All nine tests that waited for the capture are green.
