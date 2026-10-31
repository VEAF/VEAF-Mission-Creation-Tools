# 04 — Describe the simulated wind: deck, MCP answers, guide, prompts

Status: ⬜ ready

Everything that tells a pilot or an agent what the wind is says the wind DCS will simulate, computed with ticket 01's brick from the built `.miz`'s setting (PRD D5, D6):

- a. **The deck's weather block** (`weather_lines`, `campaign_manager/mission_pages.py`, fed by `_weather` in `campaign_manager/mission_picture.py`): instead of the three set layers, the wind above the reference airfield (the one ticket 03 resolved, recorded with the build; otherwise the first player departure airfield) by layer — surface (10 m), 1,000 ft and 3,000 ft above the ground, FL100, FL250 — "from" degrees and knots, magnetic like the rest of the deck (FIX-BRIEFING-MAGNETIC-HEADINGS), and the airfield named.
  The kneeboard page drawn from the same picture follows; FR and EN strings in the deck's locale files.
- b. **`inspect_built_mission`** (`veaf_mission_mcp/inspect_built.py`, `_weather_line`): for each variant, the simulated wind by the same layers above the reference airfield, then the setting, labelled "set", on its own line.
  With helicopter slots, the helicopter rule of c, applied to the variant's weather, is a line of the answer.
- c. **`set_weather`'s answer** carries the reference airfield, the setting written and the simulated wind by layer (ticket 03 e); with a helicopter slot in the mission, the rule of PRD D6 (20 kt between 0 and 600 m above the ground, 15 kt over the surface wind) is applied above each helicopter departure, objective and route point of the mission and every breach is a `warnings` entry naming the place, the height and the speed.
  Its description says that `wind_speed` is the wind wanted at 10 m above the reference airfield, not a DCS setting.
- d. **Authoring guide** (`veaf_mission_mcp/data/authoring-guide.md`, "Helicopters fly" and "Finish: validate, then build") and **both mission prompts** (`new-objective-mission` and `new-open-training-mission`, FR and EN — four files, weather of §4.2 and checks of §8):
  - "10 kt or less at the surface" becomes the rule of PRD D6, on the simulated wind from 0 to 600 m above the ground, in the open-training prompt too (it has none today);
  - the briefing's wind is the simulated one, read from `set_weather`'s or `inspect_built_mission`'s answer by layer, never the setting copied;
  - a wind shift aloft is set with `wind_veer` up to 30°, never a direction opposed to the surface (the layer without wind of the whitepaper, section 3.3);
  - `veaf-tools dcs mission-check` (ticket 05) is run before the briefing is handed over, without DCS.
- e. Thresholds and layers are the named constants of one module (ticket 05 reuses them), quoted in the lines that apply them.

Done when:

- `weather_lines` and `inspect_built_mission` are unit-tested on the original *Marteau du Golan* setting (9 / 11 / 14 m/s from 270, Rosh Pina): they print 24 kt at the surface and 36 kt at 1,000 ft, within 1 kt of the whitepaper's in-game measurement;
- `set_weather` warns on that setting with a helicopter slot, and does not warn on ticket 03's default for 10 kt wanted at Rosh Pina;
- the four prompt files and the guide no longer state a wind threshold in terms of the setting (a test greps the old wording out, as other prompt rules are guarded);
- the MCP action catalogue doc is updated if an action's parameters changed (`set_weather`'s new parameters).
