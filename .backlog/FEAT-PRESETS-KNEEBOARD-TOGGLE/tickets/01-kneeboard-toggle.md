# 01 — Polymorphic pipeline.presets + kneeboards toggle

Status: ✅ done

## Context

- `pipeline.presets` is read as a bare boolean in `mission_builder_worker.py`
  (`self.pipeline_cfg = self.mission_yaml.get("pipeline") or {}`, then a truthiness
  check per step, plus `pipeline_step_enabled_anywhere` for the orphan-file warning
  in `build_profiles.py`).
- Kneeboard PNGs are written in `presets_injector_worker.py:428–437`
  (`_write_mission`, keyed by `preset_name`); generation happens in
  `generate_presets_images()` (`presets_manager.py:1628`).

## Tasks (TDD)

- [ ] Failing test first: `pipeline.presets` accepts a mapping `{enabled, kneeboards}`;
      `enabled` drives whether the step runs (default `true` when mapping present);
      `kneeboards: false` suppresses PNG generation while presets are still injected.
- [ ] Failing test: scalar form still works — `presets: true` → inject + kneeboards;
      `presets: false` → step disabled. Back-compat regression guard.
- [ ] Normalise `pipeline.presets` (scalar-or-mapping → canonical `{enabled, kneeboards}`)
      where the build reads it; make sure `pipeline_step_enabled_anywhere` and the
      orphan-file warning still treat the mapping's `enabled` correctly.
- [ ] Thread a `generate_kneeboards` flag into the presets worker so
      `generate_presets_images()` is skipped (or its output not written) when false;
      no `KNEEBOARD/IMAGES/presets-*.png` emitted, radio injection unaffected.
- [ ] Defaults lockstep: reflect the new sub-key in
      `src/defaults/mission-folder/mission.yaml` (comment on `pipeline.presets` documenting
      the `{enabled, kneeboards}` form; keep the default value as-is).
- [ ] CHANGELOG `[Unreleased]`; PATCH bump in `pyproject.toml`; `poetry install`.

## Definition of Done

- `poetry run pytest` green; `ruff check --fix`, `ruff format --check`, and
  `mypy src/python/veaf-tools/` clean (presets worker is **not** in the mypy
  ignore list — keep it clean).
- `--cov-fail-under` bumped so it sits no more than ~2 points below measured coverage.
- Both YAML forms verified; scalar back-compat proven by test.
