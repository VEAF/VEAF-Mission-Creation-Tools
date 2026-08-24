# FIX-DOC-HIDE-NAMES-DEFAULT — the documented default was the opposite of the code's

Status: ✅ done — shipped in 6.15.34

Found on 2026-08-24 by a question, not by a test: *"comment on désactive le renommage automatique des
groupes dans les combat zones (qui donne des noms comme `SA-15 [r]-Hydra Unit#10230`) ? lien vers la
doc ?"*

## The defect

`doc/LUA_API_REFERENCE.md` and its English twin both listed:

```lua
veaf.HideNamesFromSpawnedGroups = false
```

`veaf.lua:41` sets it to **true**.

The flag replaces a spawned group's combat zone and unit type with an invented military name, so a group
comes out as `[r]-Hydra Unit#10230` instead of `<zone> [r] <real name>#<id>`. It exists so a player
cannot read a zone's contents off the F10 map before going anywhere near it — a deliberate feature,
documented as being off.

## Two smaller problems the question exposed

- **The flag was not in `mission.yaml`.** It was reachable only through the `module_settings:` migration
  hatch, so the supported way to set a documented feature was an escape valve meant for v5 migration.
- **It was documented only in the API reference**, which is where someone goes to look up a function
  signature — not where a mission maker looks when he wants to know why his groups are being renamed.

## What shipped

- `mission.hide_names_from_spawned_groups`, emitted **only when actually given**, the way
  `SecurityDisabled` and `DynamicSpawn` are. Silence leaves `veaf.lua`'s own default and lets a
  `module_settings:` line survive — the lesson of
  [`FIX-MODULE-SETTINGS-OVERWRITTEN`](../FIX-MODULE-SETTINGS-OVERWRITTEN/PRD.md).
- The default corrected in both reference pages.
- A `## Group naming` section on the combat-zone page, both languages, saying what each part of the name
  is and which parts are configurable: the coalition tag and the `#<id>` stay either way, since DCS
  requires unique group names.
- `test_documented_lua_defaults.py`, comparing every documented default against the code.

## Why the test is the durable part

Nothing compared the documentation to the code, and nothing could have: each value was right in its own
file. Same shape as the backlog consistency gate — two sources that each agree with a third, and not with
each other.

Scoped to stay trustworthy rather than noisy: booleans and numbers only, inside fenced Lua blocks, and a
constant the scripts do not assign at top level is skipped rather than failed, since documentation
legitimately describes fields set at runtime. It also checks FR and EN document the same values, because
a value corrected in one and not the other is the next version of this bug.

Verified by re-introducing the wrong default and watching the test name it with both values.

## Definition of done

- [x] The documented default matches the code, in both languages
- [x] The flag is settable from `mission.yaml`, without overwriting a `module_settings:` line
- [x] Documented where the question gets asked, not only in the API reference
- [x] A test that fails when documentation and code disagree, proven against the real defect
