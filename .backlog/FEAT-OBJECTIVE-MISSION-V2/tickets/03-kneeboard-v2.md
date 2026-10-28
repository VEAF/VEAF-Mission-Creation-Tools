# 03 — Kneeboard: maps turned attack axis up, coordination, target pages

Status: ✅ done

The kneeboard maps are portrait and turned so that the attack axis — from the players' departure to the objectives — points up, a north arrow saying where north is. A coordination page lists the code words (new optional `code_words` parameter, also a deck page). The targets keep their pages.

Done when: covered by a test, and the documentation says it.

## Result

`attack_axis_rotation`: the true bearing from the departure to the objectives' centre, taken on lat/lon (on the mission grid it was off by the meridian convergence, 6 degrees at Kobuleti, caught by the test); overview, combat area and zooms turned, a north arrow on each. `code_words` make a deck page and a kneeboard page. Tests: `TestTheAttackAxis`, `TestTheCodeWords`.
