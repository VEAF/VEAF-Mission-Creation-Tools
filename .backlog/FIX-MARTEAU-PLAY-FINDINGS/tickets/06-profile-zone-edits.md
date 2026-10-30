# 06 — Profiles edit a combat zone by name

Status: 🔄 in progress

`build_profiles._deep_merge` replaces lists whole, so a training version of a mission had to copy all nine combat zones and the operation. A profile can now edit `combat_zones` entries by `zone_name`, and set a key on every zone at once. Documented; then a `TRAINING` profile written into Marteau du Golan's `mission.yaml` (not committed there).
