# FIX-BUILD-PROFILES

Status: 🔄 in-progress

Two build-profile irritants, bundled (both touch profile resolution).

## Problem 1 — case-sensitive profile names

`--profile test` did not match a `TEST:` profile: the lookup was an exact dict
membership test (`build_profiles.resolve_profile`), so an unmatched name fell back
to the base config **with only a warning** — easy to miss. Same for each
`build_variants:` entry.

## Problem 2 — false "orphan pipeline file" warning under a profile

Building with `--profile TEST` (which sets `pipeline.weather: false`) warned
*"Orphan file 'src/versions.yaml': pipeline 'weather' is disabled…"* even though
`versions.yaml` is used by the default / `SERVER` build. The orphan check in
`complete_src_folder_with_defaults` read the **profile-resolved** `pipeline_cfg`, so
a step disabled by the *current* profile looked orphaned. The symmetric case (base
off, a `METEO` profile on) had the same false positive.

## Decisions

1. **Case-insensitive resolution**: `resolve_profile` matches exactly, else
   case-insensitively; a single match wins, an ambiguous case (e.g. `TEST` + `test`)
   warns and falls back to base. Logs / the multi-variant `.miz` suffix use the
   **canonical** (declared-case) name via `canonical_profile_name`.
2. **Orphan = unused by every build context**: a pipeline file is orphaned only when
   its step is disabled in the base **and** in every profile (`pipeline_step_enabled_anywhere`).
   The copy-skip still follows the current profile (unchanged); only the warning is
   gated on the global view.

## Implementation

- `veaf_libs/build_profiles.py`: `_find_profile_key`, `canonical_profile_name`,
  `pipeline_step_enabled_anywhere`; `resolve_profile` case-insensitive + canonical log.
- `mission_builder/mission_builder_worker.py`: keep `self._raw_yaml`; gate the orphan
  warning on `pipeline_step_enabled_anywhere(self._raw_yaml, step)`.
- `veaf_tools/commands/build.py`: `_build_plan` canonicalizes each variant.
- New i18n key `profiles.ambiguous_profile` (FR/EN).
