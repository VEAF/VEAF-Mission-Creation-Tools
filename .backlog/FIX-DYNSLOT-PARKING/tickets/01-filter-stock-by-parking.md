# 01 — Stock only what the terrain can park

Status: ✅ done

Type: fix · Files: `src/python/veaf-tools/warehouses_injector/warehouses_injector_worker.py`,
`src/python/veaf-tools/veaf_libs/` (a parking-capability helper)

## The change

`_apply_to_airport` auto-fills a base with every dynamic template of its coalition
(`warehouses_injector_worker.py:226`). It must first ask what the airfield can park, and keep only
the matching categories: helicopters at a helipad-only field, everything at a real airbase.

The data is bundled: `veaf_libs/data/parking/<Theatre>.json`, `by_airbase[<id>]` is a list of spots,
each with a `t` (DCS `Term_Type`).

## Source the term types before coding

The repo has **no** mapping from `Term_Type` to "what can park here". Establish it and write it
down with its provenance — the DCS scripting docs or a runtime probe via the bridge, not memory.
The measured distribution (see the PRD) is a consistency check, not a source: helicopter-only
fields carry `40` exclusively, working airbases carry `104`/`68`/`72`.

## Definition of done

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

## Measurable outcome

On the VEAF Open Training Syria mission, Lakatamia and Naqoura go from 149 plane types stocked to
none, and keep their helicopters. Akrotiri, Incirlik and Damascus are unchanged.

## Delivered

### The sourced table

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

### One thing had to be decided

Skipping the write was not enough. Measured on `OpenTraining_Syria_20260830.miz`, the **source**
mission already carries 144 plane types at Lakatamia from an earlier build, and the injector merges
into existing stock rather than replacing it — so Lakatamia would have kept them forever and the
measurable outcome would not have been met. The lot therefore also **prunes** the unparkable
category, but only on an airfield the config targets and only where parking data ships: what is
removed is provably inert, since DCS can never offer it.

Verified on that mission, read-only: exactly three airfields change — Lakatamia (48) 144 → 0 planes,
Naqoura (52) 41 → 0, and **Taftanaz (38)** 144 → 0, a third helicopter-only field the meeting had
not spotted. No airfield loses a helicopter, and the other 29 configured bases are byte-identical.
