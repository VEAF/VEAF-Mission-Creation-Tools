---
status: accepted
---

# Automatic radio menu pagination at render time (opt-out)

## Context

DCS silently truncates an F10 radio submenu past **10 items**. VEAF already had a
pagination helper (`veafRadio.addPaginatedRadioElements` / `addPaginatedRadioMenu`
+ the internal `_buildRadioMenuPage`), but it was **opt-in**: a caller had to
pre-paginate a list of elements it owned, before the menu tree was built. Only
`veafAssets` and `veafCombatMission` used it. Every other menu that can grow past
ten entries — most visibly the Combat Zone menu (one submenu per zone, and per
radio group) — overflowed silently.

## Decision

Paginate **at render time**, inside `veafRadio.RadioMenuBuilder:_buildSubtree`,
automatically and for every menu, with an **opt-out** flag.

- When a node has more than `veafRadio.MENU_PAGE_SIZE` (= 10) children to push to
  DCS, the builder creates `Next page` submenus on the fly and distributes the
  overflow across them. The pages exist **only in the DCS projection** — the
  logical menu tree is untouched, so the references modules hold (`rootPath`,
  submenu handles) stay valid.
- **Opt-out**: `veafRadio.doNotPaginate(menu)` sets `menu.noPagination = true`.
- **Item count = one per logical child** (each submenu, each command counts as 1).
  This is exact — not an approximation — because a node produces at most one DCS
  entry per group: submenus and `USAGE_ForAll` commands are global (1 entry),
  `USAGE_ForGroup` commands are at most 1 per group. The pages being **global**
  submenus, the item→page assignment is identical for every pilot; a pilot who
  cannot see a per-group command simply sees a shorter page — never an overflow.
- **`USAGE_ForUnit` guard**: `ForUnit` is the only multiplier (one command → one
  DCS entry *per callsign*), so a single node could exceed ten for a multi-seat
  group. No module uses `ForUnit` today. Rather than build per-group pagination
  for a case that does not exist, a menu containing a `ForUnit` command has its
  pagination **auto-disabled** (same `noPagination` flag) with a logged warning.

The `Next page` label goes through runtime i18n (`veaf.t("radio.next_page")`,
[ADR 0006](0006-lua-runtime-i18n.md)) instead of the former English literal.

## Consequences

- Combat Zone pagination (and any future overflowing menu) is **free** — no
  per-module code. The Combat Zone lot adds nothing for pagination.
- The opt-in helpers `addPaginatedRadioElements` / `addPaginatedRadioMenu` **keep
  their names** (public Lua API, two callers unchanged) but lose their internal
  pagination logic (`_buildRadioMenuPage` is removed) to avoid double pagination —
  they now just sort and insert their elements; the render paginates.
- The 10-item safety is now a global invariant of the builder, not a discipline
  each caller must remember.

## Alternatives rejected

- **Keep pagination opt-in** and just call the helper from Combat Zone — leaves
  every other menu (including the `-VEAF-` root) unprotected; the maintainer must
  remember to paginate each new menu.
- **Exact per-group pagination for `ForUnit`** (distinct `Next page` per pilot) —
  real per-group page trees for a usage no module exercises; the auto-disable
  guard is the pragmatic floor.
