# 01 — Profile: normalise `Splash_Damage_*`, scaffold `FootholdLocale`

Status: ✅ done
Type: feat

## Why

`src/python/veaf-tools/veaf_libs/data/convert-profiles/foothold.yaml` normalises
`Moose_*.lua` only. Upstream 4.4.1 also ships `Splash_Damage_3.4.1_leka.lua`: a
version-stamped name that will churn, and every churn breaks the `custom_scripts:` path on
`convert-other --update` (reported as one add + one remove, fixed by hand).

Separately, the new `Foothold Config.lua` exposes `FootholdLocale` (ten locales, `"FR"`
included). A VEAF Foothold wants French on-screen text, so it belongs in the commented
`config_override` scaffold the profile emits — the point of that scaffold being to surface
the handful of settings a mission-maker actually changes.

## Tasks

- [x] Add a `name_normalization` rule `Splash_Damage_*.lua` → `Splash_Damage.lua`.
- [x] Add `FootholdLocale: FR` to `config_override.defaults` (the block is emitted
      commented out, so this is a suggestion, not a forced value).
- [x] Unit test: `ConversionProfile.normalize_script_name` maps
      `Splash_Damage_3.4.1_leka.lua` → `Splash_Damage.lua` and leaves `Zeus.lua` alone.
- [x] Unit test: `build_scaffold_yaml` with the `foothold` profile emits `FootholdLocale`
      in the commented `config_override` block.
- [x] Re-run the moulinette on `Foothold_CA_4.4.1` and confirm `custom_scripts:` now lists
      `src/scripts/Splash_Damage.lua`.
- [x] CHANGELOG + version bump (`pyproject.toml` + `plugin/.claude-plugin/plugin.json`).

## Verify

Both keys must survive `validate`: `FootholdLocale` is lexically checked against the
injected `Foothold Config.lua`, and it is there at line 391 of the 4.4.1 config.

## Notes

Do **not** normalise the per-map setup script (`MA_Setup_CA.lua`, `footholdSyriaSetup.lua`,
`kola_setup.lua`, `AF_SETUP.lua`, …). Those names differ per *map*, not per *version*, and
each mission folder adopts exactly one map — a rule collapsing them to one name would buy
nothing and hide which map a folder holds.
