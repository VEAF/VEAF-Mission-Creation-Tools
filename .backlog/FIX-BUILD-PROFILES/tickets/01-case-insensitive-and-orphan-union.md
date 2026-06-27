# 01 — Case-insensitive profiles + union-based orphan check

Status: 🔄 in-progress

## Tasks

- [ ] `resolve_profile` case-insensitive + canonical-name log; `canonical_profile_name`.
- [ ] Ambiguous case → warn + base fallback (`profiles.ambiguous_profile`, FR/EN).
- [ ] `build.py` `_build_plan` uses the canonical name for build + `.miz` suffix.
- [ ] `pipeline_step_enabled_anywhere`; orphan warning gated on it (`self._raw_yaml`).
- [ ] Tests: case-insensitive resolve, canonical name, ambiguity; enabled-anywhere truth
      table; orphan warning silent under a re-enabling profile, fires when disabled everywhere;
      `_build_plan` canonicalization.
- [ ] CHANGELOG `[Unreleased]`, PATCH bump.

## Definition of Done

- `poetry run pytest` green, coverage held; ruff/format/mypy clean; i18n parity ok.
