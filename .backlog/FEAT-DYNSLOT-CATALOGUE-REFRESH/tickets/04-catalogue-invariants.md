# 04 — The shipped catalogue gets an invariants test

Status: ✅ done
Type: test

## Why, before the graft rather than after

Tickets 05 and 06 add 24 templates and rewrite 11 loadouts inside a 9 504-line YAML, by script. A
scripted edit that finds nothing reports nothing — this repository has already shipped four commits
that each claimed to bump a version and left it untouched. Reading the result back by eye is not a
check, so the invariants the graft must preserve are written down first, as assertions.

Measured on the catalogue as it stands, so the test very nearly passes today:

- 104 templates, `hidden: true` and `lateActivation: true` on all 104, `x: 0` / `y: 0` at group
  **and** unit level on all 104, no `password` on any, one unit each, `skill: Client` and
  `dynSpawnTemplate: true` throughout.
- The group's `name:` equals its YAML key on all 104; the unit is named `<group name> #01` on all
  104; the single route point is named after the group on 103.
- 52 blue types **exactly** mirrored by 52 red types — no blue-only, no red-only.
- Two blemishes, both fixed by this ticket:
  - `CH-47F Template-1` is the only name off the `<X> Template` / `<X> Template Red` convention (its
    red counterpart is correctly `CH-47F Template Red`, and its own route point is already named
    `CH-47F Template` — it is the 103/104 above). Nothing outside the catalogue copies references the
    name, so renaming it to `CH-47F Template` breaks nothing and makes it self-consistent.
  - `F-15E S4+ Template Red` is filed under country `Russia` while the other 51 red templates are
    under `CJTF Red`. The warehouses step matches templates by name, not country, so moving it is
    safe.

## What to do

One test module asserting, on the shipped catalogue:

| invariant | why it matters |
|-----------|----------------|
| `hidden: true` and `lateActivation: true` on every template | a visible template is drawn on the F10 map (ticket 02) |
| `x == 0` and `y == 0`, group and unit | a template carries no position; Reaper's extract has real coordinates from two different areas |
| no `password` key | the injector sets its own; a foreign hash in the catalogue is noise |
| `dynSpawnTemplate: true`, exactly one unit, `skill: Client` | what makes it a dynamic-slot template at all |
| name is `<X> Template` or `<X> Template Red`, equals the group's own `name:` field and its route point's, and the unit is `<name> #01` | the warehouses step references templates **by name** |
| blue country is `CJTF Blue`, red country is `CJTF Red` | the catalogue's own convention, not enforced anywhere today |
| the set of blue types equals the set of red types | the mirror is the catalogue's promise; ticket 05 has to hold it |
| `groupId` and `unitId` unique across the file | duplicates are a DCS load failure, and the injector does not renumber |

Then fix the two blemishes so it passes.

## Definition of Done

- The test fails on the catalogue before the two blemishes are fixed, naming them.
- It passes after, and is the thing that verifies tickets 05 and 06 rather than a read-through.
- It states the expected template count as a **floor**, not an equality, so adding a template later is
  not a test edit.

## Note, not in scope

The injector does not renumber `groupId` / `unitId` on injection — `mission_tools.group_insertion`
does it for the MCP path, `aircrafts_injector` does not. The catalogue's ids (145–520 / 18–605) can
therefore collide with the target mission's. That is pre-existing, it is not what this lot is about,
and the uniqueness assertion above only covers collisions **inside** the catalogue.
