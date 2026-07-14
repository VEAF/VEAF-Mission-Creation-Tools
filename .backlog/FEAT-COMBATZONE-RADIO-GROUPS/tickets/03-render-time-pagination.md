# 03 — Render-time radio menu pagination (opt-out) — ADR 0013

Status: ⬜ ready

## Context

DCS truncates a submenu past 10 items. Pagination is opt-in today
(`addPaginatedRadioElements` / `_buildRadioMenuPage`, used only by `veafAssets` /
`veafCombatMission`); Combat Zone and any other growing menu overflow silently.
Move pagination into the render step so it applies to every menu automatically.
Full rationale, the exact-count argument, and the `ForUnit` guard: ADR 0013.

## Tasks

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

## Definition of Done

- luaunit tests: ≤10 children → no `Next page`; 11+ → paged, no page exceeds the
  limit; deep overflow recurses; `doNotPaginate` suppresses paging; a `ForUnit`
  node is left unpaged with a warning; `veafAssets` / `veafCombatMission` menus
  still build correctly with no double `Next page`.
- Combat Zone menu with >10 zones (or >10 in a group) paginates with no combat-zone
  code change.
- `test-lua` green; `stylua --check` + `luacheck` (CI) clean; Lua coverage floor
  bumped.
