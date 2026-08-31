# 01 — Honour the spawn chance

Status: ✅ done

Type: fix · File: `src/scripts/veaf/veafCombatZone.lua`

## The change

In `VeafCombatZone:activate()`, the forced draw (`if tries == 1 then chance = 0 end`) must apply
only to element groups whose `#spawncount` was **stated by the mission maker**. Elements left at
the default `spawnCount = 1` get their probability honoured: a `#spawnchance=50` element spawns
about half the time.

That means the code has to tell "spawnCount was written" from "spawnCount defaulted to 1".
`VeafCombatZoneElement` currently initialises `spawnCount = 1` at creation
(`veafCombatZone.lua:288`), which erases the distinction — the same shape as the `#alarm` tag,
whose comment right below explains why it stays `nil` when unstated:

> **nil means "not stated"**, which is what lets the state be chosen by the group's nature at spawn
> time. Defaulting it here would make a deliberate `#alarm=0` indistinguishable from silence.

Do the same for `spawnCount`, and treat `nil` as 1 where the count is used.

## Definition of done

- [x] An element with `#spawnchance=50` and no `#spawncount` spawns roughly half the time —
      asserted statistically over many activations with a seeded RNG, not by eyeballing one run
- [x] An element at the default `#spawnchance=100` still always spawns
- [x] A group with `#spawncount=2` over 4 elements still yields exactly 2, every time — the
      guarantee that justifies the forced draw
- [x] A group with `#spawncount=2` **and** `#spawnchance=50` still reaches 2 (retries do their job)
- [x] `#spawnchance=0` never spawns — today it spawns on the forced try, which is the defect at its
      most visible
- [x] The runtime tests cover the wiring, not just the getter: assert what `activate()` actually
      spawns, via the DCS mocks

## Watch out

`veafCombatMission.lua` has its own `spawnChance` (line 328, 420) with the same default of 100.
Read it before changing anything shared: this ticket is about the combat **zone**. If the two
mechanisms turn out to share code, say so rather than changing both silently.
