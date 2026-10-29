# 02 — A readable overview

Status: ✅ done

The overview is framed on the route, the departures, the objectives and the threats' positions (not the full detection circles, nor the tankers' tracks), turned when that holds the frame tighter (north arrow drawn), rendered at about twice the resolution with every symbol scaled, and its legend drawn into the map as a compact symbol key: the slide gives the map its whole width.

Done when: the behaviour is covered by a test, and the action's documentation says it.

## Result

`MapCanvas(width=…, rotation=…)`: a framed canvas, symbols and fonts scaled by `k`, turned after the symbols are drawn (`turn`), labels set level afterwards, `north_arrow`, `free_corner`; `best_rotation` keeps north up unless a turn gains 15 %. Callers giving no width keep the north-up 1400 px map. The overview is framed on route, departures, objectives, threats where they stand, carriers and bullseye; 2000 px at 2:1 on the slide's whole width, its key drawn inside. Measured on Marteau du Golan: 3738 × 1869 px, turned, the key top left. Tests: `TestTheReadableOverview`, `TestTheRotation`.
