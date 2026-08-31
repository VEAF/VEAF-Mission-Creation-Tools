# FIX-CSAR-INIT-GUARD — CSAR's re-initialisation guard cannot fire, and its opt-out is read by nobody

Status: ✅ done — 2026-08-31

Origin: noticed 2026-08-31 while reading `csar.initialize` for `REFACTOR-CSAR-WITHOUT-MIST`'s in-game
check. Not observed failing — see *What is actually at risk*, which is the honest part of this.

## Two flags, both dead, in opposite directions

| flag | written by | read by |
|---|---|---|
| `csar.alreadyInitialized` | **nobody** | `csar.initialize`, as its re-entry guard |
| `csar.skipInitialisation` | `veaf.lua:5868` | **nobody** |

`csar.initialize` opens with:

```lua
if csar.alreadyInitialized and not force then
  csar.logInfo("Bypassing initialization because csar.alreadyInitialized = true")
  return
end
```

Nothing in `CSAR.lua`, in `veaf.lua`, or anywhere in the repository ever assigns
`csar.alreadyInitialized`. The branch is unreachable and that log line has never been printed.

Symmetrically, `veaf.csar_initialize_replacement` sets `csar.skipInitialisation = true` with the
comment *"change the init function so we can call it whenever we want"* — and no code reads it. It
looks like the two halves of a mechanism that were never joined.

## And the one guard that exists is bypassed anyway

The VEAF wrapper calls the vanilla function with **`force = true`**:

```lua
veaf.csar_initialize(true)   -- veaf.lua:5925
veaf.csar_initialized = true
```

So even if `alreadyInitialized` were set, `not force` would be false and the guard would not fire.
Three mechanisms, none of which can stop a second initialisation.

## What a second initialisation actually does

`csar.initialize` ends with:

```lua
world.addEventHandler(csar.eventHandler)
```

DCS does not deduplicate handlers. A second call registers a second one, and **every ejection is then
processed twice** — two `MAYDAY` messages, two downed pilots for one crash, two ADF beacons.

That is not hypothetical in this repository: the DCS event handler was registered twice until 6.17.0
and every event ran twice (#824). Same shape, same file family, fixed once already.

## What is actually at risk — measured, not assumed

**Nothing is failing today.** Measured over the 2026-08-31 session: six mission loads, six
initialisations, one each. The auto-init at the bottom of `CSAR.lua`
(`timer.scheduleFunction(csar.initialize, nil, timer.getTime() + 2)`) resolves to the VEAF wrapper,
which runs once.

The exposure is the documented path. `veaf.lua` says, right above the wrapper:

> Our CSAR (VEAF version) does not autoinitialize. **Instead, we count on the mission makers to call
> `csar.initialize` from mission-script.lua**

A mission maker following that instruction gets a *second* full pass — wrapper included, with
`force = true` — on top of the automatic one. Two event handlers, and the second is indistinguishable
from the first.

That the comment is also **wrong** (CSAR does auto-initialise, two seconds after load) is part of the
same knot: the comment describes the intent behind `skipInitialisation`, which was never wired up.

## Scope

- Decide which of the two flags is the real mechanism, wire it, and delete the other. Most likely
  `alreadyInitialized` set at the end of `csar.initialize`, since that is what the guard already
  reads — but `skipInitialisation` may be the better answer if the intent was to suppress the
  *automatic* pass rather than to deduplicate.
- Decide whether the wrapper should keep passing `force = true`. It probably should not: forcing was
  a way around a guard that never worked.
- `CSAR.lua` is vendored `adapted`, so a change there must go into `vendored.yaml`'s `manual_steps`
  or be done from `veaf.lua` like the seven other replacements. Prefer `veaf.lua`.
- Correct the comment in `veaf.lua`: CSAR *does* auto-initialise.

## What was done

The remedy is not a flag. Re-initialising is a **feature** — it is how a mission maker's
configuration callback is applied — so refusing the second call would have broken the documented
path instead of fixing it. What must not happen twice is the event handler.

`veaf.csar_initialize_replacement` now drops the previous handler before the vanilla initialiser
registers a new one:

```lua
if veaf.csar_initialized then
  world.removeEventHandler(csar.eventHandler)
end
veaf.csar_initialize(true)
csar.alreadyInitialized = true
```

`csar.eventHandler` is a single stable table (`CSAR.lua:449`), so `removeEventHandler` finds it.
Setting `csar.alreadyInitialized` afterwards makes CSAR's own guard reachable at last, for anyone
calling the vanilla function directly without `force`.

`csar.skipInitialisation` was **deleted** rather than wired: it was the other half of a mechanism
that was never joined, and it made the initialisation look guarded when it was not.

All of this lives in `veaf.lua`, like the eight other replacements, so `CSAR.lua` stays a clean
vendored copy.

### The comment that said the opposite of the code

`veaf.lua` claimed *"Our CSAR (VEAF version) does not autoinitialize"*. It does — the bottom of
`CSAR.lua` schedules `csar.initialize` two seconds after load, and by then the wrapper has replaced
it. Anyone reading that comment to decide whether they also had to call it from `mission-script.lua`
was told the wrong thing, and doing both is exactly what produced the second handler. Corrected.

### The mock that could not tell the difference

`world.addEventHandler` was `function(handler) end` in `dcs_mocks.lua` — a no-op. No test could
distinguish a script that registers once from one that registers on every call, which is the whole
question here. It records handlers now, and `removeEventHandler` removes them.

Same shape as the MiST stubs found during `DROP-MIST`: a mock that answers everything and proves
nothing.

### The suite that did not exist

There was **no test for CSAR at all**. `test_csar_init.lua` loads the scripts in a real mission's
order — CSAR *before* VEAF, which every other suite gets backwards — and that ordering is the point:
it is why the load-time assertion defect shipped and broke every mission until it was found in game.

Seven tests. Three fail when the handler removal is taken out.

## Definition of done

- [x] A test drives `csar.initialize` **twice** and asserts `world.addEventHandler` was called once —
      asserting the wiring, not the flag, which is what let this sit unnoticed
- [x] A test covers the documented path: automatic init, then an explicit call from a mission script
- [x] No flag is left written-but-unread or read-but-unwritten
- [x] The `veaf.lua` comment describes what the code does
- [x] Lua suite green, `stylua` and `luacheck` clean, `CHANGELOG.md` entry

## Why this was not fixed on the spot

It surfaced during an in-game session whose purpose was to close two other lots, and it is not what
that session was verifying. Fixing a guard means deciding what the guard should be, which is a design
question about how a mission maker is meant to initialise CSAR — not a one-line change to slip into
an unrelated pull request.
