# Lot FEAT-COMBATZONE-RADIO-GROUPS — combat-zone radio grouping + global menu pagination

Status: 🔄 in-progress
Branch: claude/combat-zone-radio-config-e13993 → PR → develop-v6
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
