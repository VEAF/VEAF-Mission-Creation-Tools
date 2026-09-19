# 03 — References to things the Mission Editor does not have

Status: ✅ done

Type: docs · Files: `doc/mission-maker/build-messages/missing-references.md` + `.en.md`

## What it is

The largest family, and the one that costs a session in DCS rather than a minute at the console:
`mission.yaml` names a group, a zone, a unit or an airfield that is not in the `.miz`. The build
prints a framed summary at the end and produces the mission anyway; the feature then does nothing
in game, silently.

Messages: `builder.reference_issues_header`, `validate.missing_group` /
`builder.declared_group_missing`, `validate.missing_trigger_zone`,
`validate.missing_trigger_zone_optional`, `validate.missing_unit`, `validate.unknown_airfield`,
`validate.undeclared_subzone`.

## What it has to carry, beyond the message text

- **Why the build did not stop.** Deliberate: blocking would deny the maker the `.miz` they need in
  order to place the missing object.
- **The `section` in the message is a `mission.yaml` path**, and the page says which sections are
  checked — ASSETS, QRA, COMBATZONE, SANCTUARY, `cap_missions`, `combat_missions` — because a
  reader who does not know that will search the wrong file.
- **The two traps that are not typos.** `cap_missions` groups are looked up with the
  `OnDemand-` prefix the runtime adds, so the editor group is named `OnDemand-<name>`; a SANCTUARY
  `polygon_units` entry may name a **group** as well as a unit.
- **Optional versus mandatory.** An AIRWAVES `trigger_zone_name` with an explicit centre and radius
  degrades to a warning and the mission still works; a QRA or COMBATZONE zone does not.
- **What it is not.** Not a VEAF script failure, and not something a rebuild fixes.

## Definition of done

- [x] Both languages, in the `nav` with `nav_translations`
- [x] One explicit anchor per message, derived from its locale key
- [x] The checked `mission.yaml` sections are listed, matching `group_validation.py`
- [x] `poetry run docs-check` passes
