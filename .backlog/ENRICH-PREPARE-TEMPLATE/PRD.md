# Lot ENRICH-PREPARE-TEMPLATE — `prepare` generates the same rich mission.yaml preamble as convert-v5

Status: 🔄 in-progress
Branch: feature/enrich-prepare-template → PR (targeting develop-v6)

## Problem Statement

Reported by **Tripack**: a `mission.yaml` scaffolded by `veaf-tools prepare` (even with
`--template full`) is markedly leaner than one produced by `convert-v5`. It lacks the YAML
syntax guide, `global_log_level:`, the full `mission:` identity block, `security:` and
`pipeline:` — sections a converted mission (and the shipped default `mission.yaml`) carry.

## Root cause

Three generators produce a `mission.yaml`, two rich and one lean:

- `prepare` → `mission_template.generate_mission_yaml` — header (2 lines) + `mission: name:`
  + tier-driven `modules:` block only.
- `generate-config` → `lua_config_generator.generate_mission_yaml_template` — rich.
- `convert-v5` → `V5Converter._build_mission_yaml` — rich + migrated data.

The rich preamble (guide, `global_log_level`, `mission:`, `security:`, `pipeline:`) is
**tier-independent** and was duplicated across the shipped default file, `lua_config_generator`
and `v5_converter`. `prepare` simply never emitted it.

## Solution

Factor the invariant preamble sections into shared helpers in `lua_config_generator`
(`global_log_level_section`, `mission_identity_section`, `security_section`,
`pipeline_section`; the YAML guide already lives in `yaml_syntax_header`). Both
`generate-config` and `prepare` call them, so the scaffolds share one source of truth.

- `generate_mission_yaml_template` (generate-config / the basis of convert-v5's preamble)
  refactored to call the helpers — output **byte-for-byte unchanged** (verified by diff).
- `mission_template.generate_mission_yaml` (prepare) emits the preamble above its
  tier-driven `modules:` block, plus a trailing `pipeline:` section.
- `mission_identity_section(live_name)` keeps the one genuine divergence: `prepare`
  emits `name:` live (ready-to-build scaffold); `generate-config` keeps it commented.

Scope (agreed with David): preamble = YAML guide + `global_log_level` + `mission:` +
`security:` + `pipeline:`. Not `cap_missions:` / `combat_missions:` / `build:` (those are
migrated data, noise in a fresh scaffold). The shipped default `mission.yaml` (lockstep)
needs no change since `convert-v5` / `generate-config` output is unchanged.

## Testing Decisions

- New `TestMissionTemplatePreamble`: every tier carries the guide / `global_log_level` /
  `security:` / `pipeline:` / enriched `mission:` hints; the preamble is commented-out
  (only `mission.name` is live); the prepare output reuses the generate-config helpers verbatim.
- Regression: `generate-config` output diffed before/after the refactor → identical.

## Out of Scope

- `convert-v5`'s migrated sections (`cap_missions`, `combat_missions`, `build`).
- Unifying `prepare` and `generate-config` into a single command.
