# FIX-DYNSLOT-PARKING — stocking aircraft an airfield cannot park

Status: ✅ done · archived 2026-09-28

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
| 01 | [Stock only what the terrain can park](FIX-DYNSLOT-PARKING.md) | fix |
| 02 | [Document dynamic slots and what limits them](FIX-DYNSLOT-PARKING.md) | docs |

## Out of scope

- **Changing an airfield's coalition.** An unassigned base is skipped by design; that stays a
  Mission Editor decision.

---

## Tickets, in full

## 01 — Stock only what the terrain can park

Status: ✅ done

Type: fix · Files: `src/python/veaf-tools/warehouses_injector/warehouses_injector_worker.py`,
`src/python/veaf-tools/veaf_libs/` (a parking-capability helper)

### The change

`_apply_to_airport` auto-fills a base with every dynamic template of its coalition
(`warehouses_injector_worker.py:226`). It must first ask what the airfield can park, and keep only
the matching categories: helicopters at a helipad-only field, everything at a real airbase.

The data is bundled: `veaf_libs/data/parking/<Theatre>.json`, `by_airbase[<id>]` is a list of spots,
each with a `t` (DCS `Term_Type`).

### Source the term types before coding

The repo has **no** mapping from `Term_Type` to "what can park here". Establish it and write it
down with its provenance — the DCS scripting docs or a runtime probe via the bridge, not memory.
The measured distribution (see the PRD) is a consistency check, not a source: helicopter-only
fields carry `40` exclusively, working airbases carry `104`/`68`/`72`.

### Definition of done

- [x] An airfield whose spots are all helicopter-capable is stocked with **helicopters only**
- [x] An airfield with plane parking is stocked exactly as today
- [x] An explicit `aircrafts:` list is filtered the same way — the point is that DCS ignores what
      it cannot park, so writing it is always pointless
- [x] A theatre with no parking data behaves **exactly** as today (no filtering) — test it, this is
      every map but three
- [x] An airfield absent from the parking file behaves as today
- [x] Regression test on the real shape: Naqoura (helicopters only) and Incirlik (everything) of
      the bundled Syria data
- [x] The `linkDynTempl` links follow the filtered stock — a link to a type that is no longer
      stocked is dead weight

### Measurable outcome

On the VEAF Open Training Syria mission, Lakatamia and Naqoura go from 149 plane types stocked to
none, and keep their helicopters. Akrotiri, Incirlik and Damascus are unchanged.

### Delivered

#### The sourced table

`Term_Type` is DCS's `Airbase.TerminalType`. Sourced 2026-08-31 from two independent references that
agree value for value — the Hoggit wiki's [`getParking`](https://wiki.hoggitworld.com/view/DCS_func_getParking)
page and MOOSE's [`AIRBASE.TerminalType`](https://flightcontrol-master.github.io/MOOSE_DOCS/Documentation/Wrapper.Airbase.html).
ED's own scripting FAQ does not document it. No runtime probe was needed.

| Value | Name | Meaning |
|---|---|---|
| 16 | `Runway` | Runway spawn point, not a parking stand |
| 40 | `HelicopterOnly` | Helipad |
| 68 | `Shelter` | Hardened aircraft shelter |
| 72 | `OpenMed` | Open / shelter air, airplane only |
| 100 | `SmallSizeFighter` | Tight stand for a small fixed-wing aircraft |
| 104 | `OpenBig` | Open air stand, generally larger |

The two capability sets come from that reference's own composite masks, which are the sums of the
values they combine: `FighterAircraftSmall` = 344 = 68 + 72 + 100 + 104 (planes) and
`HelicopterUsable` = 216 = 40 + 72 + 104 (helicopters). `Runway` (16) is in neither. The table lives
in `veaf_libs/dcs_parking.py` with that provenance.

Consistency check across the three bundled dumps: **no** airbase anywhere lacks a helicopter-capable
stand, so the helicopter half of the filter never fires; 151 of Syria's 225 entries have no plane
stand (helipads and FARPs), Lakatamia (48) and Naqoura (52) among them.

#### One thing had to be decided

Skipping the write was not enough. Measured on `OpenTraining_Syria_20260830.miz`, the **source**
mission already carries 144 plane types at Lakatamia from an earlier build, and the injector merges
into existing stock rather than replacing it — so Lakatamia would have kept them forever and the
measurable outcome would not have been met. The lot therefore also **prunes** the unparkable
category, but only on an airfield the config targets and only where parking data ships: what is
removed is provably inert, since DCS can never offer it.

Verified on that mission, read-only: exactly three airfields change — Lakatamia (48) 144 → 0 planes,
Naqoura (52) 41 → 0, and **Taftanaz (38)** 144 → 0, a third helicopter-only field the meeting had
not spotted. No airfield loses a helicopter, and the other 29 configured bases are byte-identical.

---

## 02 — Document dynamic slots and what limits them

Status: ✅ done

Type: docs · Files: the mission-maker docs covering `warehouses.yaml`, both languages

### Why

Two questions came out of the meeting, and one of them was purely a documentation gap: **how the
aircraft offered on a base are decided**. The mechanism is right and nobody could see it — nothing
is written in `warehouses.yaml`, the list is computed at build time from the dynamic-spawn template
groups present in the mission.

The other is the parking limit of ticket 01, which a mission maker has no way to guess: the tool
now stocks only what the terrain can park, silently.

### Definition of done

- [x] A page (or a section of the existing one) says plainly:
      - a base offers the aircraft that have a **dynamic-spawn template group** of its coalition in
        the mission — that is where the list comes from, and why `warehouses.yaml` is nearly empty;
      - an explicit `aircrafts:` list replaces that automatic choice;
      - DCS only ever offers what the airfield can **park**, so a helipad-only field offers
        helicopters whatever the stock says — with Lakatamia and Naqoura as the worked example, and
        how to check it (the slot picker in game);
      - the parking filter applies on the theatres with bundled parking data (Caucasus, Persian
        Gulf, Syria) and nothing changes elsewhere.
- [x] Both languages, in the `nav`
- [x] `poetry run docs-check` passes

---
