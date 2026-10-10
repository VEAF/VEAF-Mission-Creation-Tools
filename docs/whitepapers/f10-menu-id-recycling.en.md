# DCS: when an F10 menu left open fires the wrong command

*A VEAF whitepaper for DCS World mission script authors. It describes a behaviour of the `missionCommands` API, measured in game, and how to build an F10 menu that withstands it, with VEAF Mission Creation Tools (VMCT) and CTLD as examples.*
*Written on 2026-10-10 from the measurements of 2026-10-09.*
*Version française : [f10-menu-id-recycling.fr.md](f10-menu-id-recycling.fr.md).*

## Summary

**DCS tracks each F10 menu entry by an internal id, gives the id of a removed entry to the next entry created, and does not refresh an F10 screen that stays open.**
When a script rebuilds a menu while a player reads it, the player's click goes to whichever entry inherited the id, that is, another command.
These ids are one pool for the whole server: a stale click can even fire another group's command.

Delaying the rebuild does not protect, since the stale screen outlives the delay.
What protects is building the menu differently:

1. **render by difference**: never remove nor recreate an entry that did not change;
2. **park every freed id**: right after each removal, create an inert command for a group nobody can hold, which absorbs the id;
3. **never move an entry**, which amounts to removing and recreating it; in particular, keep pages stable in a paginated menu.

VMCT and CTLD have applied this pattern since 2026-10-09.

## 1. The F10 menu as a script sees it

A mission script builds the F10 menu with the `missionCommands` API:

- `addSubMenu`, `addSubMenuForCoalition`, `addSubMenuForGroup` create a submenu, with no callback;
- `addCommand`, `addCommandForCoalition`, `addCommandForGroup` create a command, which calls its function when the player selects it;
- `removeItem`, `removeItemForCoalition`, `removeItemForGroup` remove an entry and everything it holds.

Each creation function returns a path, to be passed later as a parent or to `removeItem`.

Two properties of the API matter for what follows:

- **DCS does not tell the script when a player opens the menu or navigates in it.** Only selecting a command runs code. A script therefore never knows who has a menu on screen.
- **There is no function to modify an entry.** Changing a command's label, function or parameters means removing it and creating another one.

Many scripts draw the simplest conclusion: on every state change, remove the whole menu and rebuild it.
That is precisely what triggers the defect.

## 2. The symptom

In multiplayer, a player opens F10 and goes down into a submenu.
While they read, the script rebuilds the menus, because another player just joined or a zone changed state.
The player's screen does not move.
They click, and another command fires.

On the VEAF servers the defect was reported in CTLD, for instance a red smoke fired instead of a troop embark, and less often in the VEAF menus.
It is intermittent, since a rebuild has to fall between opening the menu and clicking, and hard to reproduce, since the player does not know when the script rebuilds.

## 3. What DCS does, measured

### 3.1 The setup

To measure DCS itself, without any tool's code, the test uses nothing but `missionCommands`:

- a `TEST MENU > Liste` menu holding four commands A, B, C, D, each writing its own label on screen and to `dcs.log`;
- the change is applied from outside the mission, through a Lua console hook, while the player keeps `Liste` open;
- DCS in single player, **mission restarted before each test**, mouse clicks.

A **control** with no change at all (click B → B) checks that the setup itself distorts nothing.

The install script, loaded into any mission:

```lua
RT = { gen = 0, cmds = {} }
function RT.click(p)
  env.info("RADIOTEST click " .. p.label .. " gen " .. p.gen)
  trigger.action.outText("CLIC RECU : " .. p.label .. " (generation " .. p.gen .. ")", 20)
end
function RT.add(label, path)
  return missionCommands.addCommand(label, path, RT.click, { label = label, gen = RT.gen })
end
function RT.fillList(items)
  RT.gen = RT.gen + 1
  RT.cmds = {}
  for _, l in ipairs(items) do RT.cmds[#RT.cmds + 1] = RT.add(l, RT.list) end
end
RT.root = missionCommands.addSubMenu("TEST MENU")
RT.list = missionCommands.addSubMenu("Liste", RT.root)
RT.fillList({ "A", "B", "C", "D" })
```

