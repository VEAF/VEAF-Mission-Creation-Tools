# 05 — create_cap_mission takes a display name

Status: ✅ done

`create_cap_mission` takes `menu_name` and `briefing`; the generator falls back to the group name when `menu_name` is empty: an empty one made a blank F10 entry whose "Infos" failed (Marteau du Golan, 2026-10-28).

Done when: covered by a test, and the documentation says it.

## Result

`menu_name` and `briefing` parameters; the generator falls back to `group_name`; an unread `cap` key is warned. Tests in `test_create_qra_cap.py`, `test_cap_missions_arguments.py`.
