# 03 — Holes and structure: what no user can currently discover

Status: ✅ done 2026-08-13 — A, B and C applied in both languages; four of the ticket's items were contradicted by measurement (see the PRD)
Type: feat
Files: `doc/pilot/`, `doc/mission-maker/`, `doc/developer/`, `doc/ROADMAP.*`, `mkdocs.yml`

The gap hunt ranked these by user impact. Items 1-3 are behaviour a pilot hits in game **today**
with either no documentation or the old model's documentation (ticket 01 removes the lies; this
ticket writes the replacements' missing halves).

## A. Pilot-facing gaps

- [ ] `doc/pilot/GUIDE.md` §Sécurité (+ EN) — beyond ticket 01's corrections, the section needs the
      full new-model narrative: per-command password for unlisted pilots, lowest-occupant rule with
      a worked example (instructor + student), `_auth elevate` with its 2-minute cap, the tier
      table incl. `OPEN` and `MM`. One section, pilot vocabulary, no implementation jargon.
- [ ] Guided checklists: the pilot F10 tree (`pilot/GUIDE.md:52-63` mermaid) and the feature table
      (`pilot/README.md:20-27`) must show the `Assistance` submenu and link the pilot section of
      `veafAssist.md` (`#for-pilots` anchor exists). A pilot who saw it in game currently has no
      path to it.
- [ ] Coalition-scoped menus (`FEAT-COMBATZONE-MENU-COALITION`, changes existing missions):
      one paragraph in `pilot/GUIDE.md` §Zones de combat — you only see your side's zones;
      `radio_menu_coalition: ALL` restores the old behaviour (maker-side pointer).
- [ ] `kneeboard_only` FC3 types (PR #690/#691): a subsection in
      `mission-maker/dcs-radio-specs.md` + `developer/radio-preset-projection.md` — ten FC3 types
      get a kneeboard and deliberately no `Radio` table; the pilot's "why are my presets empty?"
      and the maker's "why no Radio?" both answered. Port EN's `## Per-type kneeboards (ADR 0012)`
      section to FR (`radio-preset-projection.en.md:125`, no FR counterpart).
- [ ] `capture-map --parking` (`FEAT-MCP-MUTATION-ACTIONS` 08): document the flag, the
      `parking/<theatre>.json` output and the `parking` vs `parking_id` pair in
      `developer/capture-airbases.md` + `developer/dcs-data.md` (+ the GUIDE command table row).

## B. Reference gaps (from the CLI/YAML audit)

- [ ] `MISSION_YAML_REFERENCE.md` — cross-reference the four top-level keys parsed but documented
      elsewhere: `dcs_bridge`, `strip_native_triggers`, `conversion_profile`, `config_override`
      (one row each, linking the owning page).
- [ ] `era` auto-detection (`era_detector.py:130-150`, written back into mission.yaml when absent):
      document in the `era` row.
- [ ] `PIPELINE_REFERENCE.md` — add `warehouses` to the `pipeline:` fields table (`:41-48`), the
      root-level `warehouses.yaml` location, and the `enabled` / `presets.kneeboards` sub-fields to
      the step table.
- [ ] `MISSION_YAML_REFERENCE.md` Category A table + folder tree — add `spawn-groups.yaml` and
      `src/warehouses.yaml`.
- [ ] `TOOLS_REFERENCE.md` — add `build-standalone` and `build-kit` to the veaf-build list; complete
      `update-dcs-data`'s eight missing options.
- [ ] `src/defaults/mission-folder/mission.yaml` — add a commented `delay_seconds:` example to the
      `custom_scripts:` block (defaults-lockstep rule: the shipped default is where a maker copies
      from, and the feature is invisible there).
- [ ] Unify the FR/EN index taxonomies of `MISSION_YAML_REFERENCE` (FR 3-tier vs EN 6-domain; pick
      the EN domains, port to FR, add the 5 entries FR lacks, drop EN's duplicate QRA row, add the
      4 sections both omit).

## C. Structure (David's arbitrations b, e, f)

- [ ] **b** — `doc/ROADMAP.md` + `.en.md` → thin pointer: two paragraphs, a link to the root
      [`ROADMAP.md`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/ROADMAP.md),
      and the three vision axes. Kill the fossil content (wrong master claim, dead version numbers,
      EN older than FR). Keep the page in nav (inbound links exist).
- [ ] **f** — normalise `AI_ASSISTANT_CATALOG.md` FR anchors to the EN slugs (repo convention:
      identical anchors, heading text translated). ~30 anchors + their same-page index links.
- [ ] Nav (`mkdocs.yml`): a pilot-visible entry for checklists ("Checklists guidées" /
      "Guided checklists" → the veafAssist pilot anchor or a small dedicated page) and one for
      security ("Sécurité & permissions"), so the two biggest behaviour features are findable by
      name rather than as the 4th and 19th alphabetical Lua module.
- [ ] README (scripts dir): link `veafAssist.md` (only page with no README entry) and `veafRadio.md`
      (named as plain text at `:15`).

## Acceptance criteria

- [ ] Every new section in both languages, nav entries with `nav_translations`.
- [ ] `docs-check` green (it will now enforce `--parking` if `FIX-DOCAUDIT-CODE` 04 lands first —
      sequence the code lot's gate hardening **before** or **with** this PR).
- [ ] CHANGELOG entry; version bump ×3 manifests (shared with ticket 04's PR).
