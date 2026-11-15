# FIX-OPEN-TRAINING-PILOT-FEEDBACK — Helicopter hard tier and QNH in inHg

Status: ⬜ ready

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
| 01 | [A real hard tier for the helicopter training](tickets/01-helicopter-hard-tier.md) | ⬜ |
| 02 | [The QNH in hPa and inHg everywhere](tickets/02-qnh-hpa-and-inhg.md) | ⬜ |
| 03 | [Training ranges out of the forests](tickets/03-training-ranges-out-of-forests.md) | ⬜ |

Ticket 03 (point 4) is mission work in the same repositories, with a look in game on Syria where the forest probe is blind.
Ticket 01 is mission work in the six Open Training repositories (`VEAF-Open-Training-Mission-<theatre>-v6`), ticket 02 is Lua runtime in VMCT (`src/scripts/veaf/veafWeather.lua`, luaunit tests).
They are independent: 02 ships with the next VMCT release, 01 with the next `Publish-OT` of each mission.
