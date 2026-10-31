# 02 — From a gust to `groundTurbulence`

Status: ⬜ ready

A METAR's gust group (`08024G37KT`) says the peak wind exceeds the mean by 13 kt; DCS only takes a turbulence, `weather.groundTurbulence` (60 in the `.miz` reads as 6 m/s in the editor).
What DCS does with a turbulence of N m/s is not measured: the whitepaper only characterised the spread of `atmosphere.getWindWithTurbulence` around the base wind (RMS 3.2 m/s at 10 m for 6 m/s) and a floor of 2 % of the 0 m level even at 0.

**Semantics, decided by David on 2026-10-31 for the servers and kept here so both sides agree:** the turbulence is the **gap** gust − mean wind, not the peak gust (DCS Real Weather writes the peak, about three times the gap), **capped at 2 m/s** until the measurement gives a table.

**The measurement is not done in this lot.**
It runs in its own session, *Mesure en jeu de la turbulence DCS*, with the whitepaper's protocol (missions at several `groundTurbulence`, `getWindWithTurbulence` − `getWind` sampled at fixed points over time), and delivers a table "gust gap → `groundTurbulence`" with its whitepaper section and runs.

This ticket puts the rule in the shared brick of ticket 01, so VMCT and the DCSServerBot fork apply the same one:

- a. `turbulence_for_gust(mean_knots, gust_knots) -> float` (m/s, the `.miz`'s unit divided by 10): the gap, capped at `GUST_TURBULENCE_CAP_MPS = 2.0`, 0 when no gust is reported or the gust does not exceed the mean.
- b. When the measurement session has delivered its table, the function interpolates it instead, the cap is revised to what the table says is flyable, and the table's source (whitepaper section, date, DCS version) is quoted in the docstring and the module.
  If the table has not landed when the lot is implemented, the lot ships with the capped gap and says so in the CHANGELOG.
- c. Shared test vectors (ticket 01 g) gain the gust cases: `08024G37KT` → 2.0 m/s capped (6.7 m/s gap), `27015KT` → 0, a gust under the mean → 0.

Done when: the function is in the shared file with its vectors, ticket 03 d uses it, and either the measured table is in or the CHANGELOG says the turbulence is the capped gap pending the measurement.
