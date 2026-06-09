# veafRadio — F10 Radio Menu Builder


**Module ID:** `RADIO` | **File:** `veafRadio.lua`

---

## Purpose

The F10 "Other" menu in DCS is the primary interface between players and VEAF scripts. `veafRadio` manages that entire menu tree: building it, refreshing it as human groups join and leave, and providing helpers that let other VEAF modules and mission makers add their own entries without worrying about DCS radio menu limits.

---

## Enable

```lua
veafRadio.initialize()
```

Optional parameters:

```lua
veafRadio.initialize(
  skipHelpMenus,   -- bool: omit "Help" entries from built-in menus (default false)
  dontCreateMenus  -- bool: suppress all DCS radio menu creation (default false)
)
```

After all modules are initialised, call:

```lua
veafRadio.refreshRadioMenu()
```

This rebuilds the entire F10 tree. It is safe to call multiple times — it debounces internally (1-second delay).

---

## Configuration (`mission.yaml`)

```yaml
modules:
  RADIO:
    enabled: true          # default: true
    logLevel: info        # optional log level override
    init:
      help_menus: true    # show built-in "Help" entries in radio menus (default: true)
```

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `enable` | boolean | `true` | No | Enable or disable the module |
| `logLevel` | string | *(global)* | No | Per-module log level override |
| `init.help_menus` | boolean | `true` | No | Show built-in "Help" entries in the generated radio menus |

### Minimal example

```yaml
modules:
  RADIO:
    enabled: true
```

---

## Creating a custom menu

Use `veafRadio.createUserMenu()` to build a structured menu tree from a simple Lua table, using three helpers:

```lua
veafRadio.createUserMenu(
  veafRadio.mainmenu(
    veafRadio.menu("QRA Management",
      veafRadio.command("Start QRA North", veafQraManager.startQra, { name = "QRA-NORTH" }),
      veafRadio.command("Stop QRA North",  veafQraManager.stopQra,  { name = "QRA-NORTH" }),
      veafRadio.command("Status",          veafQraManager.getStatus,{ name = "QRA-NORTH" })
    ),
    veafRadio.menu("Flags",
      veafRadio.command("Set Flag 10",   trigger.action.setUserFlag, { "FLAG-10", true }),
      veafRadio.command("Clear Flag 10", trigger.action.setUserFlag, { "FLAG-10", false })
    )
  )
)
```

### Helpers

| Helper | Signature | Returns |
|--------|-----------|---------|
| `mainmenu(...)` | Variable args of `menu()` or `command()` items | Flat array for `createUserMenu()` |
| `menu(name, ...)` | Name + variable args of nested items | A submenu node |
| `command(name, fn, params)` | Name + function + parameter table | A command node |

### Group-specific menus

Pass a `groupId` as the second argument to `createUserMenu()` — the menu will only appear for that group:

```lua
local playerGroupId = 101
veafRadio.createUserMenu(
  veafRadio.mainmenu(
    veafRadio.command("Request tanker", myMission.requestTanker, { groupId = playerGroupId })
  ),
  playerGroupId
)
```

---

## Usage constants

When adding commands via the low-level API, the `usage` parameter controls who sees the entry:

| Constant | Value | Behaviour |
|----------|-------|-----------|
| `veafRadio.USAGE_ForAll` | `0` | Single entry visible to all players |
| `veafRadio.USAGE_ForGroup` | `1` | One entry per connected human group; the unit name is appended to params automatically |
| `veafRadio.USAGE_ForUnit` | `2` | One entry per connected human pilot; entry title is prefixed with the pilot's callsign |

`USAGE_ForGroup` is ideal for commands that should respond differently per flight (e.g. "Request support for my flight"). `USAGE_ForUnit` is for individual pilot interactions.

---

## Low-level API

For finer control, build the menu tree directly:

```lua
-- Add a top-level submenu under the VEAF root
local missionMenu = veafRadio.addMenu("Mission Control")

-- Add a submenu inside it
local qraMenu = veafRadio.addSubMenu("QRA", missionMenu)

-- Add a command (ForAll)
veafRadio.addCommandToSubmenu(
  "Start QRA North",
  qraMenu,
  veafQraManager.startQra,
  { name = "QRA-NORTH" },
  veafRadio.USAGE_ForAll
)

-- Add a secured command (requires /secu login)
veafRadio.addSecuredCommandToSubmenu(
  "Emergency stop all QRA",
  missionMenu,
  veafQraManager.stopAll,
  {},
  veafRadio.USAGE_ForAll
)

-- Trigger a rebuild
veafRadio.refreshRadioMenu()
```

### Paginated menus

When a submenu has more than ~9 entries (DCS limit), use paginated helpers:

```lua
veafRadio.addPaginatedRadioMenu(
  "All Zones",          -- menu title
  parentMenu,           -- parent menu node
  veafRadio.addCommandToSubmenu,
  myZonesList,          -- table of elements
  "name",               -- attribute used as the entry title
  "sortKey"             -- attribute used for sorting (optional)
)
```

Pages of 10 are created automatically with a "Next page" submenu.

---

## Examples

### QRA start/stop from a custom menu

```lua
local controlMenu = veafRadio.addMenu("Mission Control")

local qraMenu = veafRadio.addSubMenu("Quick Reaction Alerts", controlMenu)

veafRadio.addCommandToSubmenu("Start QRA North",
  qraMenu, myNorthQRA.start, {}, veafRadio.USAGE_ForAll)
veafRadio.addCommandToSubmenu("Stop QRA North",
  qraMenu, myNorthQRA.stop,  {}, veafRadio.USAGE_ForAll)

veafRadio.addCommandToSubmenu("Start QRA South",
  qraMenu, mySouthQRA.start, {}, veafRadio.USAGE_ForAll)
veafRadio.addCommandToSubmenu("Stop QRA South",
  qraMenu, mySouthQRA.stop,  {}, veafRadio.USAGE_ForAll)

veafRadio.refreshRadioMenu()
```

### Destroy a group by name

```lua
local function _destroyGroup(name)
    local names = type(name) == "string" and {name} or name
    for _, n in pairs(names) do
        local g = Group.getByName(n)
        if g then
            g:destroy()
            trigger.action.outText(string.format("Group %s destroyed", n), 10)
        end
    end
end

veafRadio.createUserMenu(
    veafRadio.mainmenu(
        veafRadio.menu("Adversaries",
            veafRadio.command("CAP Maykop",   _destroyGroup, "CAP-Maykop"),
            veafRadio.command("SA-6 Minvody", _destroyGroup, "SA6-Minvody")
        )
    )
)
```

### Flag-based mission triggers

```lua
veafRadio.createUserMenu(
  veafRadio.mainmenu(
    veafRadio.menu("Phase control",
      veafRadio.command("Begin Phase 2", trigger.action.setUserFlag, { "PHASE2", true }),
      veafRadio.command("Begin Phase 3", trigger.action.setUserFlag, { "PHASE3", true }),
      veafRadio.command("End mission",   trigger.action.setUserFlag, { "MISSIONEND", true })
    )
  )
)
```

### Per-group command (ForGroup)

A "Request close air support" entry that appears once per connected flight, automatically passing that group's unit name:

```lua
veafRadio.addCommandToSubmenu(
  "Request CAS",
  supportMenu,
  myCasDispatch,      -- receives { originalParams, unitName } at runtime
  {},
  veafRadio.USAGE_ForGroup
)
```

---

## See Also

- [veafSecurity](veafSecurity.md) — securing commands with `/secu login`
- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafRadio` API
