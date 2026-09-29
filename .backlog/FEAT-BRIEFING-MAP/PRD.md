# FEAT-BRIEFING-MAP — the briefing map, drawn by the tools rather than by every mission

Status: ⬜ ready — opened 2026-09-29.

## Origin

The Open Training prompt asks, since 2026-09-29 (§4.13), for a map of the theatre generated from the
mission's data: one picture at the top of the README and as the DCS briefing picture, and the same
overlays as F10 drawings. Two missions have now done it by hand, each with its own script outside this
repository:

| Mission | Script | What it took |
|---|---|---|
| `VEAF-Open-Training-Mission-GermanyCW-v6` | `.veaf-backups/outils-controle/gen_map.py` (+ `gather.py`) | 311 lines, label positions tuned by eye per mission (`QRA_LABEL_BELOW`, `SUPPORT_LABEL_AT_END`) |
| `VEAF-Open-Training-Mission-Caucasus-v6` | `tools/gen_map.py`, `tools/set_briefing_picture.py`, `tools/gen_15_dessins.py` | 303 lines, the GermanyCW script adapted: frame, front line, zone letters and label exceptions rewritten; three rendering rounds to clear overlaps |

The second mission had to rewrite everything that was specific to the first: frame, front line, zone letters, label exceptions. That is the signal to make it a tool.

## The findings

| # | What is missing | Measured |
|---|-----------------|----------|
| [01](tickets/01-render-briefing-map.md) | Nothing renders a map from a mission folder | both missions carry their own renderer; the Caucasus one needed marker de-cluttering the GermanyCW one did by hand |
| [02](tickets/02-briefing-picture-action.md) | Nothing sets the briefing picture, and `save_folder_mission` drops a new `mapResource` key in silence | `pictureFileNameB/R/N` and `ResKey_ImageBriefing_carte` written by script on both missions; `add_sound` accepts `.ogg` / `.wav` only |
| [03](tickets/03-f10-drawings-from-map-data.md) | The F10 drawings are a second copy of the same overlays, and cannot be regenerated | Caucasus: 38 `add_map_drawing` calls generated from the map's data, which a second run refuses (names taken); GermanyCW: 38 objects, placed separately |

## A personal-data leak to fix on the way

GermanyCW-v6's `gen_map.py` sends a personal e-mail address to `tile.openstreetmap.org` in its
`User-Agent` (line 27). The OpenStreetMap tile policy asks for an identifying `User-Agent`, and a URL
identifies the tool as well; the Caucasus script uses
`veaf-briefing-map/1.0 (+https://github.com/VEAF/VEAF-Mission-Creation-Tools)`, like `geocoding.py`.
Ticket 01 must never put personal data in a request, and the GermanyCW script is to be fixed or
replaced by the tool — mission-side, outside this repository.

## One lot, one PR

01 and 03 share the data gathering (bases, support, zones, QRA, CAP, sanctuaries, front line) and
belong together; 02 is the small write that 01's output needs to reach DCS.

## Out of scope

- The README generator of each mission (`gen_readme.py`): mission-side prose, not a map.
- The encoding defect that turns accents into `Ã¨` on the presets kneeboard pages, found the same day
  (Caucasus-v6 `tools/retours-vmct.md` n° 11): a presets bug, its own lot.

## Definition of Done

- Every ticket closed.
- The Caucasus-v6 map is rebuilt with the tool, and its three scripts can be deleted.
- The prompt's §4.13 names the action and the command instead of describing a script to write.
