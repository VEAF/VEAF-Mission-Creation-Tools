# 05 — `veafNamedPoints` has no cities for GermanyCW, nor for the other recent theatres

Status: ✅ done — 2026-09-29
Type: fix + data
Files: `src/scripts/veaf/veafNamedPoints.lua` (`addCities`, the `_cities*` tables), the tool that
produces them, tests

## Origin

private1's `dcs.log`, GermanyCW-v6, 2026-09-28:
`VEAF|W|addCities|…: no cities in veafNamedPoints for theatre GermanyCW`.

## Measured

- `veafNamedPoints.addCities()` knows six theatres: Caucasus, Persian Gulf, The Channel, Syria,
  Mariana Islands, Falklands (`_citiesCaucasus` … `_citiesFalklands`). Any other theatre gets an
  empty list and that warning — GermanyCW here; Sinai, Kola, Afghanistan, Iraq and Normandy are
  not in the list either, and VEAF runs missions on several of them.
- The cities are added as **hidden** named points (`point.hidden = true`). Which features look
  them up — marker commands taking a place name, the named-points radio menu, the interpreter —
  is **not checked** yet; that is what says how much a mission on these theatres loses.

## Done when

- What uses the city points is established and written here.
- Each theatre VEAF supports has a city list, produced from one source (DCS's own terrain town
  data, or whatever produced the six existing lists), not typed by hand.
- The warning names the theatre and says what will not work without cities.

## Done — 2026-09-29

**What uses the city points** (hidden, so not in the named-points list): `getPoint` by name — a
shortcut's position (`-sa6 Kutaisi`), a convoy's destination (`veafSpawnGround`, `veaf.lua`), a
transport mission's start — and `getNearestPoint`, behind the weather at the closest point. Without
cities, a town name does none of this and the weather only knows the airbases; the warning now says
so.

**One source.** `veaf-build update-dcs-data --cities --dcs-path <install>` reads each terrain's
`Map/towns.lua` under the name its `entry.lua` declares (`self_ID`), merges into
`veaf_build/dcs_data/cities.yaml` (a theatre the install lacks is kept), and renders
`src/scripts/veaf/veafCities.lua`; the 5 277 typed lines left `veafNamedPoints.lua`. Run on
DAVID-BUREAU's install and on the server's (`dcs.veaf.org`, read-only copy of three terrains):

| Theatre | Before | Now |
|---|---:|---:|
| Afghanistan | — | 1 197 |
| Caucasus | 1 691 | 1 691 |
| Falklands | 1 323 | 1 323 (carried: no reachable install has it) |
| GermanyCW | — | 127 |
| MarianaIslands | 67 | 77 |
| MarianaIslandsWWII | — | 22 |
| Normandy | — | 1 282 |
| PersianGulf | 385 | 385 |
| SinaiMap | — | 703 |
| Syria | 213 | 1 151 |
| TheChannel | 1 311 | 1 311 |

No town of the old lists was lost. **Kola and Iraq** are installed nowhere reachable and have no list
yet: the next run on an install that has them fills them.
