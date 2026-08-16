# FIX-CTLD-NEVER-INITIALIZED — CTLD 2 never starts in a generated mission

Status: ✅ done — 2026-08-16, all three tickets; upstream filed as VEAF/CTLD#125. **Confirmed in game**: CTLD starts, the FOB spawns without the crash, and the CTLD radio menu is there

Origin: a 6.14.0 mission built by Tripack. Report: *"no CTLD menu in the radio menu"*. The DCS log
he sent carries the whole chain, and the defect is not specific to his mission: **no mission built
by veaf-tools starts CTLD 2**.

## The measurement

From the log (`dcs.log`, 2026-08-16 13:44:42):

1. `CTLD.lua` loads and parks itself, as designed:
   `[CTLD][INFO] CTLD auto-start skipped (ctld.dontInitialize=true). Call ctld.initialize() manually.`
2. `veaf.lua:5089` registers CTLD as a VEAF module:
   `veaf.registerModule(veaf.ctldId, veaf.ctld_initialize, { enable = true }, 50)`.
   That registration is only ever consumed by **`veaf.initialize()`**.
3. `veaf.initialize()` is **never called**. The generated `veaf-config.lua` emits one
   `veafXxx.initialize()` call per module instead — the "legacy" path `veaf.initialize()`'s docstring
   says is still supported. Proof in the log: every module logs its own *"Initializing module"* line,
   and **not one** `VEAF framework initialization starting` / `Initializing module [ctld]` appears.
4. Corroborating signal: CTLD keeps logging as `[CTLD][INFO]`, never as `VEAF-CTLD|…`. The
   `ctld.utils.log` override lives inside `veaf.ctld_initialize`, so its absence is observable.
5. Consequence 1 — **no CTLD radio menu**, the reported symptom.
6. Consequence 2 — **a Lua crash** the moment anything touches CTLD. Tripack's start-up batch
   contains `-fob#FARP_PARIS`; `veafSpawn.spawnFob` calls `CTLDZoneManager.getInstance()`, the
   manager builds on a config that was never loaded, `ctld.gs("smokeRefreshInterval")` returns nil,
   and `CTLD.lua:9109` dies on `attempt to perform arithmetic on local 'interval' (a nil value)`.

## Why no test caught it

`veaf.ctld_initialize` is referenced in exactly three places in the repo: its own definition, the
`registerModule` line, and `test/lua/test_veaf.lua` — which **calls it directly**. The test proves
the function works; nothing proves anything ever calls it. On the Python side,
`lua_config_generator.py` has no `veaf.initialize` string at all, and its CTLD comment states
*"started by veaf.lua"* ([lua_config_generator.py:1578]) — an assertion that stopped being true when
FEAT-CTLD2-INTEGRATION replaced `veaf.ctld_initialize_replacement` with the module registration.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Generate the CTLD start-up call](tickets/01-generate-ctld-startup-call.md) | ✅ |
| 02 | [Fail loudly instead of crashing on an unstarted CTLD](tickets/02-guard-unstarted-ctld.md) | ✅ |
| 03 | [Documentation and upstream report](tickets/03-docs-and-upstream.md) | ✅ |

## What ticket 02 widened, and why

The ticket was scoped to `spawnFob`, the path in the log. Enumerating its guard showed the predicate
`ctld and veaf.isEnabled("ctld")` at **9 sites in 5 files**, each one a door into a CTLD manager and
each crashing identically. Fixing only the reported one would have left eight armed traps, so the
third condition went into a shared `veaf.isCtldReady()` instead. That is a decision taken alone and
open to review.

## What is actually tested, and what is not

Measured with `test-lua --coverage`, not asserted:

| | |
|---|---|
| The generator emits the call, and emits it **before** `veafGrass`/`veafAssets` | 4 Python tests, plus one end-to-end build of the demo mission with `CTLD: true` (call at line 26, `veafGrass` 190, `veafAssets` 200) |
| `veaf.isCtldReady()` — nominal plus all three failure states, and the log line | 5 Lua tests |
| `spawnFob` on an unstarted engine returns nil **and** touches no manager | 1 Lua test |
| **6 of the 9 guarded call sites** (`veafAssets` ×2, `veafGrass` ×2, `veafSpawnAircraft` ×1, `veafSpawnEffects` ×1) | **no test executes them** — measured `*******0` in luacov, and the same lines measured `*******0` *before* this lot too, so nothing regressed, but nothing proves them either |
| The reported symptom — a CTLD entry appearing in the F10 menu | **verified in game 2026-08-16**, but by a human, not by a test. No automated test loads the generated `veaf-config.lua`; the Python side asserts a string in generated text and the Lua side asserts a function |

The in-game run also produced the log evidence the automated tests cannot: `VEAF|I|log: CTLD
initialized.` followed by `VEAF-SPAWN|I|spawnFob: Spawned FOB FOB YD6647 #10228`, i.e. the exact
`-fob` path that used to die on `interval`. Getting there took two other defects out of the way
first — `FIX-FIDDLE-HOOK-CLOBBERS-VEAF` and `FIX-MCP-AIRCRAFT-CATEGORY`, each shipping in its own PR,
both found *because* someone flew the mission. (Named rather than linked: each lot lands on its own
branch, and a relative link to a sibling that does not exist there fails `docs-check`.)

The remaining gap is that no test closes this loop, and `FEAT-DCS-SMOKE-HARNESS` is the instrument
for it: a check asserting the CTLD radio menu exists after load would cover exactly the chain that
broke here. Not done in this lot.

## Out of scope

- **Making `veaf-config.lua` call `veaf.initialize()`.** It would double-initialise every module the
  generator already calls one by one. Switching the generator to the framework entry point is a
  separate, larger change with its own ordering and back-compat surface.
- **Patching `CTLD.lua`.** It is vendored verbatim from [VEAF/CTLD](https://github.com/VEAF/CTLD)
  (ADR 0016); the nil-`interval` crash is reported upstream as
  [VEAF/CTLD#125](https://github.com/VEAF/CTLD/issues/125), not fixed here.

## Workaround for missions already built

Until a rebuild with the fix, add to the mission's `mission-script.lua`:

```lua
if ctld then veaf.ctld_initialize() end
```
