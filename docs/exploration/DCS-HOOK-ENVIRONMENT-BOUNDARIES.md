# DCS hook environment — what a `Scripts/Hooks/` script can and cannot reach

Measured against DCS 2.9 on 2026-08-01 (install at `C:\jeux\DCS World`), while investigating whether
VMCT could drive a live Mission Editor. The conclusion of that investigation is
[ADR 0017](../adr/0017-no-live-mission-editor-bridge.md); this note keeps the **facts**, which outlive
the decision.

Read this before writing anything that runs in a `Saved Games/DCS/Scripts/Hooks/` script, and before
trusting third-party claims about DCS's Lua environments — two widely repeated ones turned out false.

## 1. `onSimulationFrame` fires outside a mission

**The claim it refutes:** that hook-based tools are gated by a running sim and "die at the main menu".
[dcs-sms](https://github.com/nielsvaes/dcs-sms) states this as established fact about six comparable
tools (DCS-gRPC, Olympus, Witchcraft, DCSServerBot, Quaggles' Lua Connector, dcs_code_injector).

**What was measured:** a probe hook counting `onSimulationFrame` calls, launched with DCS going to the
main menu, then the Mission Editor, then a mission.

```
16:12:29  first onSimulationFrame tick
16:12:34  simframes=123          ← still at the main menu / in the editor
16:13:52  simframes=2305
16:13:56  onMissionLoadBegin     ← the mission only starts here
16:14:20  onSimulationStart
```

~28 Hz, 2305 ticks before any mission existed. The counter freezes during the blocking mission load
(2403 from 16:13:56 to 16:14:20), then resumes.

**Consequence:** anything a hook needs to poll — a socket, a file mailbox — keeps working with no
mission loaded. Verified end to end: with `dcs-fiddle-server.lua` enabled and DCS at the main menu,
`GET /<base64>?env=default` returned `alive: Lua 5.1`.

## 2. `onShowMainInterface` never fires

Registered through `DCS.setUserCallbacks` in two separate runs; never called once. The callbacks that
*did* fire, in order: `onMissionLoadBegin`, `onMissionLoadEnd`, `onSimulationStart`,
`onSimulationResume`, `onSimulationPause`, `onSimulationStop`. Do not use `onShowMainInterface` as a
"DCS is ready" anchor.

## 3. The hook environment is **not** the Mission Editor's Lua state

**The claim it refutes:** that the GUI hook environment and the editor share one Lua VM, so
`require('me_mission').mission` from a hook reaches the table the editor mutates. dcs-sms's design spec
asserts this; their shipped hook comments the opposite.

**What was measured**, with the editor open on a real mission (a theatre plus an A-10):

```
loaded_total=142
pl.me_mission   = table: 00000244A8C8FB28  keys=3
G.me_mission    = table: 00000244A8C8FB28  keys=3
pl.me_trigrules keys=3 | pl.me_route keys=3
G.mission = nil
→ no theatre-bearing table found
```

44 editor modules are *listed* in the hook's `package.loaded`, and every one holds exactly three keys:
`_M`, `_NAME`, `_PACKAGE`.

**Why — and this is the trap worth remembering.** These modules use Lua 5.1's `module('name')`, which
registers its table in `package.loaded` **before** the file body executes. When the body then fails,
the empty table stays behind: a phantom module that answers `require` successfully and contains
nothing. The failure is visible in the probe's own log:

```
me_modulesInfo.lua:21: module 'DcsWeb' not found
```

`DcsWeb` only exists in the editor's full environment. So the 9860 lines of `me_mission.lua` — where
`create()`, `fixWeather()`, `fixUnitsPos()` and the `mission` table live — never ran on the hook side.

**Consequence:** a non-empty `package.loaded[x]` from a hook proves nothing about `x` being usable.
Check for a symbol you actually need, not for the module's presence. And a search by *shape* (find the
table carrying a `theatre` field) beats a search by name when hunting for editor state.

## 4. `package.path` shadowing works — but not for the editor

`<DCS install>\Scripts\UserHooks.lua` overwrites `package.path` with the **user directory first**:

```lua
package.path = (lfs.writedir()..'Scripts\\?.lua;')
	.. '.\\Scripts\\?.lua;'
	...
Gui = require('dxgui')                        -- note: a global
local UpdateManager = require('UpdateManager')
Gui.AddUpdateCallback(UpdateManager.update)
```

So a file dropped at `Saved Games\DCS\Scripts\<Module>.lua` **replaces** the installed one for anything
required after that point. Verified: a replacement `UpdateManager.lua` did get loaded (once — so
`package.loaded` *is* shared between `UserHooks.lua` and the hooks environment).

`MissionEditor.lua:22` then overwrites `package.path` again, with install-relative entries only and
**no `lfs.writedir()`**. The editor's requires never look at the user directory. Shadowing therefore
cannot reach the editor; only writing into `<DCS>\MissionEditor\modules\` can.

## 5. `Gui.AddUpdateCallback` leads nowhere from a hook

The global `Gui` **is** visible from a hook and `Gui.AddUpdateCallback(fn)` accepts a function without
raising. It is simply never called — zero invocations at the menu, in the editor, and during a mission.
Same for `require('UpdateManager').add(fn)`, and same for the replacement `UpdateManager` of point 4:
loaded, never pumped, even though `UserHooks.lua` itself wires `Gui.AddUpdateCallback(UpdateManager.update)`.
Consistent with point 3 — that `Gui` is not the one rendering the editor.

Do not spend time here: point 1 gives a working tick for free.

## Two incidental notes

- **`UpdateManager.update` unsubscribes any updater returning `true`** (`if updater() then delete(updater) end`).
  A tick function must return `nil` or `false`.
- **ED leaks a global** in `Scripts/UpdateManager.lua`: `deleteUpdaters_` assigns `count` without
  `local`. Harmless, but it means `_G.count` is written on every deletion pass.

## Method note

The first probe coupled two measurements — "does anything tick?" and "is the mission table reachable?" —
by only probing the table from inside a tick. Zero ticks therefore yielded zero information about the
table, and worse, the probe's own `require('me_mission')` polluted `package.loaded` with the phantom
module it then reported on. Both were fixed in the second pass: a positive control
(`onSimulationFrame`), probes driven from callbacks rather than ticks, and **passive** inspection —
`rawget` on `package.loaded`, never a `require` of our own.

## Retest, 2026-08-09 — with the Mission Editor actually open

ADR 0017 names one question worth re-asking: *"does ED still overwrite `package.path` in
`MissionEditor.lua` without consulting `writedir`? If that ever changes, a non-invasive editor
mod becomes possible."* Measured again on David's machine, twice: DCS at the main menu, then DCS
with the **Mission Editor open**.

| Field | Main menu | Editor open |
|---|---|---|
| `package.path` entries | 40 | **40, byte-identical** |
| `Saved Games` in `package.path` | yes, **first entry** | yes, first entry |
| `me_mission` keys | — | **3** |
| `me_mission.theatre` | — | absent |
| `me_*` modules registered | — | 30 |

**ADR 0017 stands.** `me_mission` still holds exactly the three keys `module()` registers before a
file body runs — the husk described on 2026-08-01, unchanged with the editor genuinely open on
screen. The editor's Lua state is not reachable from a hook, so an editor mod still costs a module
under `<DCS>\MissionEditor\modules\` plus a patch to `MissionEditor.lua`, re-applied after every
DCS update.

### The trap this retest walked into first

The initial probe asked **the wrong question**, and it is worth recording because the mistake is
inviting. It measured `Saved Games` being present in `package.path` and was ready to conclude
"ED consults writedir, reopen the ADR" — reading `true` and calling it a result.

But that `package.path` belongs to the **hook** environment, which is not the editor's. ADR 0017
is about `MissionEditor.lua` overwriting `package.path` *inside the editor's own Lua state*, and a
hook cannot see that state at all — which is the very thing the ADR established. So the field was
answering a different question from the one being asked, and it happens to answer `true`.

The field that actually decides is `me_mission_keys`: it looks straight at whether the editor's
state is real or a husk. `package.path` from a hook can never settle it either way.

**Cost of finding out**: two probe runs. **Cost of not finding out**: a lot opened on a false
positive, against an undocumented GUI toolkit.
