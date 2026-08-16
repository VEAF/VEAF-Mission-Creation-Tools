# FIX-EMPTY-WAREHOUSES — a built mission has no usable airfield

Status: 🧑 waiting-human — implemented 2026-08-16, needs one in-game confirmation

Origin: the test mission built to verify `FIX-CTLD-NEVER-INITIALIZED`. Its two helicopter slots,
parked cold at Deir ez-Zor, could be **selected but never taken** — the pilot stayed a spectator.
The same mission, opened in the DCS Mission Editor and launched from there, worked.

## How it was found, and what it cost

Three hypotheses were posed and eliminated by David testing one file at a time, each isolating a
single variable:

| Suspect | Verdict |
|---|---|
| `payload.fuel: 0` on our units | **wrong** — the editor left it at 0 and the mission works |
| a missing `AddPropAircraft.NetCrewControlPriority` | **wrong** — adding it alone changed nothing |
| four groups referencing absent mods (`A-4E-C`, `OV-10A`) | **wrong** — removing them changed nothing |

The method error is worth recording: the first three rounds diffed the **`mission` table** only. A
`.miz` has five members, and diffing the whole archive answered it immediately:

| member | ours | the editor's |
|---|---|---|
| **`warehouses`** | **69 bytes** | **179 992** |
| `options` | 299 | 23 498 |
| `mission` | 927 191 | 862 322 |

Our `warehouses` is `airports = {}`. The editor writes **one entry per airfield of the theatre** —
224 on Syria. That table is where an airfield's coalition and stock live; without an entry the
airfield does not exist as a usable base, so a ramp start has nowhere to put the aircraft. An air
start does not go through it, which is why `SmokePlayer` always worked and why this survived
`FIX-SCRATCH-MISSION-PLAYABLE`, whose slot was airborne.

Confirmed by a file carrying that one change: **`CTLD-Test_warehouses.miz` — our mission with the
editor's `warehouses` — is takeable.**

Detail that shapes the fix: the editor writes every one of the 224 entries as `coalition =
"NEUTRAL"`, including fields with units on them. Ownership is resolved at runtime; a mission whose
airfields are all neutral flies correctly.

## Nothing reported it

`validate` said *"aucun problème détecté"*, the build said nothing, and the warehouses injector
logged *"0 airports configured"* — which reads like a mission that declared none, not like a mission
that cannot work. `apply_warehouses` **configures** airports it finds; it has never created any.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Populate the airfield table at build time](tickets/01-populate-airports.md) | ✅ |
| 02 | [Persist a warehouses change to disk](tickets/02-persist-warehouses.md) | ✅ |

## Measured after the fix

A rebuild of the smoke-test mission: `warehouses` goes from **69 bytes to 150 040**, 225 airfields,
`coalition = NEUTRAL`, 20 keys each — the shape read off the editor's own output.

**225, not 224**: our runtime-sourced `airdromes.yaml` carries id 43 (Nicosia) which the editor does
not write. An entry for an id DCS does not know is inert, so it is left in rather than special-cased
— but it is a real difference and it is recorded here rather than rounded off.
