# FEAT-AIRFIELD-CHANNELS-FROM-DCS — airfield channels come from DCS, and a mission picks the ones it needs

Status: ⬜ ready

Opened 2026-10-01 from the Open Training Caucasus v6, where David found in flight that the radio
plan does not match what DCS shows on the F10 view. Measured afterwards: the mission's `bases`
collection is an **invented series** — 270.1, 270.2, 270.3… — while Batumi's tower is on 260.0 and
Krasnodar's on 251.0.

## What was measured (2026-10-01)

**The reference is already right, and already reproducible.** `veaf-build update-dcs-data
--airfield-freqs --dcs-path <DCS>` reads every `Mods/terrains/<Theatre>/Radio.lua`. Re-run against
the installed DCS and compared with the committed file: **392 airfields over 7 theatres, 0 missing,
0 whose frequency changed.** Nothing to fix there.

**The default channel collections do not descend from it.** They are hand-written, and it shows:

| collection | channels | airfields in the reference | state |
|---|---|---|---|
| `airports-caucasus` | 8 | 21 | 7 right, 13 airfields with no channel |
| `airports-syria` | 60 | 81 | 29 right, **Sanliurfa 251.6 instead of 252.7** |
| `airports-persian-gulf` | 29 | 26 | no name matches the reference at all |
| GermanyColdWar | — | 119 | no collection |
| Normandy | — | 86 | no collection |
| Sinai | — | 54 | no collection |
| MarianaIslands | — | 5 | no collection |

**Who got it wrong, and who did not.** Across 56 `presets.yaml` on David's machine, 3 658 airfield
channels: the ten **Foothold** missions are at **0 wrong**, Open Training Caucasus **v5** at 0,
Open Training Syria at 0. The two **v6** Open Training missions are the outliers — Caucasus v6 at
**0 right out of 13**, GermanyCW v6 at **0 out of 12**, both with the same invented `270.x` series.
GermanyCW's pre-v6 backup was at 7 right out of 12, so v6 regressed on what it replaced. The 43
remaining wrong entries are Sanliurfa, replicated wherever the defaults file was copied.

So the trigger is not missing data: it is that **nothing offers a mission the real frequencies**,
and the v6 authoring prompt let a series be invented instead.

**And a mission cannot take them all.** 392 airfields against the twenty-odd preset channels a DCS
radio holds. Which airfields deserve a channel is a per-mission decision — today nobody makes it,
because there is nothing to make it with.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [channel collections are generated from the reference](tickets/01-generate-collections-from-reference.md) | ⬜ |
| 02 | [a mission picks the airfields that deserve a channel](tickets/02-pick-airfields-for-a-mission.md) | ⬜ |

## Definition of done

- One command regenerates reference **and** collections after a DCS update; a second run is a no-op.
- A mission author — human at the CLI, or Claude through MCP — gets the real frequencies of the
  bases his mission actually uses, without typing a number.
- Each ticket closed with what was measured, not only what was changed.
- `CHANGELOG.md` entry; `doc/` updated where the radio plan is explained.

## Not in this lot, but found on the way

- **Eight VEAF tactical channels sit on real DCS towers** on Caucasus: Arco 1 (251.0) is Krasnodar's
  tower, Texaco 1 (252.0) Novorossiysk, Shell 1 (253.0) Krymsk, Shell 2 (254.0) Khanskaya,
  AWACS Rouge (260.0) Batumi, Tanker Rouge (261.0) Kolkhi, Magic 1 (265.0) Nalchik, Overlord 1
  (266.0) Mozdok. Choosing a band clear of towers **on all seven theatres** is a decision of its
  own, and it moves callsigns on every mission — David's call, not opened here.
- The two v6 missions still carry their invented series; fixing them belongs to their repositories.
