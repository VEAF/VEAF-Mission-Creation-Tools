# 02 — an empty survey mission, and the sweep that fills the catalogue

Status: ⬜ ready — depends on ticket 01
Type: feat

## What this builds

**The survey mission.** A `.miz` holding no units at all, generated for a given map and loaded only
to be swept. Empty is the whole point: the probe answers "is there room here" and counts vehicles as
obstacles, so anything standing on the map would be baked into the catalogue as permanent scenery
(PRD, *What was learned*). Sweeping from whatever mission is at hand is exactly the mistake that
cost two days this week.

**The sweep.** Two passes, per decision 1: a coarse one at 200 m over the whole map, a fine one at
50 m around the combat zones, airfields and road axes. Each retained point carries the **clear
radius** measured around it, by whichever method ticket 01 found cheapest.

**Resumability is not optional.** A pass measured in tens of minutes will be interrupted — DCS
dropped its connection three times in one evening while this lot was being investigated. The sweep
must stop and continue rather than start over.

## What has to be decided while building

- The file format, and where a map's catalogue lives when versioned in VMCT (decision 5, first
  half).
- What "around the airfields and road axes" means concretely — a radius around each, or a corridor
  along them. Combat zones are easy: they already have a radius.

## Definition of done

- [ ] A survey mission can be generated for a map, and holds no units
- [ ] The sweep produces a catalogue carrying a clear radius per point, at both spacings
- [ ] The sweep can be interrupted and resumed without losing what it has done
- [ ] Sweeping the same map twice produces the same catalogue. The small probe is deterministic
      (12 repetitions, 0/12 against 12/12, identical counts), so this is a real assertion rather
      than a formality
- [ ] A catalogue is produced for GermanyCW and committed
- [ ] Python tests green, and `stylua --check` plus `luacheck` clean wherever Lua is touched
