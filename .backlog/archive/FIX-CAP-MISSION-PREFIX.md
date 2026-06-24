# Lot FIX-CAP-MISSION-PREFIX — cap_missions group validation must account for the OnDemand- prefix

Status: ✅ done

**Goal**: The pre-build group-existence validation (`group_validation.py`) warns that a `cap_missions` group is missing even when the maker placed it. Root cause (David, VEAF-Demo-Mission): `veafCombatMission.addCapMission(name)` prefixes `"OnDemand-"` to the group name at runtime (`veafCombatMission.lua:1432`, v5 behaviour), so a `cap_missions: group_name: CAP-Maykop-1` is backed by a Mission-Editor group named `OnDemand-CAP-Maykop-1` (its unit is `CAP-Maykop-1-1`). The validation searched the raw `group_name` → false "missing group" warning. `combat_missions` uses `Group.getByName()` on the verbatim name (no prefix) and is correct. Fix: validate cap_missions against `"OnDemand-" + group_name`.

**Branch**: `fix/cap-mission-ondemand-prefix` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-CAP-MISSION-PREFIX-001 | In `collect_declared_groups`, reference cap_missions groups as `OnDemand-<group_name>` so the existence check matches the real Mission-Editor group. Update the existing cap_missions test and add a behavioural test (present `OnDemand-X` → no warning; genuinely absent → still flagged). `combat_missions` untouched. | `mission_builder/group_validation.py`, `test/python/` | fix | ✅ (#506) |
