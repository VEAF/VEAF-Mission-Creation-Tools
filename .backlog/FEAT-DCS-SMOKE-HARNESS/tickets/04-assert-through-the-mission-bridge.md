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

### Re-measured 2026-08-15, on a different mission, same verdict

Run again against `TestMenuFR-fixed.miz`: same two failures, same four passes. Probing the route's
globals directly adds three details that close the door on any remaining doubt:

- `env.mission.theatre` returns `Caucasus` — so the route **is** in a state that can read the loaded
  mission, which is what made `env`-based detection look convincing;
- `veaf` is `nil`, **and so is `mist`** — not one of the **1683** globals in that state contains the
  string "veaf", in any case;
- `missionCommands`, `trigger` and `coalition` are all tables, which is why the DCS-native checks keep
  passing and why 4/6 reads as "mostly working".

Nothing here is new — the ticket had it right on 2026-08-09. It is recorded because a second
independent measurement on another mission removes "maybe that run was odd" as an explanation, and
because **running the harness again cannot produce anything else until this ticket lands**. That is the
useful conclusion for whoever is tempted to spend a DCS session on it.

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

## The transport was exercised end to end on 2026-08-09, after this ticket was written

A mission built from current sources (`veaf.BuildVersion = 6.13.47+4a6d7cbc` — the build stamp
identifies the commit, so there is no doubt about what ran) with `dcs_bridge.enabled: true`, then
driven entirely over that bridge. What it answered, none of which the hook transport can reach:

| Asserted live | Result |
|---------------|--------|
| `veaf`, `veafSecurity`, `veafRemote` loaded | tables, not `veaf-absent` |
| `veaf.findSpawnPoint` over open water | `nil` — refuses rather than inventing a point |
| `findSpawnPoint` with an absurd clearance in a 100 m radius | 95 m — tier 2 degrades, **radius still honoured** |
| group of a level-10 and a level-1 pilot | acts at **1**, the minimum |
| the level-10 occupant elevates | 10 |
| the level-1 occupant elevates | **1** — cannot borrow the other's rights |
| a pilot with no level elevates | refused, group falls back to its minimum |
| an elevation past its deadline | dropped from the table, level falls back |

So the transport question is settled by measurement, not argument: `dcs_bridge` reaches the state
the mission's scripts run in, and everything this lot wants to assert is reachable from it.

### One trap, paid for during the run

A probe crashed midway, **leaving a stubbed `getGroupOccupantUnitNames` behind**. The next probe
saved-and-restored that stub believing it was the real function, and the fallback silently read 1
instead of 0. The result looked plausible, which is exactly why it was nearly missed — the same
*"it came back is not it worked"* mistake this lot has now made four times.

For the harness this is a requirement, not an anecdote: **a check that mutates mission state must
restore from the source, never from what it found there**, because what it found may be the wreckage
of an earlier failed check. A crashed probe leaves the state dirty for every probe after it.
