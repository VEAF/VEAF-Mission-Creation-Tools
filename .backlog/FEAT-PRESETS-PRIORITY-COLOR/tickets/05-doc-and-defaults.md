# 05 — Docs + shipped-default lockstep

Status: ✅ done
Depends on: 01, 02, 03, 04

## Scope

- ADR 0012 — done (this lot's design record).
- CONTEXT.md glossary (`Channel priority`, `Channel colour`, updated `Preset
  kneeboard`) — done during grilling.
- Dev page `doc/developer/radio-preset-projection.md` (+ `.en.md`): document
  `priority` (universal + Viggen routing), `color`, the AJS-37 key mapping +
  Group-100 recycle, the `{priority}` special variant, per-type kneeboards + grey
  headers + Viggen labels. Update the AJS-37 row of the quirk table.
- `doc/PIPELINE_REFERENCE.md` (+ `.en.md`): mission-maker view of `priority` /
  `color` in `presets.yaml`.
- `dcs-radio-layouts.yaml` header comments: document the extended
  `trailing_specials` `{priority}` variant and the AJS-37's key mapping.
- Shipped-default `src/defaults/mission-folder/src/presets.yaml`: no functional
  change required (no AJS37 in the default missions), but add a commented
  `priority` / `color` example if it aids discoverability.

## Acceptance

- Docs describe the new attributes and the AJS-37 behaviour accurately; deep links
  resolve; FR/EN parity.
