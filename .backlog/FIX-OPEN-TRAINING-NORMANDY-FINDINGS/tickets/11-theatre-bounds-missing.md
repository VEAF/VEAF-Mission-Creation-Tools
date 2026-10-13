# 11 — `theatre-bounds.yaml` has four theatres: `geocode` resolves « Omaha Beach » in Iowa without a warning

Status: ✅ done
Type: fix (data)
Files: `src/python/veaf-tools/veaf_libs/data/theatre-bounds.yaml`, `veaf_mission_mcp/geo.py` (l. 125-143), tests

## What happens

`theatre-bounds.yaml` lists `caucasus`, `syria`, `persiangulf`, `marianaislands`. For any other theatre `bounds is None`, so `geocode` sends no Nominatim `viewbox` (geo.py l. 142-143) and sets `in_theatre_bounds = True` (`bounds is None or …`). On Normandy: `Omaha Beach` → « Omaha Beach, Okoboji, Dickinson County, Iowa » (x 5 595 880, y −6 634 842), `in_theatre_bounds: true`, no warning. The same hole shows on Sinai (« El Qantara » → Lebanon, « Mount Sinai » → New York: Sinai retours entry 5), Germany CW, Falklands, Afghanistan, Nevada and The Channel. Every other Normandy place resolved correctly because the names were unambiguous; the one that was not went unnoticed until the x was read.

## What ships

- The missing boxes: `normandy` (lat 48.3-51.7, lon -2.9-3.0, from the airfield extents: x −118 842…229 644, y −166 232…205 059), `sinaimap`, `germanycw`, `falklands`, `afghanistan`, `nevada`, `thechannel`, `marianaislandswwii`. Derive them from `airdromes.yaml` with a margin rather than typing them.
- A theatre with no box returns `in_theatre_bounds: null` and a warning « no bounds for this theatre — the point is not checked », not `true`.
- A test asserts every theatre of `dcs-maps.yaml` has a box.

## Done when

`geocode("Omaha Beach")` on a Normandy folder returns a point in Calvados; a theatre with no box warns.

## Done

Nine boxes added, derived from the airfield extents of `airdrome-positions.yaml` with one degree of margin: Afghanistan, GermanyCW, Iraq, Kola, MarianaIslandsWWII, Nevada, Normandy, SinaiMap, TheChannel. Correction: the file had **five** theatres, `falklands` included, and the missing ones were nine — Iraq and Kola were not in the ticket's list. A test asserts every theatre of `dcs-maps.yaml` has a box, and that each derived box holds its airfields. A theatre with no box returns `in_theatre_bounds: null` and a warning instead of `true`.
