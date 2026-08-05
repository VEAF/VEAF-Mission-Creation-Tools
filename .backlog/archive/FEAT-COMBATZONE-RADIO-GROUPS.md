# Lot FEAT-COMBATZONE-RADIO-GROUPS — combat-zone radio grouping + global menu pagination

Status: ✅ done
Branch: claude/combat-zone-radio-config-e13993 → PR → develop
ADR: [0013](../../docs/adr/0013-radio-menu-pagination.md)

## Problem Statement

Two related gaps in the F10 radio surface:

1. **Combat-zone menu organisation is unreachable from config.** `veafCombatZone`
   already has the runtime machinery to group zones into a named intermediate
   submenu (`setRadioGroupName` → `buildRadioMenu` gathers zones sharing a name)
   and to prefix a zone's label (`setRadioMenuPrefix`). Both setters are
   **orphans** — nothing calls them: no YAML key, and `convert-v5` neither extracts
   them from a v5 `missionConfig.lua` nor emits them. A maker cannot organise the
   combat-zone menu without hand-editing Lua, and a v5 mission that grouped its
   zones loses that grouping on conversion.

2. **Radio menus overflow silently past 10 items.** DCS truncates a submenu beyond
   ten entries. VEAF's pagination is **opt-in** (`addPaginatedRadioElements`, used
   only by `veafAssets` / `veafCombatMission`); every other menu — most visibly
   Combat Zone with one submenu per zone and per radio group — overflows without
   warning.

## Solution

### Combat-zone config (points 1–2)

Two **optional per-zone** keys under `modules.COMBATZONE.combat_zones[]`, each a
1:1 mapping onto the existing runtime setter, round-tripped by `convert-v5`:

```yaml
modules:
  COMBATZONE:
    combat_zones:
      - zone_name: "CZ-Alpha"
        friendly_name: "Alpha"
        radio_group_name: "North"     # → :setRadioGroupName("North")  (submenu)
        radio_menu_prefix: "BLUE"     # → :setRadioMenuPrefix("BLUE")  (label prefix)
```

- `radio_group_name`: zones sharing the value are gathered under one intermediate
  submenu of that name inside the Combat Zone menu. Absent → zone sits at the root.
- `radio_menu_prefix`: cosmetic prefix on the zone's menu label (`BLUE * Alpha`).

### Global pagination (point 3, ADR 0013)

Paginate **at render time** in `veafRadio.RadioMenuBuilder:_buildSubtree`,
automatically and for every menu, **opt-out** via `veafRadio.doNotPaginate(menu)`.
Combat-zone pagination falls out for free — no combat-zone code. Full rationale,
the exact-count argument, and the `ForUnit` guard are in ADR 0013.

## Decisions (validated by David)

- Two per-zone keys `radio_group_name` + `radio_menu_prefix`; a group is **not** a
  first-class object (no separate `radio_groups:` block, no ordering config) — the
  submenu is born from the first zone that names it.
- `convert-v5` round-trips both, symmetric to the other zone attributes
  (`_parse_combat_zone` extracts, `_emit_combat_zone_def` emits).
- Pagination lives at render time, opt-out, item count = one per logical child
  (exact — no `ForUnit` in use); `ForUnit` menus auto-disable pagination + warn.
- `addPaginatedRadioElements` / `addPaginatedRadioMenu` **keep their names**; their
  internal pagination (`_buildRadioMenuPage`) is removed to avoid double pagination.
- ADR required (render-time pagination changes the behaviour of every radio menu)
  → ADR 0013.
- **No ad-hoc schema validation** for the two keys (ticket 01): combat-zone
  attributes have no type/unknown-key validation today; a bespoke check for these
  two only would be an inconsistent new pattern for optional strings emitted
  verbatim. Left out of scope.

## Scope

- **Ticket 01** — combat-zone config: emit `:setRadioGroupName(...)` /
  `:setRadioMenuPrefix(...)` from `radio_group_name` / `radio_menu_prefix`
  (`lua_config_generator.py._emit_combat_zone_def`) + schema validation of the two
  keys (`mission_validator.py`). Python + tests.
- **Ticket 02** — `convert-v5` round-trip: extract `:setRadioGroupName("...")` /
  `:setRadioMenuPrefix("...")` in `config_migrator.py._parse_combat_zone`. Python +
  tests (incl. a v5→v6 fixture that grouped/prefixed zones).
