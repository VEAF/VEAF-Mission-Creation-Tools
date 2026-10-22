# 05 — "0 aircraft" also stops the combat missions' auto scale (issue #1151)

Status: ✅ done

Found by the security-audits quality pass of 2026-10-19 (`opposition-zero-avion-combat-missions-non-coupees`).
"0 aircraft" fixed from the Opposition menu (or `_opposition 0`) announced "no enemy fighters (fixed)" and silenced the QRAs, but a combat mission started through "Auto scale (opposition level)" still took off at its smallest scale: `scaleForOppositionLevel` cannot tell a 0 fixed by hand from a 0 counted.

`ActivateMissionAtOppositionLevel` now checks `veafOpposition.isNoAircraft()` first: it starts nothing and tells whoever asked (`combatmission.no_aircraft`).
A 0 counted from the players keeps its smallest scale, and a scale chosen by hand always starts.
`veafQraManager` page, both languages: the zero-aircraft paragraph says so.

Done when: `test_no_aircraft_fixed_activates_nothing_and_says_so` fails on the old code and passes on the new (both measured).
