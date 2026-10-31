# 06 — `veafWeather.lua`: rounded speeds, the low-layer maximum, gusts as an option

Status: ⬜ ready

`src/scripts/veaf/veafWeather.lua` already asks `atmosphere.getWind` at the right place (whitepaper, section 6: 13 kt announced at Rosh Pina for 13.1 simulated); three changes (PRD D8):

- a. **Round, don't truncate.** `veafWeatherData:toStringWind` writes `math.floor(veaf.mpsToKnots(nSpeedMps))` and `math.floor(nSpeedMps)`: 13.9 kt reads 13.
  Round to the nearest unit (`veaf.round` or `math.floor(x + 0.5)`), in every wind string of the module (ATIS, weather report, LASTE); the calm threshold (`<= 0.5` m/s) is unchanged.
- b. **"Max wind 0-2000 ft" in the ATIS.** A line giving the strongest base wind between the surface and 2,000 ft above the airfield, its direction and the height it occurs at — sampled with `veafWeather.getWind` every 100 ft from 10 m, which is what the helicopter pilots of *Marteau du Golan* needed and the surface wind did not tell them.
  The line shows only when that maximum exceeds the surface wind by 5 kt or more, so a calm profile does not lengthen the ATIS; FR and EN through `veaf.t`, in the module's unit system (knots and/or m/s).
- c. **Gusts, as an option** (`veafWeather.announceGusts`, false by default): sample `atmosphere.getWindWithTurbulence` around the surface point (a ring of points, or along the runway axis, as ticket 02 found DCS's turbulence to vary) and announce `G<peak>` the METAR way when the peak exceeds the mean by 10 kt or more.
  Off by default: the whitepaper measured a turbulence floor even at `groundTurbulence` 0, and an ATIS that announces gusts nobody set would be noise; ticket 02 says how many samples make a stable peak.
- d. Lua 5.1, no new dependency; luacheck and stylua clean; the luacov floor bumped if coverage rises.

Done when:

- `test/lua/test_veafWeather.lua` (DCS mocks) covers: a 13.9 kt wind reads 14; a mocked profile peaking 300 m above the airfield gives the max-wind line with its height, and a flat profile gives none; with the option off no gust is announced, with it on a mocked turbulent field gives `G` only past the 10 kt threshold;
- the demo mission gains the step of ticket 07 c, so a player sees the new line before a release.
