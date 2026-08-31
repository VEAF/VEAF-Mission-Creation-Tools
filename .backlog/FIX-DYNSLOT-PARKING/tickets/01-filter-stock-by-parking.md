# 01 — Stock only what the terrain can park

Status: ⬜ ready

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

- [ ] An airfield whose spots are all helicopter-capable is stocked with **helicopters only**
- [ ] An airfield with plane parking is stocked exactly as today
- [ ] An explicit `aircrafts:` list is filtered the same way — the point is that DCS ignores what
      it cannot park, so writing it is always pointless
- [ ] A theatre with no parking data behaves **exactly** as today (no filtering) — test it, this is
      every map but three
- [ ] An airfield absent from the parking file behaves as today
- [ ] Regression test on the real shape: Naqoura (helicopters only) and Incirlik (everything) of
      the bundled Syria data
- [ ] The `linkDynTempl` links follow the filtered stock — a link to a type that is no longer
      stocked is dead weight

## Measurable outcome

On the VEAF Open Training Syria mission, Lakatamia and Naqoura go from 149 plane types stocked to
none, and keep their helicopters. Akrotiri, Incirlik and Damascus are unchanged.
