# FEAT-THIRD-PARTY-MODS-001 — Default list + stripper

Status: ✅ done
Type: feat
Files: `mission_builder/`, `mission_builder/data/`, `test/python/`

## What to build

- A bundled data file `mission_builder/data/third_party_mods.json` holding the VEAF default
  list of third-party aircraft mod ids, initialised from the v5 hack:
  `Hercules`, `UH-60L`, `A-4E-C`, `T-45`, `AM2`, `FlankerEx by Codename Flanker`,
  `Bronco-OV-10A`. Loaded via `veaf_libs.bundled_data.read_bundled_text` (same pattern as
  `placeholder_groups.json`).
- A pure function (e.g. `strip_third_party_mods(mission_content, extra_mods) -> list[str]`)
  that removes every id in `(default ∪ extra_mods)` from
  `mission_content["requiredModules"]` (a `{modId: modName}` dict) and returns the list of
  ids actually removed. No-op when the table is absent/empty or holds none of the ids.

## Acceptance criteria

- [ ] Removes listed mods, keeps unlisted ones.
- [ ] Union: `extra_mods` adds to the default, does not replace it.
- [ ] Safe when `requiredModules` is missing, empty, or a non-dict — no crash.
- [ ] Returns exactly the ids removed (for the build log).
- [ ] TDD; ruff + mypy clean.
