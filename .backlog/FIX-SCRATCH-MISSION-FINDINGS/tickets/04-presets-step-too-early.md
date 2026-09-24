# 04 — The presets step runs before the aircraft it should fill exist

Status: ⬜ ready
Type: fix
Files: `src/python/veaf-tools/veaf_tools/commands/build.py`, tests

## What happens

`build.py` runs presets (~l. 295) **before** `spawnable_aircrafts` and `dynamic_slot_templates`
(~l. 314). `FIX-WAYPOINTS-STEP-TOO-EARLY` moved the waypoints step for exactly this reason (comment
~l. 342) and left presets where it was.

## Measured

GermanyCW-v6: « Traitement de 7 groupes d'aéronefs — Préréglages injectés dans 0 aéronefs », then 64
templates injected from `dynamic-slot-templates.yaml`. In the built mission: 64 templates, **0** with
a `Radio` table. A pilot taking one of those dynamic slots has no presets.

## What it is not

Not every mission. Where the templates are placed in the **source** mission they exist when presets
run and get them: VEAF-Demo-Mission 2 of 2 templates with `Radio`, Caucasus v6 62 of 76. David's
recollection that "our v6 test missions have presets on dynamic slots" is right for those. The
defect is on the `prepare` path, where the templates come from YAML — the default for a new folder.

## Done when

- Presets run after both aircraft-injection steps, guarded by a source-order test bounded on both
  sides like the waypoints one
- GermanyCW-v6 rebuilt: 64 of 64 blue templates carry the plan's channels
- Kneeboards generated for the injected types too
