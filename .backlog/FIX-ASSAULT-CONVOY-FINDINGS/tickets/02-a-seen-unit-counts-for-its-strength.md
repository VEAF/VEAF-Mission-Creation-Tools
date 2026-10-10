# 02 — A ground unit seen beyond engagement range counts for its own strength

Status: ✅ done

- `ConvoyUnitHandler:recordThreat`: a living enemy ground unit **seen** counts for `veafGroundAI.unitStrength`, whatever its distance; `math.huge` stays for an aircraft and for a unit that **fired** at the convoy from beyond `ENGAGEMENT_RANGE` (the gun it cannot answer). The caller says which (seen by the watch, or from a hit/shot event).
- Lua tests: an infantryman seen at 3164 m does not make a strength-5 group fall back; a gun firing from 6 km still does; an aircraft still does.
- Check an infantry unit's strength (`STRENGTH_BY_ATTRIBUTE`): a rifleman should not outweigh a Shilka.
