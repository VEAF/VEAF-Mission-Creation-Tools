# FIX-AUDIT-FINDINGS-2026-11 — the four audit findings on VMCT, and the pypdf alerts

Status: ✅ done (#1236)

Origin: the audit repository `davidp57/security-audits`, issues #137, #138, #146 and #147 (2026-10-26 and 2026-11-02), plus seven open Dependabot alerts on `pypdf` 6.21.2. Taken together on 2026-11-04 at David's request, one PR.

## What each finding is

| Issue | Defect | Fix |
|---|---|---|
| #147 | A `groupFilter` / `perPilot` menu nested under a menu already rendered for one group never asks its own filter: every pilot of the outer menu sees it. | `_buildSubtree` asks the node's filter under an inherited scope too — for the pilot the scope is bound to, or for each live pilot of the group; a per-pilot menu splits only between the pilots who pass. |
| #146 | `RADIO.init.help_menus` is passed unchanged to `skipHelpMenus`, so `true` hides the help entries; the docs say both things. | Negate it like `create_menus`. Default changed to `false` so the generated call stays `veafRadio.initialize(true)`: every v5 `missionConfig.lua` skipped the help menus, and no built mission has shown them. Docs and the shipped default follow. |
| #138 | `add_group` stopped telling a static from the ground units already placed: one dropped on a launcher said nothing. | A separate overlap check, within 10 m of another unit (plus a marker's footprint). The issue's proposal (`separation=0` in `place_on_clear_ground`) would still keep the 40 m `PLACEMENT_MARGIN_METERS` and warn about a depot's tanks 20 m apart. |
| #137 | `set_route` refuses `HOME, IP, TGT, HOME`, which the injector and the validator accept since `e2ea2f09`. | Refuse a repeated name only at a different place; the same name at the same place lists its key twice. Action description and catalogue page updated. |
| Dependabot | `pypdf` 6.21.2, seven high alerts, development scope. | `poetry update pypdf` → 6.21.4. |

## Tickets

- [01 — Nested filtered menus keep their filter](tickets/01-nested-menu-filter.md)
- [02 — `help_menus` negated](tickets/02-help-menus-negated.md)
- [03 — A static on another unit is warned](tickets/03-static-overlap-warning.md)
- [04 — `set_route` takes a return to the departure point](tickets/04-set-route-return-home.md)
- [05 — pypdf 6.21.4](tickets/05-pypdf-bump.md)
