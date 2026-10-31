# 01 — mission-check measures the simulated wind

Status: ⬜ ready

`veaf-tools dcs mission-check`, on the test copy the user launched, gains a `wind` check:

- a. **Where:** each player departure (airbase or FARP of a `Client` / dynamic slot), each combat zone of an objective, and each waypoint of a helicopter flight's route; points read from the `.miz` and the mission's VEAF configuration, de-duplicated within 5 km.
- b. **At which heights:** 10, 150, 300, 600 m above the ground (`land.getHeight`), then 2,000 and 8,000 m above sea level — the layers DCS's own setting names.
- c. **What:** `atmosphere.getWind(vec3)` in the mission scripting state, through the bridge `mission-check` already embeds; turned into "from" degrees (true) and knots, the way a METAR says it. `getWindWithTurbulence` may be recorded beside it, unjudged (PRD, out of scope).
- d. **Through one function** — `simulated_wind(point, height_agl)` behind an injected provider, the DCS measurement being the first one — so the model under study in `feature/dcs-wind-model` can replace it without touching the checks (PRD D2).
- e. **Output:** one informing report line per place (surface wind, low-layer range, `at2000`, `at8000`), and the full table written as `<stem>_CHECK.wind.json` beside the test copy, with the DCS version and the date, for tickets 02 and 03.

Done when: the Lua chunk builder, the parser of its answer and the conversion to METAR terms are unit-tested without DCS (a vector from the west reads `270°`), and a run on *Marteau du Golan* with its original setting (ground 9 m/s) finds again the 2026-10-31 measurement — about 24 kt at 10 m above Rosh Pina, 34 to 37 kt between 150 and 600 m.