- **Ticket 03** — render-time pagination (ADR 0013): paginate in
  `RadioMenuBuilder:_buildSubtree` with `MENU_PAGE_SIZE`, `veafRadio.doNotPaginate`,
  the `ForUnit` auto-disable + warning; add `radio.next_page` to the Lua runtime
  locales and use `veaf.t`; strip `_buildRadioMenuPage` and the internal pagination
  from `addPaginatedRadio*` (names kept, `veafAssets` / `veafCombatMission`
  unchanged). Lua + luaunit tests (≤10 untouched, 11+ paginates, deep recursion,
  opt-out, `ForUnit` guard).
- **Ticket 04** — docs + defaults lockstep: combat-zone module doc
  (`radio_group_name` / `radio_menu_prefix`), `veafRadio` doc (automatic pagination
  + `doNotPaginate`), `src/defaults/mission-folder/mission.yaml` (a commented
  combat zone showing both keys), MISSION_YAML_REFERENCE. CONTEXT.md glossary
  (`Combat zone radio group`, `Combat zone menu prefix`) already landed during the
  grill.

## Cross-cutting Definition of Done

- **Quality ratchet** (CLAUDE.md §3): the Python workers touched
  (`lua_config_generator.py`, `config_migrator.py`, `mission_validator.py`) are
  **no longer** in the mypy `ignore_errors` list (only `luadata` remains) — keep
  them clean, add none. Bump `--cov-fail-under` (currently 76) to stay within
  ~2 pts of measured coverage. The Lua coverage ratchet floor only ever goes up.
- **Defaults lockstep** (CLAUDE.md §9.7): `src/defaults/mission-folder/mission.yaml`
  updated in this lot (ticket 04).
- Quality gate green: `ruff check --fix`, `ruff format --check`, `mypy`, `pytest`,
  `test-lua`, `stylua --check`, `luacheck` (CI).

## Out of scope

- A first-class radio-group object (explicit `radio_groups:` block, empty groups,
  group ordering) — the per-zone attribute covers the need.
- `convert-v5` inventing groups the v5 mission did not declare (no inference — pure
  round-trip of what `setRadioGroupName` / `setRadioMenuPrefix` was called with).
- Per-group / per-pilot pagination for `USAGE_ForUnit` menus (auto-disabled + warn
  instead) — ADR 0013.
- Configurable page size (fixed at the DCS limit of 10).

---

## 01 — Combat-zone `radio_group_name` + `radio_menu_prefix` config keys

Status: ✅ done

### Context

