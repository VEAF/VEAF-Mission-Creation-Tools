# 05 — `veafNamedPoints` has no cities for GermanyCW, nor for the other recent theatres

Status: ⬜ ready
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
