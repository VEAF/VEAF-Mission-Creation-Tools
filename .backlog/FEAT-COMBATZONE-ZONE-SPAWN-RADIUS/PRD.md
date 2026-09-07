# FEAT-COMBATZONE-ZONE-SPAWN-RADIUS — a zone decides the dispersion its own elements get

Status: ⬜ ready

Origin: Tripack, relayed by David on 2026-09-07. He places air defences in the revetments the Syria
map provides — emplacements drawn for exactly that — and a spawn that scatters a launcher by tens of
metres puts it on the berm instead of inside it. His ask, in David's words: *"une option sur les CZ
pour changer le default de spawnradius. Comme ça il peut mettre 0 pour les CZ où il a beaucoup
d'objets placés pile poil."*

## What already works, and must be said before writing any code

Two thirds of this request is already served, and the lot is smaller because of it.

**Per group, today.** `#spawnradius=0` on a group's or a unit's name means "no dispersion", and since
FIX-TRIPACK-FIELD-REPORTS ticket 04 it is an **identity spawn** — asserted to the millimetre in
`test_veafCombatZone_displacement.lua`. Before that ticket the tag was not enough on its own: the
anchor offset applied whatever the radius, which `veafCombatZone.lua` admitted in its own comment
(*"the delta is not only the dispersion"*), so a group could still move with dispersion switched off.

**Globally, today.** `veafCombatZone.DefaultSpawnRadiusForUnits` and `…ForStatics` are plain module
globals, already documented for mission makers
([`veafCombatZone.md:508`](../../doc/mission-maker/scripts/veafCombatZone.md)). Writing
`veafCombatZone.DefaultSpawnRadiusForUnits = 0` in `veaf-config.lua` before the `AddZone` calls
already changes the default for the whole mission.

**What is missing is the middle ground**, and that is exactly what he asked for: *some* zones pinned,
the rest scattering normally. He has **38 zones** in `Snowfox_20260903.miz`, so neither tagging every
group of a pinned zone nor flattening the default for all 38 is the right tool.

## The shape it should take

Tripack declares his zones explicitly, in the fluent style, one call per zone:

```lua
veafCombatZone.AddZone(
    VeafCombatZone:new()
    :setMissionEditorZoneName("CMBT_ABU_DHABI_AIRPORT")
    :setFriendlyName("ABU DHABI AIRPORT")
    :setRadioGroupName("PERSIAN SOUTH")
    :setTraining(false)
    :initialize()
)
```

So the option belongs in that chain — `:setDefaultSpawnRadius(0)` — which costs him one line on the
zones that need it and nothing anywhere else. No new vocabulary, no new file, no editor convention.

**Rejected: a tag in the trigger zone's name.** It would read naturally (`#spawnradius=0` on the zone
the way it goes on a group), but a combat zone's name is load-bearing: every group belonging to it
must be named with that name as its **prefix**, and the zone reports the ones that are not
(`reportGroupsExcludedByName`, which fired in Tripack's own log). Appending a tag to the zone name
would either break that prefix rule or force the rule to start stripping tags — a change to the
naming contract of every existing mission, to save a line of Lua in a file the mission maker already
edits. Worth recording as considered and refused rather than silently skipped.

## The trap this must not fall into

`initialize()` is what builds the zone elements, and it is what applies the default
([`veafCombatZone.lua:608`](../../src/scripts/veaf/veafCombatZone.lua)). A setter called **after** it
would be read by nobody and would fail silently — the exact failure mode this repository has been
bitten by twice (`test_defaultSpawnRadii` stayed green for three years while the default never
applied; `spawnSmoke` reported success and produced nothing). Tripack's own style puts `initialize()`
last, so the happy path is natural, but the code must not rely on that.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [A zone carries its own spawn-radius default](tickets/01-zone-level-spawn-radius-default.md) | feat |

## Constraints

- `#spawnradius=` written on a group **still wins** over the zone's default, which still wins over the
  module global. Three levels, most specific first, and the precedence is part of the tests.
- The distinction FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT established has to survive: the default is
  applied because the tag was **not written**, never because its value happens to be 0. A zone default
  of 0 and a group tag of `#spawnradius=0` must remain distinguishable in the code.
- **Both languages** for the documentation page, in lockstep, and `poetry run docs-check` clean.
- Any test asserting dispersion has to drive `dcs_mocks.setRandomSequence`: the mocks answer
  `math.random()` with a constant 0, so in the harness no spawn ever scatters and a naive "it moved"
  or "it did not move" assertion passes either way. Recorded in FIX-TRIPACK-FIELD-REPORTS ticket 04.
