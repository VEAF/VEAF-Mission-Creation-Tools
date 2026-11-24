# FIX-AUDIT-FINDINGS-2026-11 — the four audit findings on VMCT, and the pypdf alerts

Status: ✅ done (#1236) · archived 2026-11-24

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

- [01 — Nested filtered menus keep their filter](FIX-AUDIT-FINDINGS-2026-11.md)
- [02 — `help_menus` negated](FIX-AUDIT-FINDINGS-2026-11.md)
- [03 — A static on another unit is warned](FIX-AUDIT-FINDINGS-2026-11.md)
- [04 — `set_route` takes a return to the departure point](FIX-AUDIT-FINDINGS-2026-11.md)
- [05 — pypdf 6.21.4](FIX-AUDIT-FINDINGS-2026-11.md)

## Tickets, in full

## 01 — Nested filtered menus keep their filter

Status: ✅ done

security-audits#147. `veafRadio.RadioMenuBuilder:_buildSubtree` asks `node.groupFilter` under an inherited scope: for `scope.unitName` when the parent is a pilot's menu, else for each live pilot of `scope.groupId`; no pilot passing renders nothing, and a per-pilot menu splits only between the pilots who pass.

Done when: `test_veafRadio_pilots.lua` covers a filtered per-pilot menu under a reserved one, a reserved menu under a reserved one, and a filtered per-pilot menu under a pilot's menu.

## 02 — `help_menus` negated

Status: ✅ done

security-audits#146. `help_menus` joins `_NEGATED_INIT_KEYS`, its default becomes `false` so a mission that does not mention it still gets `veafRadio.initialize(true)` (help entries hidden, as since v5). `veafRadio.md`, `MISSION_YAML_REFERENCE.md` (both languages) and the shipped `mission.yaml` say so.

Done when: `help_menus: true` generates `initialize(false)`, `false` and absent generate `initialize(true)`.

## 03 — A static on another unit is warned

Status: ✅ done

security-audits#138. `_static_clear_ground` checks `occupied_by(mission_content)` on its own, within `_STATIC_OVERLAP_METERS` (10 m) plus a marker's footprint, and warns without moving; the scenery check stays as it was.

Done when: a tank on an existing vehicle group is warned, three tanks 20 m apart are not.

## 04 — `set_route` takes a return to the departure point

Status: ✅ done

security-audits#137. A repeated name is refused only at another place (positions compared to the metre); the same name at the same place writes one point and lists its key twice. The `set_route` action description and the catalogue page (both languages) follow.

Done when: `HOME, PUSH, HOME` writes `[LION_HOME, LION_PUSH, LION_HOME]`, the injector reads three points, and `COAST` / `Coast` at two places is still refused.

## 05 — pypdf 6.21.4

Status: ✅ done

Seven open Dependabot alerts (high) on `pypdf` 6.21.2 in `poetry.lock`, development scope. `poetry update pypdf` → 6.21.4, which the alerts give as patched.

Done when: the lock holds 6.21.4 and Dependabot closes the alerts after merge.
