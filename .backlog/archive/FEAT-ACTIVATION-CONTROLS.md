# FEAT-ACTIVATION-CONTROLS — QRA start state + combat-zone completability in YAML

Status: ✅ done

## Problem (reported by Tripack)

Two unrelated gaps, both about *when a subsystem activates or deactivates itself*, both
already solvable in the Lua runtime but **not reachable from `mission.yaml`**:

1. **A QRA cannot start inactive.** Tripack tried `active_at_start: false` on a QRA
   definition. The key does not exist there (it is a **combat-zone** key,
   FEAT-COMBATZONE-ACTIVATE) so it was silently ignored: the generator always emits
   `:start()`, and every QRA is armed from mission start. There is no way to declare a QRA
   that waits for a radio command (`qra.start`) or a scripted trigger.

2. **A combat zone holding only BLUE units activates then deactivates ~1 min later.**
   Confirmed in the code — the completion check is hardcoded on the **red** count
   (`veafCombatZone.lua:1203`):

   ```lua
   if nbUnitsR == 0 then   -- "everyone is dead, let's end this mess"
   ```

   `nbUnitsB` is counted but only ever **logged**, never used to decide. So a zone with no
   red unit is "completed" on the first watchdog pass (`SecondsBetweenWatchdogChecks = 60`)
   → completion message + `desactivate()`.

   The runtime already has the escape hatch — `setCompletable(false)`
   (`veafCombatZone.lua:443`) skips scheduling the watchdog entirely — but **no YAML key
   exposes it**.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | QRA `active_at_start` (default `true`): when `false`, do not emit `:start()` | ✅ |
| 02 | Combat zone `completable` (default `true`): when `false`, emit `:setCompletable(false)` | ✅ |

## Why ticket 01 is safe

A QRA registers itself in `veafQraManager.qras` from `setName()` / `setDescription()`
(`veafQraCore.lua:229`), **not** from `:start()`. So an unstarted QRA:

- is still reachable by name — the `qra.start` radio action does
  `veafQraManager.get(name):start()`, so it can be armed later;
- is inert and safe — `humanBornEvent` (called on **every** registered QRA at each unit
  birth) returns immediately while `_enemyHumanUnits` is `nil`, which is the case until the
  first `:start()`.

## Out of scope

- Making the combat-zone **enemy coalition configurable** (the real subject behind
  problem 2: "red = enemy" is baked into the module). `completable: false` keeps a
  blue-only zone alive, but a zone that must *complete* when its blue units die still
  needs that work. Pending Tripack's answer on his actual intent; deserves its own lot.

## Definition of Done

- Both keys round-trip from `mission.yaml` to the generated Lua, defaults unchanged.
- Generator tests for on/off in both cases; docs (mission-maker QRA + combat zone, FR/EN)
  and the shipped `mission.yaml` default updated in the same lot.
- `ruff` / `mypy` / `pytest` green; CHANGELOG + version bump.

---

## 01 — QRA `active_at_start`

Status: ✅ done
Type: feat

### Behaviour

New optional key on a `modules.QRA.definitions[]` entry:

```yaml
- name: QRA_SYRIA_SOUTH
  active_at_start: false   # default true — the QRA waits for qra.start
```

- `true` / absent → unchanged (`:start()` emitted, current behaviour for every mission).
- `false` → the builder chain stops before `:start()`. The QRA is still registered (via
  `:setName()`), so a `qra.start` radio command or a scripted call arms it later.

### Tasks

- [x] Generator: skip the `:start()` line when `active_at_start` is `false`.
- [x] Tests: emitted by default / omitted when false / the rest of the chain unchanged;
      and the QRA is still named (so `qra.start` can find it).
- [x] Docs: `doc/mission-maker/scripts/veafQraManager.{md,en.md}` key table + example.
- [x] Default `src/defaults/mission-folder/mission.yaml`: document the key in the QRA block.

---

## 02 — Combat zone `completable`

Status: ✅ done
Type: feat

### Behaviour

New optional key on a `modules.COMBATZONE.combat_zones[]` entry:

```yaml
- zone_name: BLUE_DEFENCE
  completable: false   # default true — never auto-completes/deactivates
```

- `true` / absent → unchanged (the zone completes when no red unit remains).
- `false` → emit `:setCompletable(false)`; the runtime then never schedules its watchdog,
  so the zone stays active until something stops it explicitly.

This is what a blue-only zone needs today, since completion is hardcoded on the red count.

### Tasks

- [x] Generator: emit `:setCompletable(false)` when the key is `false` (nothing when true).
- [x] Tests: absent → no line; `false` → line emitted; `true` → no line.
- [x] Docs: `doc/mission-maker/scripts/veafCombatZone.{md,en.md}` key table, stating the
      blue-only symptom this addresses.
- [x] Default `src/defaults/mission-folder/mission.yaml`: document the key.
