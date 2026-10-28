# 06 — validate_mission warns on an unknown cap_missions key

Status: ✅ done

`friendly_name` in `cap_missions` was silently ignored. A key the generator does not read is a warning.

Done when: covered by a test, and the documentation says it.

## Result

`CAP_MISSION_KEYS`, `_check_cap_mission_keys`. Tests in `test_mission_validator.py`.
