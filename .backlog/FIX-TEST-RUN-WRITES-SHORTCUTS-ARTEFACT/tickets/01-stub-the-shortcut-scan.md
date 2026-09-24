# 01 — Stub the shortcut scan in the build orchestration tests

Status: ✅ done

Type: fix · Files: `test/python/veaf_build/test_build_standalone.py`

## Change

Stub `_scan_lua_shortcuts` in `_recording_worker`, like `_scan_lua_modules` already is. The worker
itself is unchanged: writing the artefact next to the module is what the real build needs, since
PyInstaller bundles it from there.

## Definition of done

- [x] A test that failed before the fix: running both stubbed build paths leaves the two generated
      artefacts (`veaf-shortcuts.json`, `veaf_modules_list.json`) exactly as they were
- [x] A full local `poetry run pytest`, artefact deleted beforehand, leaves it absent
