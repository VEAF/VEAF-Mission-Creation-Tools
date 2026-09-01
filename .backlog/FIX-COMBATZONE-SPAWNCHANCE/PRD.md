# FIX-COMBATZONE-SPAWNCHANCE — a spawn chance that never denies a spawn

Status: ✅ done

Origin: VEAF meeting, 2026-08-30 ("spawnChance devrait être autocalculé"). Measured on
`origin/develop` at `c14e79e2`; David chose "the probability must be honoured" on 2026-08-31.

## The defect

`VeafCombatZone:activate()` spawns each element group by drawing a random number per element and
comparing it to that element's `spawnChance`. It retries until `spawnCount` elements have spawned —
and **forces the draw on the last try**:

```lua
local tries = 10
while spawnCount > 0 and tries > 0 do
  tries = tries - 1
  ...
      local chance = math.random(0, 100)
      if tries == 1 then chance = 0 end  -- force chance if in the last try
      if chance <= zoneElement:getSpawnChance() then
```

Defaults are `spawnChance = 100` and `spawnCount = 1`, and an element with no `#spawngroup` gets
its own group (`veafCombatZone.lua:539` defaults the spawn group to the DCS group name). So the
common case is **one element, `spawnCount = 1`**: nine random draws, then a forced one. It always
spawns. `#spawnchance` changes *when*, never *whether*.

`doc/mission-maker/scripts/veafCombatZone.en.md` documents the opposite, in its worked example:

> Four MANPADS positions, `#spawnchance=50` on each — "statistically, around two will be active
> each time the zone is triggered."

Four spawn, every time.

## The decision

**The probability is honoured as written.** The forced draw stays only where it earns its keep: a
group carrying an explicit `#spawncount`, which is a promise of a number ("2 of these 4, granted").
Without `#spawncount`, an element at 50 % spawns half the time.

## What this changes for missions in service

Zones carrying `#spawnchance` will spawn **less** than they do today. That is the point, and it is
also a behaviour change to missions already running — call it out in the changelog and the PR.

## Also in this lot — the doc still shows Lua

`doc/mission-maker/GUIDE.md` (around line 646) teaches combat zones as Lua:

```lua
local strikeZone = VeafCombatZone:new()
  :addZoneElement(VeafCombatZoneElement:new():setName("ARMOR"):setSpawnGroup("STRIKE-ALPHA-ARMOR"))
```

The YAML form exists (`COMBATZONE: combat_zones:` — see `veaf_libs/mission_template.py:69`) and is
what a mission maker should write. Replace the Lua examples with the YAML ones, in both languages.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Honour the spawn chance](tickets/01-honour-spawn-chance.md) | fix |
| 02 | [Teach combat zones as YAML, not Lua](tickets/02-combatzone-doc-yaml.md) | docs |

## Out of scope

- **Deriving the chance from `#spawncount`** (the literal reading of the meeting note). Today
  `#spawncount=2` over 4 elements already yields exactly 2, picked at random by the shuffle; a
  derived percentage would trade that guarantee for variability. Not wanted for now.
