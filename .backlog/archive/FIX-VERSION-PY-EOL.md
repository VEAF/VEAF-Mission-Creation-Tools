# Lot FIX-VERSION-PY-EOL — generated `_version.py` always shows as modified

Status: ✅ done

**Goal**: `veaf-build` writes `veaf_tools/_version.py` (and restores its stub) in Python text mode, so on Windows `\n` is translated to `\r\n`. The git-tracked stub is normalized to LF (`.gitattributes` `eol=lf`), so every build left the working tree permanently "modified" with a CRLF-only, content-less diff — recurring friction. **Done**: `_write_version_py` / `_restore_version_py` now pass `newline="\n"`; the same latent bug in `radio_specs_updater` (tracked `dcs-radio-specs.yaml` / `.md`) was fixed too, matching the `dcs_data` generators that already force LF. Regression tests assert LF output. Working tree `_version.py` renormalized.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-VERSION-PY-EOL-001 | Force LF (`newline="\n"`) in `_write_version_py`/`_restore_version_py` and the radio-specs writers; renormalize the tracked stub; LF regression tests | `veaf_build/worker.py`, `veaf_build/radio_specs_updater.py`, `test/python/veaf_build/test_version_py_eol.py` | fix | ✅ |
