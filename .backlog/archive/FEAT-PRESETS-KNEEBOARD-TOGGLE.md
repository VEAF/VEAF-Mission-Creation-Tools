# Lot FEAT-PRESETS-KNEEBOARD-TOGGLE — disable preset kneeboard generation (with Tripack)

Status: ✅ done
Branch: feat/presets-kneeboard-toggle → PR → develop

## Problem Statement

The presets pipeline step does two things at once — inject radio presets into every
human-piloted aircraft, **and** generate a kneeboard PNG per used preset
(`KNEEBOARD/IMAGES/presets-<name>.png`, `presets_injector_worker.py:428–437`).
Today `pipeline.presets` is a bare **boolean** (`presets: true|false`,
`mission_builder_worker.py:431`): the only way to stop the kneeboards is to disable
the whole step, which also drops the radio injection. Tripack wants to keep the radio
presets but suppress the generated kneeboards globally.

Separately, pipeline configuration is hard to discover from the mission-maker GUIDE:
it has a "Configurer les modules" section but no symmetric pipeline section, so a
mission-maker must hunt through PIPELINE_REFERENCE / the mission.yaml index to find
the presets config (David's feedback #2).

## Solution

1. **Polymorphic `pipeline.presets`** (scalar *or* mapping), backward-compatible:

   ```yaml
   pipeline:
     presets: true               # unchanged: inject presets + kneeboards
     # or:
     presets:
       enabled: true             # default true — inject radio presets
       kneeboards: true          # default true — generate kneeboard PNGs
   ```

   `presets: {enabled: true, kneeboards: false}` injects presets without kneeboards.
   `presets: false` still disables the whole step (unchanged).

2. **GUIDE-MM pipeline section** ("Configurer le pipeline de build",
   `{#configuring-pipeline}`) mirroring "Configurer les modules": a table of pipeline
   steps (presets, waypoints, aircraft groups, weather) with one-line roles +
   deep-links to PIPELINE_REFERENCE, plus a short `presets:` example showing the new
   `kneeboards` key.

## Decisions (validated by David)

- Polymorphic scalar-or-mapping under `pipeline.presets`, following the existing
  `enabled:` convention — **no** sibling top-level `pipeline.kneeboards` key.
- **Per-plate** (disable kneeboards for selected presets only) is **dropped** — not
  even a ticket for now.
- No ADR (follows the `enabled:` convention; not "surprising").
- Glossary: `Preset kneeboard` / `planchette` term added to `CONTEXT.md` during the
  grill session.

## Scope

- **Ticket 01** — implement the polymorphic `pipeline.presets` + `kneeboards` toggle
  (build config parsing + presets worker), with tests.
- **Ticket 02** — GUIDE-MM pipeline section + MISSION_YAML_REFERENCE / PIPELINE_REFERENCE
  updates for the polymorphic schema.

## Out of scope

- Per-preset / per-plate kneeboard selection (dropped).
- Changing what a kneeboard contains or the `used_in_mission` gating
  (`presets_manager.py`).
- convert-v5 / generate-config output: keep emitting `presets: true` (scalar); the
  mapping form is opt-in.

---

## 01 — Polymorphic pipeline.presets + kneeboards toggle

Status: ✅ done

### Context

- `pipeline.presets` is read as a bare boolean in `mission_builder_worker.py`
  (`self.pipeline_cfg = self.mission_yaml.get("pipeline") or {}`, then a truthiness
  check per step, plus `pipeline_step_enabled_anywhere` for the orphan-file warning
  in `build_profiles.py`).
- Kneeboard PNGs are written in `presets_injector_worker.py:428–437`
  (`_write_mission`, keyed by `preset_name`); generation happens in
  `generate_presets_images()` (`presets_manager.py:1628`).

### Tasks (TDD)

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

### Definition of Done

- `poetry run pytest` green; `ruff check --fix`, `ruff format --check`, and
  `mypy src/python/veaf-tools/` clean (presets worker is **not** in the mypy
  ignore list — keep it clean).
- `--cov-fail-under` bumped so it sits no more than ~2 points below measured coverage.
- Both YAML forms verified; scalar back-compat proven by test.

---

## 02 — GUIDE-MM "Configurer le pipeline" section + reference updates

Status: ✅ done

### Context

The mission-maker GUIDE has "Configurer les modules {#configuring-modules}" but no
symmetric pipeline section; pipeline step config is only reachable via
PIPELINE_REFERENCE and the mission.yaml index (David's feedback #2). This ticket also
documents the new `pipeline.presets.kneeboards` toggle from ticket 01.

### Tasks

- [ ] Add "Configurer le pipeline de build" with explicit anchor `{#configuring-pipeline}`
      (identical id in FR + EN, per the DOC-GUIDE-ANCHORS convention) to
      `doc/mission-maker/GUIDE.md` and `GUIDE.en.md`, placed right after
      "Configurer les modules":
  - [ ] Table of pipeline steps (presets, waypoints, aircraft groups, weather): one-line
        role + deep-link to the matching PIPELINE_REFERENCE anchor.
  - [ ] Short inline `presets:` example showing the polymorphic mapping incl.
        `kneeboards: false`.
- [ ] Update `doc/MISSION_YAML_REFERENCE.md` (+ `.en.md`) `pipeline:` / `pipeline.presets`
      rows to document the scalar-or-mapping form (`enabled`, `kneeboards`).
- [ ] Update `doc/PIPELINE_REFERENCE.md` (+ `.en.md`) presets step to mention the
      `kneeboards` toggle (the step already notes it generates kneeboard PNGs).
- [ ] CHANGELOG entry (may share the lot's `[Unreleased]` entry with ticket 01).

### Definition of Done

- GUIDE FR + EN carry `id="configuring-pipeline"`; deep-links resolve; markdown-lint clean.
- References describe the polymorphic `pipeline.presets` consistently with the code
  from ticket 01.