`veafCombatZone` already exposes `setRadioGroupName` (groups zones under a named
intermediate submenu, consumed by `buildRadioMenu`) and `setRadioMenuPrefix`
(prefixes the zone's menu label), but no config path feeds them:
`lua_config_generator.py._emit_combat_zone_def` emits `friendly_name`, `briefing`,
`training`, chained zones… but not these two. Add both as optional per-zone keys.

### Tasks

- [x] In `_emit_combat_zone_def` (`lua_config_generator.py`), emit
      `:setRadioGroupName("<v>")` when `zone_def["radio_group_name"]` is present, and
      `:setRadioMenuPrefix("<v>")` when `zone_def["radio_menu_prefix"]` is present,
      placed in the builder chain like the other string setters.
- [x] Do NOT add them to combat *operations* (`_emit_combat_operation`) — scope is
      combat zones only.

### Decision — no ad-hoc schema validation

The planned per-key type validation was **dropped**: combat-zone attributes have
**no** type/unknown-key validation anywhere today (`collect_module_issues` stops at
the module level; `friendly_name`, `briefing`, … are consumed by `.get()` and
unknown keys are silently ignored). Adding a bespoke check for these two keys only
would be an inconsistent new pattern (RULE simplicity/surgical) with little value —
they are optional strings emitted verbatim. Validation stays out of scope.

### Definition of Done

- Given a combat zone with `radio_group_name` / `radio_menu_prefix`, the generated
  config Lua contains the matching `:setRadioGroupName(...)` / `:setRadioMenuPrefix(...)`
  call; absent keys emit nothing. Unit test covers present + count.
- `ruff`, `ruff format --check`, `mypy`, `pytest` green.

---

## 02 — convert-v5 round-trip of `radio_group_name` + `radio_menu_prefix`

Status: ✅ done

### Context

A v5 `missionConfig.lua` can call `:setRadioGroupName("...")` /
`:setRadioMenuPrefix("...")` on a `VeafCombatZone:new()` chain, but
`config_migrator.py._parse_combat_zone` does not extract them, so the grouping /
prefix is dropped on conversion. Add symmetric extraction so the round-trip is
iso-functional (extract here → emit in ticket 01).

### Tasks

- [ ] In `_parse_combat_zone` (`config_migrator.py`), add regex extraction of
      `:setRadioGroupName\s*\(\s*"([^"]+)"\s*\)` → `zone["radio_group_name"]` and
      `:setRadioMenuPrefix\s*\(\s*"([^"]+)"\s*\)` → `zone["radio_menu_prefix"]`,
      mirroring the existing `setFriendlyName` extraction.
- [ ] Leave `_parse_combat_operation` untouched (zones only).

### Definition of Done

- A v5 zone chain calling `setRadioGroupName` / `setRadioMenuPrefix` produces the
  matching YAML keys; a chain without them produces neither. Unit tests cover both,
  plus an end-to-end v5→v6 fixture (grouped + prefixed zones) that survives the full
  convert → generate cycle unchanged.
- `ruff`, `ruff format --check`, `mypy`, `pytest` green; coverage gate bumped.

---

## 03 — Render-time radio menu pagination (opt-out) — ADR 0013

Status: ✅ done

### Context

DCS truncates a submenu past 10 items. Pagination is opt-in today
(`addPaginatedRadioElements` / `_buildRadioMenuPage`, used only by `veafAssets` /
`veafCombatMission`); Combat Zone and any other growing menu overflow silently.
Move pagination into the render step so it applies to every menu automatically.
Full rationale, the exact-count argument, and the `ForUnit` guard: ADR 0013.

### Tasks

- [ ] Add `veafRadio.MENU_PAGE_SIZE = 10` and `veafRadio.doNotPaginate(menu)`
      (sets `menu.noPagination = true`).
- [ ] In `RadioMenuBuilder:_buildSubtree`: after sorting, if a node has more than
      `MENU_PAGE_SIZE` logical children (commands + submenus) and is not opted out,
      distribute the overflow across on-the-fly `Next page` submenus in the **DCS
      projection only** (logical tree untouched; module-held references stay valid).
      Recurse so page 2 paginates too.
- [ ] `ForUnit` guard: if a node holds a `USAGE_ForUnit` command, auto-disable its
      pagination and log a warning (`ForUnit` multiplies entries per callsign; no
      module uses it today).
- [ ] Add `radio.next_page` to the Lua runtime locales (`fr.json` / `en.json`) and
      label pages with `veaf.t("radio.next_page")` (ADR 0006) — no English literal.
- [ ] Remove `_buildRadioMenuPage` and the internal pagination from
      `addPaginatedRadioElements` / `addPaginatedRadioMenu` (keep the names + the
      sort-and-insert behaviour) so they no longer double-paginate; `veafAssets` /
      `veafCombatMission` callers stay unchanged.

### Definition of Done

- luaunit tests: ≤10 children → no `Next page`; 11+ → paged, no page exceeds the
  limit; deep overflow recurses; `doNotPaginate` suppresses paging; a `ForUnit`
  node is left unpaged with a warning; `veafAssets` / `veafCombatMission` menus
  still build correctly with no double `Next page`.
- Combat Zone menu with >10 zones (or >10 in a group) paginates with no combat-zone
  code change.
- `test-lua` green; `stylua --check` + `luacheck` (CI) clean; Lua coverage floor
  bumped.

---

## 04 — Docs + defaults lockstep

Status: ✅ done

### Context

The new combat-zone keys and the automatic pagination change user-facing behaviour
and config; documentation + the shipped default must move in lockstep (CLAUDE.md
§9.7). CONTEXT.md glossary entries (`Combat zone radio group`, `Combat zone menu
prefix`) already landed during the grill.

### Tasks

- [ ] Combat-zone module doc: document `radio_group_name` (grouping submenu) and
      `radio_menu_prefix` (label prefix) as optional per-zone keys (FR + `.en`).
- [ ] `veafRadio` doc: document automatic render-time pagination (menus over 10
      items get `Next page` automatically) and `veafRadio.doNotPaginate(menu)` as
      the opt-out; note the `ForUnit` guard.
- [ ] `src/defaults/mission-folder/mission.yaml`: add a commented combat zone under
      `modules.COMBATZONE.combat_zones` showing both keys.
- [ ] MISSION_YAML_REFERENCE (and any module-key index): add the two keys.

### Definition of Done

- Docs describe both keys and the pagination behaviour/opt-out; FR and `.en` stay
  in sync.
- Shipped default `mission.yaml` illustrates `radio_group_name` / `radio_menu_prefix`
  and matches what `lua_config_generator` produces.
- `CHANGELOG.md` `[Unreleased]` has one entry for the lot; markdown-lint clean.
