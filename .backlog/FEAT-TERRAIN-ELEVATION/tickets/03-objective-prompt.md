# 03 — The objective-mission prompt uses the elevation

Status: ✅ done

Files: `.prompts/new-objective-mission.fr.md`, `.prompts/new-objective-mission.en.md`.

The three places that say "no action gives the ground elevation" now call `terrain_elevation`: target
altitudes in the briefing, the floor of the TBA legs (height above the profile's maximum), and the
masking table between each route leg and each SAM. Where the theatre has no grid, the old wording stays:
an open point.