Test 1, applied while the player keeps `Liste` open, before clicking B:

```lua
for _, c in ipairs(RT.cmds) do missionCommands.removeItem(c) end
RT.fillList({ "A", "B", "C", "D" })
```

Test 9, before clicking B (9a) or A (9b):

```lua
missionCommands.removeItem(RT.cmds[1])
RT.cmds[1] = RT.add("E", RT.list)
```

### 3.2 Results

| # | Change while the list is on screen | Clicked | Fired |
|---|---|---|---|
| control | none | B | B ✅ |
| 1 | remove A, B, C, D, then add them again, identical | B | **C** ❌ |
| 7 | remove A, then add X and Y elsewhere; menu reopened fresh | X, Y | X, Y ✅ |
| 9a | remove A, then add E | B | B ✅ |
| 9b | remove A, then add E | A | **E** ❌ |
| P2c | the same in a group menu (`ForGroup`) | A | **E** ❌ |
| P1 | global menu: remove A, add a command for a group that does not exist, then add E | A | the inert command ✅ |
| P2 | group menu: same sequence as P1 | A | the inert command ✅ |

A first, less controlled series points the same way:

| Change while the list is on screen | Clicked | Fired |
|---|---|---|
| remove and recreate the whole `TEST MENU` | B | **"Test 2", an entry of another menu** ❌ |
| add E at the end of the list | B | B ✅ |
| remove D, after B | B | B ✅ |
| remove A, before B | B | B ✅ |
| remove A, nothing created afterwards | A | nothing ✅ |

The "remove A, before B" case rules out the most natural hypothesis: had DCS resolved the click by its position in the list, F2 would have landed on C.
It landed on B.

### 3.3 The model that explains every measurement

DCS gives each entry an internal id.
The player's F10 screen keeps the ids of the entries it shows, and is not refreshed while it stays open.
When an entry is removed, its id is freed, and **the next entry created takes it**.

The observed order of reuse is consistent with "last freed, first reused".
It explains test 1 exactly:

| Entry | Id before | Freed | Id after recreation |
|---|---|---|---|
| A | 1 | 1st | 4 |
| B | 2 | 2nd | 3 |
| C | 3 | 3rd | **2** |
| D | 4 | 4th | 1 |

The player's screen still maps id 2 to B; id 2 now belongs to C; the click on B fires C.
This order remains an inference: only its effects were measured.

Tests P1 and P2 establish a more serious fact: **the ids are one pool for the whole server.**
The id of a global menu entry went to a command created for another group.
A stale click can therefore fire another group's command, a restricted one included, which then runs with that group's parameters.

### 3.4 What is safe and what is not

| Operation while a player reads the menu | Effect on their click |
|---|---|
| touch nothing | right |
| add an entry | right, for every entry on screen |
| remove an entry, create nothing afterwards | right for the others; nothing for the removed entry |
| remove an entry, then create another one, anywhere on the server | **a click on the removed entry fires the new one** |
| rebuild the whole menu, even identically | **any click can go elsewhere** |
| reopen the menu after the change | always right |

### 3.5 A measurement trap

A first series of tests, stacked in the same menu without restarting the mission, produced an alarming result: a freshly reopened menu seemed to fire the wrong command.
Redone on a restarted mission, the test did not reproduce.
The earlier manipulations had left the id pool in a state the test did not control.
**Any measurement of this behaviour runs on a restarted mission, one test at a time**, with a control.

## 4. Why the usual remedies fail

| Remedy | Why it is not enough |
|---|---|
| Rebuild the menu in the same order | Test 1 rebuilds identically and fires C instead of B: position is not what counts. |
| Delay the rebuild: empty the menu now, rebuild it a few seconds later | A click during the delay does nothing, but the player's screen stays frozen past the delay; a click after the rebuild falls into the defect again. The window narrows, it does not close. |
| Group close rebuilds (debounce) | Useful for the number of calls, no effect on the mechanism: every rebuild reassigns every id. |
| Rebuild only the menu of the group concerned | The id pool is shared by the whole server: ids freed by one group are taken by another group's creations. |

CTLD had adopted the second remedy in September 2026, and players kept reporting wrong commands: that is what triggered the measurement.

