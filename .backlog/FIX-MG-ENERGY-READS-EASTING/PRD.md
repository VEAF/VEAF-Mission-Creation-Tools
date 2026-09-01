# FIX-MG-ENERGY-READS-EASTING — a missile's potential energy is computed from its longitude

Status: ⬜ ready

Found 2026-09-01 by the enumeration [`FIX-AIR-SPAWN-ALTITUDE-GUARD`](../FIX-AIR-SPAWN-ALTITUDE-GUARD/PRD.md)
was asked to do — "enumerate the other height tests rather than sample them". This one is **not** on the
spawn path, so it was opened as its own lot rather than folded in.

## The defect

`VeafMG_Weapon:getCurrentEnergy` (`src/scripts/veaf/veafMissileGuardian.lua:176`):

```lua
local _alt = self:getDcsWeapon():getPoint().z
local _potential = _mass * 9.81 * _alt
```

`getPoint()` returns a runtime vec3, whose altitude is `y`; `z` is the **easting**
(`docs/agents/dcs-coordinates.md`). So the potential energy of a missile is computed from how far east
it is. On Caucasus that is a few hundred thousand metres, so the "potential" term dominates the kinetic
one by two orders of magnitude and barely varies as the missile flies — the total is essentially a
constant times the missile's longitude.

Fourth site of the same confusion in three days, after `FIX-AIRWAVES-COMMAND-EASTING`,
`FIX-WAVE-OFFSET-AXES` and the aircraft spawn guard.

## Why it is small, and worth doing anyway

`getCurrentEnergy` has **no caller in `src/`**: the only reference outside its own definition is
`test_veafMissileGuardian.lua`, which covers the case where there is no weapon and never reaches the
arithmetic. So nothing observable is wrong in a mission today.

That is an argument about size, not about correctness. The function exists to be used — the missile
guardian's whole purpose is deciding whether a missile still threatens a protected unit — and a
one-word defect that is invisible until the day someone wires it up is exactly what this family of bugs
does.

## Definition of done

- [ ] The altitude is read from `y`
- [ ] A test that **separates the two readings**: a weapon high up at easting 0 and one at sea level far
      east cannot both give the same answer. A test that passes under either reading is worth nothing —
      that is the trap `FIX-AIR-SPAWN-ALTITUDE-GUARD` documented
- [ ] Decide, and say which: is the mass really 250 kg for every weapon (`-- let's say the missile
      weights 250kg`), or should it come from the weapon description? Out of scope to *change*, in scope
      to state
- [ ] `poetry run test-lua`, `stylua --check src/scripts/veaf/ test/lua/` clean

## Out of scope

- Wiring `getCurrentEnergy` into the guardian's decisions. Whether an energy threshold is the right way
  to decide that a missile is no longer a threat is a design question, not a coordinate one.
