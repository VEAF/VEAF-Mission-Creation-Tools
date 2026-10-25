# 08 — The briefing in the kneeboard

Status: ⬜ ready

David: the briefing should also be in the kneeboard, as JPEG, the maps at least.

`build_mission_briefing` already renders the maps and writes them as JPEG briefing pictures; the presets injector already writes kneeboard pages (`KNEEBOARD/<type>/IMAGES/` per type, `KNEEBOARD/IMAGES/00-veaf-calibration.png` for every aircraft, `presets_manager.py`).
**DCS stretches a kneeboard image onto the whole page without keeping its proportions**, and the page is 2:3 portrait (`KNEEBOARD_PAGE_SIZE = (1536, 2304)`, measured 2026-10-18): the landscape briefing maps cannot be reused as they are.

Pages, drawn at 2:3 portrait, JPEG, in `KNEEBOARD/IMAGES/` (every aircraft), named so they sort after the calibration page and before nothing else of VEAF's:

1. the overview map, rendered for the portrait frame (not a crop of the landscape one);
2. one zoom per objective;
3. a flight card: the route's points (name, coordinates, leg heading and distance, the floor of the leg from `terrain_elevation` when the theatre has a grid) and the flight's frequencies;
4. the targets: name, coordinates, elevation — the deck's targets page.

The pages are kept in the mission folder so a rebuild carries them into every `.miz`, root and weather variants (same path as ticket 01); a page an earlier run wrote and this one no longer writes is removed, only if this tool generated it.
`build_mission_briefing` gains a `kneeboard` switch, on by default.

Measure in DCS (David): the pages show in the kneeboard of a dynamic-slot AJS-37 and of one other type, in that order, readable; a JPEG page is read like the PNG ones.

Done when: the pages are written and carried over, with tests on the page sizes, the names and the presence in each variant; the DCS check is reported here; the catalogue page and the objective prompt mention the kneeboard.