## 5. The generic fix

### 5.1 Render by difference

The script remembers what it rendered the previous time.
On every refresh, it compares the wanted menu with the rendered one, creates what appeared, removes what disappeared, and leaves the rest alone.

Each entry gets a **stable key**, which must identify the same entry from one render to the next:

- its parent's key;
- its audience: everyone, a coalition or a group;
- its kind: submenu or command;
- its label, suffixed with `#2`, `#3`… when two entries share a label under the same parent.

An entry with the same key is reused as is when its function and parameters did not change: no DCS call.
Otherwise it is removed and created again.
Entries that disappeared are removed **children before their parent**, so that each freed id is parked one by one.

Three traps lie in the comparison:

- **A function recreated on every refresh never equals the previous one.** A closure built in the render loop makes every command recreated, every time. Use stable functions, or a single dispatcher that receives a key and finds the right action at click time.
- **A DCS object never equals itself from one call to the next.** `Unit.getByName` returns a new table on every call. Two DCS objects compare by their class and their `id_`.
- **A rebuilt parameter table is not the same table.** Compare it field by field, or pass plain values.

### 5.2 Park every freed id

Rendering by difference fixes the full rebuild, not the replacement: one entry disappearing while another appears (a zone's "Activate" turning into "Deactivate") is enough for the id to be inherited, test 9b.

The remedy: **right after each removal, and before any other creation, create an inert command for a group nobody can hold.**

```lua
missionCommands.removeItem(path)
missionCommands.addCommandForGroup(999999, "parked " .. n, nil, onParkedClick)
```

The command takes the freed id; nobody sees it, since no player belongs to group 999999; a stale click on the removed entry lands on it and does nothing.
Since the pool is shared by the whole server, a group command parks the id of a global entry as well as that of a group entry: tests P1 and P2 measured it.
For a coalition entry it is very likely but not measured.

The cost: one invisible command per removal, never removed, so they pile up for the whole mission.
It was measured on 2026-10-10, in single player, by parking up to 50,000 commands in a running mission:

| Parked commands | Creation time | DCS private memory | Frames per second | 500 ordinary adds + 500 removes | F10 menu |
|---|---|---|---|---|---|
| 0 | | 29,465 MB | 30.0 | 0.096 s | instant |
| 1,000 | 0.05 s | 29,373 MB | 30.0 | 0.029 s | instant |
| 10,000 | 0.02 s | 29,356 MB | 30.0 | 0.025 s | instant |
| 50,000 | 0.13 s | 29,443 MB | 30.0 | 0.065 s | instant |

Nothing is measurable: neither DCS memory, whose noise is about 100 MB, so under 2 KB per command; nor the frame rate; nor the speed of ordinary operations, which do not slow down as the menu grows.
The mission's Lua memory went from 46 to 66 MB, at most 0.4 KB per command, garbage included.
A long mission should park a few thousand ids at most: that is an estimate, not a measurement, but it stays ten times under the level tested.
There is no reason to bound the pool.

### 5.3 Entry order

DCS always adds a new entry at the end of its menu.
Inserting an entry in the middle of a sorted list therefore means recreating every entry after it.
Parking made that safe: a stale click on a recreated entry does nothing, at worst.

Two choices remain, depending on what the menu promises the player:

| Choice | For | Against |
|---|---|---|
| Append at the end of the list | no existing entry moves, the click stays right | the list is sorted on first render only |
| Recreate the entries after the insertion | the declared order holds | those entries go inert for a stale screen |

### 5.4 Paginated menus

DCS truncates a submenu past ten entries, hence pagination through a "Next page" command.
If each entry's page is recomputed on every render, an entry added at the top shifts all the following ones, and every entry that changes page is removed and created again.
A new entry can even land after "Next page".

The remedy is to **keep pages stable**:

- on first render, distribute the entries in order;
- afterwards, an entry already shown keeps its page, and a new entry goes to the last page;
- an emptied page disappears, the following ones move up;
- a menu falling back under one page's size returns to a single page.

### 5.5 A skeleton

This skeleton applies sections 5.1 and 5.2 to a global menu.
For a group or coalition menu, use the `ForGroup` or `ForCoalition` variants and add the audience to the key.
It handles neither duplicate labels, nor table parameters, nor pagination.

```lua
-- StableMenu: renders an F10 menu by difference and parks every freed id.
-- Global menu only; for a group menu, use the ForGroup variants and add the group id to the key.
local PARKING_GROUP_ID = 999999 -- a group id no player can hold

local StableMenu = {}
StableMenu.__index = StableMenu

function StableMenu.new()
  return setmetatable({ rendered = {}, parked = 0 }, StableMenu)
end

local function onParkedClick()
  env.info("click on a removed F10 entry, ignored")
end

-- Removes one entry, then parks the id it freed before anything else can take it.
function StableMenu:_remove(entry)
  missionCommands.removeItem(entry.path)
  self.rendered[entry.key] = nil
  self.parked = self.parked + 1
  missionCommands.addCommandForGroup(PARKING_GROUP_ID, "parked " .. self.parked, nil, onParkedClick)
end

-- tree: a list of nodes, each { label = ..., children = {...} } for a submenu
-- or { label = ..., fn = ..., arg = ... } for a command.
function StableMenu:render(tree)
  local seen = {}
  local function walk(nodes, parentKey, parentPath, depth)
    for _, node in ipairs(nodes) do
      local kind = node.children and "menu" or "command"
      local key = parentKey .. "/" .. kind .. ":" .. node.label
      seen[key] = true
      local entry = self.rendered[key]
      local unchanged = entry and (kind == "menu" or (entry.fn == node.fn and entry.arg == node.arg))
      if not unchanged then
        if entry then
          self:_remove(entry) -- a command whose callback or argument changed
        end
        local path
        if kind == "menu" then
          path = missionCommands.addSubMenu(node.label, parentPath)
        else
          path = missionCommands.addCommand(node.label, parentPath, node.fn, node.arg)
        end
        entry = { key = key, path = path, fn = node.fn, arg = node.arg, depth = depth }
        self.rendered[key] = entry
      end
      if node.children then
        walk(node.children, key, entry.path, depth + 1)
      end
    end
  end
  walk(tree, "", nil, 0)

  -- Remove what is no longer rendered, children before their parent: each removal frees one id.
  local gone = {}
  for key, entry in pairs(self.rendered) do
    if not seen[key] then
      gone[#gone + 1] = entry
    end
  end
  table.sort(gone, function(a, b)
    return a.depth > b.depth
  end)
  for _, entry in ipairs(gone) do
    self:_remove(entry)
  end
end

return StableMenu
```

The skeleton was checked under Lua 5.1 against a `missionCommands` double that recycles ids as measured, not in game:

| Case | Result |
|---|---|
| naive rebuild, stale click on B (control of the double) | C, as in game |
| identical render | 0 DCS calls, stale click on B → B |
| A replaced by E | stale click on B → B; on A → inert command |
| `Liste` submenu removed | stale click on E → inert command |

Removing the parking line, or disabling entry reuse, makes three of these checks fail each.

## 6. Examples

### 6.1 VEAF Mission Creation Tools

VMCT builds the VEAF menu through `veafRadio.RadioMenuBuilder` ([veafRadio.lua](../../src/scripts/veaf/veafRadio.lua)).
Before the fix, `rebuild()` removed the VEAF root and recreated the whole tree, for every group, whenever a human player joined and on some thirty other events: combat zones, CAS missions, transport, assets, spawn.

Pull request [VEAF/VEAF-Mission-Creation-Tools#1113](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/1113) applies the pattern:

- **Render by difference**: every entry of the VEAF menu is created through `RadioMenuBuilder:_render`, with the key of section 5.1. The parameter comparison (`_sameValue`) recognises two identical DCS objects by their `id_`. A player joining now adds only their group's commands, and a refresh with nothing changed makes no DCS call at all.
- **Parking**: `RadioMenuBuilder:_removeEntry` creates, after each removal, an inert command for `veafRadio.PARKING_GROUP_ID = 999999`.
- **Order**: append at the end of the list. VEAF menus have no declared order, only an alphabetical sort on first render.
- **Stable pages**: [ADR 0013](../adr/0013-radio-menu-pagination.md) was amended with the rules of section 5.4.

Checked in game, the code hot-loaded into a demo mission:

| Check | While the player reads a submenu | Clicked | Fired |
|---|---|---|---|
| addition elsewhere | an entry is added to the VEAF menu | B | **B** ✅ |
| replacement | A is removed and E added | A | **nothing** ✅ |
| addition to a paginated menu, stable pages | an entry is added to the root menu | B | **B** ✅, one DCS call instead of 40 |

The in-game check is what revealed the pagination problem: before stable pages, a single addition at the root moved the following entries to another page, hence recreated them, 40 DCS calls in all, and the new entry landed after "Next page".

### 6.2 CTLD

CTLD rebuilt a group's menu on every refresh, at once or 4 seconds later under its ADR 0015.
Issue [VEAF/CTLD#257](https://github.com/VEAF/CTLD/issues/257) brought it the measurement, and pull request [VEAF/CTLD#261](https://github.com/VEAF/CTLD/pull/261) the pattern; its ADR 0027 supersedes ADR 0015.

The principle is the same, but three choices differ from VMCT, because the constraints differ:

- **A single dispatcher** (`ctld.MenuManager._dispatch`, argument `{ groupId, key }`): CTLD creates a new function on every refresh and cannot compare callbacks; the dispatcher finds the command at click time. That is the first trap of section 5.1.
- **The declared order holds**: CTLD menus have a defined order, and entries disabled then enabled again must return to their place. An insertion recreates the entries after it, which parking makes safe.
- **The 4-second delay is gone**, replaced by a 0.15-second debounce.

CTLD also wrote a `missionCommands` double that recycles ids as measured, on which its test suite reproduces "clicked B, fired C".
As of 2026-10-10, the in-game check of a CTLD mission is still to do.

## 7. Checklist for an F10 menu

1. Never remove and recreate a whole menu, neither at once nor after a delay.
2. Give each entry a stable key: parent, audience, kind, label.
3. Reuse an entry whose function and parameters did not change; compare DCS objects by `id_`, and do not recreate functions on every render.
4. Remove the entries that disappeared, children before their parent.
5. After each removal, park the freed id on an inert command for a nonexistent group, before any other creation.
6. Choose between appending at the end and recreating the entries that follow; never move an entry without parking.
7. In a paginated menu, keep pages stable.
8. To verify, measure on a restarted mission, one test at a time, with a control.

## 8. Limits and open questions

- **The measurements were made in single player.** The reports came from multiplayer and agree, but no measurement was made on a dedicated server.
- **VMCT has an option to measure in multiplayer**: `RADIO.menu_stats: true` in `mission.yaml` writes to `dcs.log`, on every refresh, the menu's size and what changed. It is how the previous point gets measured on a real mission.
- **Coalition menus were not measured.** The single id pool makes the same behaviour very likely.
- **The exact order of reuse is inferred**, not measured directly. The fix does not depend on that order.
- **Inert commands pile up** with no bound during a mission. Up to 50,000, their cost is not measurable in single player (section 5.2); in multiplayer, what the server sends clients for a group with no members was not measured.

## References

- The trap, with its measurements: `f10-menu-entry-id-is-recycled` in [known-limitations.yaml](../../src/python/veaf-tools/veaf_libs/data/known-limitations.yaml), generated page [dcs-runtime-traps.md](../agents/dcs-runtime-traps.md).
- VMCT: pull request [VEAF/VEAF-Mission-Creation-Tools#1113](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/1113); `RadioMenuBuilder:rebuild`, `_render` and `_removeEntry` in [veafRadio.lua](../../src/scripts/veaf/veafRadio.lua); tests `TestVeafRadioIncrementalRender` in [test_veafRadio.lua](../../test/lua/test_veafRadio.lua); pagination, [ADR 0013](../adr/0013-radio-menu-pagination.md).
- CTLD: issue [VEAF/CTLD#257](https://github.com/VEAF/CTLD/issues/257), pull request [VEAF/CTLD#261](https://github.com/VEAF/CTLD/pull/261).
- A neighbouring thread on the DCS forum, not directly related: [missionCommands.removeItem bug](https://forum.dcs.world/topic/96887-missioncommandsremoveitem-bug/).
