# 07 — Documentation, changelog, limitations, demo

Status: 🔄 in-progress

## Done when

- A FR/EN page for mission makers — what the training versions are, how to write the `training:` block, the rule table, how a vague element is drawn, what is refused and why — in the `mkdocs.yml` `nav` with its `nav_translations`, and `MISSION_YAML_REFERENCE` (FR/EN) documents `training:` and `remove_groups`.
- The support bot's page index is refreshed (`services/support-bot`, `refresh_doc_pages.py`).
- `poetry run docs-check` is green.
- `CHANGELOG.md` has one entry under `[Unreleased]`, at the end of the section.
- `known-limitations.yaml` carries what the lot leaves (training with `build_variants:`, a referenced group cannot be drawn) and ticket 05's measurement; `dcs-runtime-traps.md` is regenerated.
- A step in `VEAF/VEAF-Demo-Mission-v6` `tour/steps.yaml`, with its acceptance check: build the demo, launch `_TRAINING_SEAD` twice, see a different set of defences around the same site.
