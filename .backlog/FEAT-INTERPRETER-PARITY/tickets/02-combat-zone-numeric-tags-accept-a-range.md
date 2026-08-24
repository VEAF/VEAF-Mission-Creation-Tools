# 02 — A combat-zone numeric tag accepts a range instead of truncating it

Status: ✅ done
Type: feat

## The defect

`veafCombatZone.TAG_PATTERNS` reads numeric tags with `(%d+)`:

```lua
spawnRadius = "#spawnradius%s*=%s*(%d+)",
```

On `#spawnradius=100-300` that captures `100`. The `-300` is not rejected — it is **not seen**, so the
mission maker who wrote a range gets the lower bound and no warning. #25 asked for the randomisable
parameters to reach combat-zone elements; they cannot even be written today.

## Scope

The four tags whose value is a count or a distance: `spawnRadius`, `spawnChance`, `spawnCount`,
`spawnDelay`. Conversion goes through `veaf.getRandomizableNumeric`, the same function marker commands
use, so `100-300` means the same thing in both places.

**`alarmState` is deliberately excluded**: it is an enumeration (0 AUTO, 1 GREEN, 2 RED), and a range
over an enumeration is not a random value, it is a mistake. `spawnGroup` is a string.

**When the draw happens** has to be decided rather than fallen into: at tag-reading time, which is
`initialize`, so a range is drawn **once per mission** and every activation of the zone uses the same
value. The alternative — redrawing on each activation — is a different feature and a surprising one for
`spawnRadius`.

## Definition of done

- [x] `#spawnradius=100-300` draws a value in that range, and a plain `#spawnradius=200` is unchanged
- [x] `alarmState` still refuses a range, and says so as it already does for an out-of-bounds value
- [x] Lua tests over each of the four tags, plus the two exclusions
- [x] Documented on the `veafCombatZone` page, both languages
