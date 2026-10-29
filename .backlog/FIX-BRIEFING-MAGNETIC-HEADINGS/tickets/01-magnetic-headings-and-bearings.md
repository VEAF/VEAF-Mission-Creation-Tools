# 01 — Magnetic headings and bearings in the briefing

Status: 🔄 in-progress

## Done when

- The declination matches the twelve WMM2020 test values (`test_the_declination_matches_the_wmm_test_values`), and a date takes the last epoch before it (`test_each_date_takes_the_last_epoch_before_it`).
- The true bearing is within 0.001 degree of GeographicLib's geodesic, and the magnetic bearing is that less the declination, on a Syria case and a Caucasus case (`test_the_magnetic_bearing_is_the_true_one_less_the_declination`).
- The legs, the step, objective and target bullseyes, the bullseye from the departure and the campaign deck's bullseye read `°M` with the magnetic value (`test_briefing_kneeboard.py`, `test_briefing_parity_marteau.py`, `test_campaign_mission_deck.py`).
- The CHANGELOG and `doc/developer/mission-editing-mcp*.md` say it.
