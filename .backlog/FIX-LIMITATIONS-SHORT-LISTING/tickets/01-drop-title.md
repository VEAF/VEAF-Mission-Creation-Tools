# 01 — Drop `title` from the short listing

Status: ✅ done

`_LIMITATION_SUMMARY_FIELDS` in `veaf_mission_mcp/oracle.py` loses `title`; the action description, the authoring guide and `doc/developer/mission-editing-mcp.{md,en.md}` say what the short listing holds; the test asserts the fields and keeps the 15 000 cap. CHANGELOG.
