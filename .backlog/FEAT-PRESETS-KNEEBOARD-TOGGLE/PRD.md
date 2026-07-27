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
