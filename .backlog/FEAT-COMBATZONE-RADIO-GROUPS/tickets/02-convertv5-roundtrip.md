# 02 — convert-v5 round-trip of `radio_group_name` + `radio_menu_prefix`

Status: ✅ done

## Context

A v5 `missionConfig.lua` can call `:setRadioGroupName("...")` /
`:setRadioMenuPrefix("...")` on a `VeafCombatZone:new()` chain, but
`config_migrator.py._parse_combat_zone` does not extract them, so the grouping /
prefix is dropped on conversion. Add symmetric extraction so the round-trip is
iso-functional (extract here → emit in ticket 01).

## Tasks

- [ ] In `_parse_combat_zone` (`config_migrator.py`), add regex extraction of
      `:setRadioGroupName\s*\(\s*"([^"]+)"\s*\)` → `zone["radio_group_name"]` and
      `:setRadioMenuPrefix\s*\(\s*"([^"]+)"\s*\)` → `zone["radio_menu_prefix"]`,
      mirroring the existing `setFriendlyName` extraction.
- [ ] Leave `_parse_combat_operation` untouched (zones only).

## Definition of Done

- A v5 zone chain calling `setRadioGroupName` / `setRadioMenuPrefix` produces the
  matching YAML keys; a chain without them produces neither. Unit tests cover both,
  plus an end-to-end v5→v6 fixture (grouped + prefixed zones) that survives the full
  convert → generate cycle unchanged.
- `ruff`, `ruff format --check`, `mypy`, `pytest` green; coverage gate bumped.
