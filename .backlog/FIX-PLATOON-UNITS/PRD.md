# FIX-PLATOON-UNITS — the platoon spawner does not know the units the database does

Status: ⬜ ready

Origin: [#296](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/296). Its sibling #295 (the
unit *list*) is closed and done; this is the same request on the other surface.

## The gap

The Currenthill units are in `veaf_libs/data/dcsUnits.yaml` and `dcsUnits.lua`, kept fresh by
`update-dcs-data`. A platoon composition, though, is a **hand-written table** in `veafCasMission.lua`
(armour tiers at `:264-273`), and `Oplot`, `T-90M` and `Terminator` appear in none of them. So the
data pipeline gains units and the spawner never sees them — not a missing entry, but a table that
does not read the database.

## Scope

Add the modern units, and decide whether the tiers should be **derived** from `dcsUnits` by era and
role instead of hand-written. Deriving stops this recurring; hand-editing ships this week. Record
which was chosen, and why.

## Definition of done

- [ ] The units listed on #296 can appear in a spawned platoon
- [ ] A test asserting a composition draws only from types the database knows
- [ ] The derive-vs-hand-write decision recorded here
