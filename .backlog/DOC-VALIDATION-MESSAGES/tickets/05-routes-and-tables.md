# 05 — Routes DCS refuses, and holed mission tables

Status: ⬜ ready

Type: docs · Files: `doc/mission-maker/build-messages/routes-and-tables.md` + `.en.md`

## What it is

Two small families that share a property: the message is about data **DCS itself** will reject or
choke on, so the reader has no way to guess the rule from the editor.

Messages: `validate.route_no_locked_time`, `validate.route_contradictory_locks`,
`validate.holed_sequence` / `builder.mission_table_renumbered`, plus the two
"configured but nothing to apply it to" warnings `validate.presets_no_aircraft` and
`validate.waypoints_no_aircraft`.

## What it has to carry, beyond the message text

- **The waypoint lock rule, in editor words.** *Locked time* is the ETA checkbox on a waypoint,
  *locked speed* the speed one. The editor refuses a route with no locked time at all, and one
  whose locked speed sits between two locked times. Found on 2026-08-22 by David, on a mission the
  validator had just called sound (`FIX-VALIDATE-CONTRADICTORY-WAYPOINT-LOCKS`).
- **Where a holed table comes from** — a hand edit or a third-party tool — and that the build
  closes the hole, so the message is an invitation to check, not a failure. The version that did
  *not* say so cost a debugging session: three holes surfaced at three unrelated subsystems under
  `'int' object has no attribute 'get'`, naming none of them.
- **What it is not.** Not something VMCT wrote. These are warnings on data that arrived that way.

## Definition of done

- [ ] Both languages, in the `nav` with `nav_translations`
- [ ] One explicit anchor per message, derived from its locale key
- [ ] The lock rule is stated as the editor's checkboxes, not as `ETA_locked` / `speed_locked` alone
- [ ] `poetry run docs-check` passes
