# 03 — A static on another unit is warned

Status: ✅ done

security-audits#138. `_static_clear_ground` checks `occupied_by(mission_content)` on its own, within `_STATIC_OVERLAP_METERS` (10 m) plus a marker's footprint, and warns without moving; the scenery check stays as it was.

Done when: a tank on an existing vehicle group is warned, three tanks 20 m apart are not.
