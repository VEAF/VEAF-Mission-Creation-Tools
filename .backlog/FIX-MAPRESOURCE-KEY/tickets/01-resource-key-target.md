# 01 — Resource key must go into `l10n/DEFAULT/mapResource`

Status: ✅ done
Type: fix

## Tasks

- [x] `_allocate_map_resource_key` takes the mission's `mapResource` dict (documented as the
      separate archive member) instead of the `mission` table.
- [x] `apply_startup_script_trigger` gains `map_resource=`; `file_static` without it raises
      a clear `ValueError` rather than silently losing the key.
- [x] `add_startup_script_trigger` passes `mission.map_resource_content` (initialised when
      the archive has no such member) and, in that case, supplies the serialised member via
      `additional_files` so `write_miz` writes it.
- [x] Tests: fix the one that asserted the wrong table; assert the key is **absent** from
      `mission`; new end-to-end test (key present in `l10n/DEFAULT/mapResource` of the
      written `.miz`); new test for the missing-member case.
- [x] Verified in the DCS editor by David.
