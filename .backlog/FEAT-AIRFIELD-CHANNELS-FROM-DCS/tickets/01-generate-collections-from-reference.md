# 01 — channel collections are generated from the reference, not typed

Status: ⬜ ready

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
