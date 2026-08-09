# 04 — Assert VEAF through the mission bridge, not the hook

Status: ⬜ ready
Type: fix

## What the 2026-08-09 run measured

Run against a live DCS with a VEAF mission in flight, the harness reported:

```
[FAIL] veaf-loaded: returned 'veaf-absent'
[FAIL] findspawnpoint-exists: returned 'veaf-absent'
```

while three `Disposition` checks passed and `coalition-scoped-submenu-accepted` returned
`created`. `dcs.log` showed the scripts loading normally (`STATIC VEAF scripts loading`, then
`VEAF-GROUNDAI`, `VEAF-COMMANDS`, `VEAF-RADIO` initialising). So `veaf-absent` was **not** a
mission problem.

The pattern explains itself once you sort the globals by who creates them:

| Global | Created by | Seen by the hook route |
|---|---|---|
| `env`, `Disposition` | DCS itself | **yes** |
| `veaf`, `veafRadio`, `veafSecurity` | the mission's scripts | **no** |

The route reaches a scripting state that never ran the mission's scripts. `dcs.log` agrees:
`Error while executing string in scripting` for probes as trivial as `return true`.

## The route that does work, proven the same day

`dcs-bridge.lua` is injected **into the mission** at build time (it is the trigger whose index
shift VMR-005 fixed), so it lives in the state where `veaf` exists. With `dcs-serve` running:

```
capabilities -> veaf version 6.13.2, mist 4.5.128-DYNSLOTS-02-VEAF
exec_lua "return type(veaf) .. '|' .. tostring(veaf.Id) .. '|radio=' .. type(veafRadio)"
      -> "table|VEAF|radio=table|security=table"
```

**`veaf` is reachable.** The harness's limitation is a transport choice, not a property of DCS.

## Why the harness picked the hook, and where that generalised too far

`dcs_fiddle_client`'s own docstring gets it right: `onSimulationFrame` answers **with no mission
loaded**, and a bridge living inside a mission cannot be what loads that mission. Sound — *for the
load step*. But the module calls itself "the harness's single transport", and the argument for one
step became the rule for all of them.

The two needs have different constraints:

| Need | When | Transport |
|---|---|---|
| locate, launch, load, quit | before / outside a mission | **fiddle hook** — the only one that answers |
| assert VEAF behaviour | mission in flight | **dcs-bridge** — the only one that sees `veaf` |

## Tasks

- [ ] Split the transport: keep the hook for driving DCS, route every `veaf-*` assertion through
      the mission bridge.
- [ ] Fix the sentinel that hid this. `route dostring_in-scripting: reaches the scripting state`
      concludes "reached" because `env` is a table — and `env` exists in *every* scripting state,
      loaded or bare. It must test a **VEAF** global instead. This is the **fourth** truthy-failure
      in this lot after the sentinel strings, the submenu constant and the Lua-error-shaped-as-result.
- [ ] Make the bridge a documented prerequisite of a VEAF assertion run, and fail with a message
      naming `dcs-serve` when it is absent rather than reporting `veaf-absent`.

## A second finding from the same run: the test mission must be built, not stored

`findspawnpoint-exists` also returned `veaf-absent`, and that one is **not** the transport:
`exec_lua` through the working route confirms `veaf.findSpawnPoint` is genuinely nil in that
mission. The reason is the mission's age — it carries veaf **6.13.2**, built 2026-08-02, and
`findSpawnPoint` first appears on **2026-08-05** (`4f15f228`, FEAT-SCENERY-AWARE-SPAWN).

So a stored `.miz` silently tests whatever VEAF version it was built with. The lot's existing
"committed test mission" item therefore needs one more clause: the mission is **rebuilt from
source before the run**, or the harness asserts against a snapshot of the past and calls today's
code broken.
