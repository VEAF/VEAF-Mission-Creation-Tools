# FIX-DYNSLOT-PARKING — stocking aircraft an airfield cannot park

Status: ✅ done

Origin: VEAF meeting, 2026-08-30 ("faire en sorte que les 3 airdromes manquants sur Syria soient
injectables"). Diagnosed and confirmed **in game** on 2026-08-31.

## What was actually happening

The three airfields — Akrotiri, Lakatamia, Naqoura — were never a tool defect. Measured on the
VEAF Open Training Syria mission (`OpenTraining_Syria_20260830.miz`):

| | id | coalition | dynamicSpawn | stock | in game |
|---|---|---|---|---|---|
| Akrotiri | 44 | BLUE | true | 149 planes / 26 helicopters | works |
| Lakatamia | 48 | BLUE | true | 149 planes / 26 helicopters | **helicopters only** |
| Naqoura | 52 | BLUE | true | 149 planes / 26 helicopters | **helicopters only** |

Everything the tool controls was already right: the names resolve (`Akrotiri` → 44, case
insensitively), the bases are blue, `dynamicSpawn` is on, the templates are linked, and the build
reported "32 aéroports configurés" — every assigned base, these three included. David confirmed in
the Mission Editor that the `A-10C II` template is linked at Lakatamia, and in game that the slot
picker offers six helicopters and no plane.

**DCS filters by the parking the terrain actually has**, from the bundled runtime dumps
(`veaf_libs/data/parking/Syria.json`, field `t` = DCS `Term_Type`):

| Airfield | Spots | Types |
|---|---|---|
| Akrotiri | 47 | `104`×28, `68`×13, `40`×4, `16`×2 |
| Lakatamia | 10 | `40`×8, `16`×2 |
| Naqoura | 9 | `40`×9 |
| Incirlik (works) | 128 | `104`×66, `68`×47, `72`×11, … |
| Damascus (works) | 75 | `104`×55, `68`×8, `72`×8, … |

The two that fail carry only `40` (and Naqoura has no runway at all). The three that work carry
`104`/`68`/`72` in quantity. Note the repository holds **no table of `Term_Type` meanings** — the
correlation is strong and confirmed in game, but the mapping itself needs sourcing as part of
this lot rather than assumed.

## The decision

**Fill only what can fly, and document it.** No warning: the build stocks what the terrain can
park and stays quiet about the rest. Today Lakatamia and Naqoura each get 149 plane types that
will never appear — noise in the mission, and an unreadable Resource Manager.

## Reach

Parking dumps exist for **Caucasus, PersianGulf, Syria** only. On any other theatre there is no
data, and the behaviour must be exactly what it is today — no filtering, no message.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Stock only what the terrain can park](tickets/01-filter-stock-by-parking.md) | fix |
| 02 | [Document dynamic slots and what limits them](tickets/02-document-dynslot-limits.md) | docs |

## Out of scope

- **Changing an airfield's coalition.** An unassigned base is skipped by design; that stays a
  Mission Editor decision.
