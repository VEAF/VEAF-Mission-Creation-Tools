# FIX-COMBATZONE-SPAWNCHANCE — a spawn chance that never denies a spawn

Status: ✅ done · archived 2026-09-28

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
| 01 | [Honour the spawn chance](FIX-COMBATZONE-SPAWNCHANCE.md) | fix |
| 02 | [Teach combat zones as YAML, not Lua](FIX-COMBATZONE-SPAWNCHANCE.md) | docs |

## Out of scope

- **Deriving the chance from `#spawncount`** (the literal reading of the meeting note). Today
  `#spawncount=2` over 4 elements already yields exactly 2, picked at random by the shuffle; a
  derived percentage would trade that guarantee for variability. Not wanted for now.

---

## Tickets, in full

## 01 — Honour the spawn chance

Status: ✅ done

Type: fix · File: `src/scripts/veaf/veafCombatZone.lua`

### The change

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

### Definition of done

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

### Watch out

`veafCombatMission.lua` has its own `spawnChance` (line 328, 420) with the same default of 100.
Read it before changing anything shared: this ticket is about the combat **zone**. If the two
mechanisms turn out to share code, say so rather than changing both silently.

---

## 02 — Teach combat zones as YAML, not Lua

Status: ✅ done

Type: docs · Files: `doc/mission-maker/GUIDE.md` + `.en.md`,
`doc/mission-maker/scripts/veafCombatZone.md` + `.en.md`

### The gap

`GUIDE.md` teaches combat zones by showing Lua (`VeafCombatZone:new():addZoneElement(...)`), around
line 646. A mission maker on v6 writes YAML:

```yaml
modules:
  COMBATZONE:
    enabled: true
    combat_zones:
      - type: zone
        zone_name: CZ-Alpha
        friendly_name: Alpha Zone
        training: false
```

(from `veaf_libs/mission_template.py:69`, which is what `convert-v5` and the scaffold emit).

### Definition of done

- [x] The `GUIDE` shows the YAML form first; Lua appears only where it is genuinely the answer
      (a maker function called from `mission-script.lua`), clearly labelled as such
- [x] Both languages, in step
- [x] The MANPADS example in `veafCombatZone.md` is corrected to match ticket 01's behaviour —
      today it claims "around two will be active", which was never true and will become true
- [x] `poetry run docs-check` passes

---
