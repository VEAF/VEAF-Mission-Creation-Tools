# 02 — GUIDE-MM "Configurer le pipeline" section + reference updates

Status: ✅ done

## Context

The mission-maker GUIDE has "Configurer les modules {#configuring-modules}" but no
symmetric pipeline section; pipeline step config is only reachable via
PIPELINE_REFERENCE and the mission.yaml index (David's feedback #2). This ticket also
documents the new `pipeline.presets.kneeboards` toggle from ticket 01.

## Tasks

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

## Definition of Done

- GUIDE FR + EN carry `id="configuring-pipeline"`; deep-links resolve; markdown-lint clean.
- References describe the polymorphic `pipeline.presets` consistently with the code
  from ticket 01.
