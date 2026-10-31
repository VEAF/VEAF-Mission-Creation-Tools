# 02 — Measure how `groundTurbulence` turns into gusts

Status: ⬜ ready

Needs DCS: run on a machine with the game (DAVID-BUREAU), with the whitepaper's protocol (section 8).

A METAR's gust group (`27015G25KT`) says the peak wind exceeds the mean by 10 kt; DCS only takes a turbulence, `weather.groundTurbulence` (60 in the `.miz` reads as 6 m/s in the editor).
The whitepaper characterised the spread of `atmosphere.getWindWithTurbulence` around the base wind (RMS 3.2 m/s at 10 m for a turbulence of 60) but not a gust, and noted a floor of 2 % of the 0 m level even at turbulence 0.
This ticket measures what ticket 03 d needs: for a turbulence, the gust a pilot meets.

- a. **Missions**: with `make_missions.py`, the empty survey mission of veaf-tools (`veaf-survey-Syria.miz`, bridge loaded at start) with one change per mission — wind 5 m/s from 270 at the ground and 11 m/s at 2,000 m (the defaults of PRD D3), `groundTurbulence` 0, 30, 60, 120 and 200; and once 10 m/s at the ground with 60, to see whether the gust scales with the wind or not.
- b. **What to sample**, at Rosh Pina (262 m), over the sea and on the Hermon (2,797 m), at 10 m, 100 m and 300 m above the ground:
  - in time, at a fixed point: `getWindWithTurbulence` every 0.1 s for 10 minutes of mission time, to learn whether DCS's turbulence changes with time at all;
  - in space, along a line into the wind and across it: one point every 4 m over 10 km, what a helicopter at 80 kt meets every 0.1 s.
- c. **What to compute**: the METAR's gust, i.e. the highest 3-second mean of the sampled speed, minus the 10-minute (or 10-km) mean; and the mean itself, to check that turbulence leaves it alone.
- d. **Deliverable**: the runs in `docs/whitepapers/dcs-wind-model/data/` beside the five others, the script beside `measure.py`, and a section of the whitepaper (FR and EN) giving the table turbulence → gust by height, the formula ticket 03 d will use and its error, and the DCS version.
  If DCS's turbulence turns out to depend on time or on the aircraft rather than on position only, the section says so and gives what a briefing can still announce.

Done when: the section is written in both languages with its table, the runs are committed, and the mapping is a formula (or a table to interpolate) with its stated error, ready for ticket 03 d.
