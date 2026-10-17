# 03 — A withdrawn module is a warning, not an error

Status: ✅ done

`hercules: false` sat in all ten Foothold `mission.yaml` after the Hercules Cargo script was withdrawn in 6.18.0 (#843).
As an unknown `modules:` key it was an error, and `validate` — so the batch — refused to build any of them, for a line that switched nothing on.

`yaml_validator.py` now keeps a `_RETIRED_MODULES` table (`HERCULES` → `6.18.0`): such a key is a warning naming the release that withdrew it and asking to delete the line.
A misspelt module stays an error.

The ten missions also lose the line (ticket 04).

Test: `test_a_retired_module_is_a_warning_naming_the_release` in `test/python/test_yaml_validator.py`.
