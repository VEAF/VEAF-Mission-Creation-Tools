# 02 — Nothing worth engaging sends the CAP back on patrol

Status: ✅ done

Type: fix · Files: `src/scripts/veaf/veafSpawnAircraft.lua`, `test/lua/test_veafSpawn.lua`,
`test/lua/dcs_mocks.lua`

## What was wrong

The watchdog had no notion of *nothing worth engaging*. Four separate defects made the branch that
hands the CAP back its patrol either unreachable or wrong, and together they are what "the patrol never
returned fire" looked like from the cockpit.

**1. The list held the wrong object.** A detection was registered as
`{ …, unit = unit }` where `unit` is the CAP's **own** aeroplane, the one whose radar saw the target.
So the freshness check —

```lua
not Unit.isExist(targetData.unit) or not targetData.unit:inAir()
```

— asked whether the patrol was still flying, not whether the enemy was still there. Visible in the
2026-09-01 log: a watchdog dumped its list of four freshly detected F-14s, every entry carrying the
same `unit.id_`, and threw all four away in the same tick it registered them.

**2. `foundTargets` was set before the entry was checked.** So a list holding nothing but stale
contacts still reported *"Watchdog has targets ! Allowing AA for CAP"*, lifted `PROHIBIT_AA`, went
weapons free, pushed **no** task at all, and skipped the cleanup. In the log that pattern —
"has targets" with no "Engaging target!" — repeats tick after tick for the same group.

**3. `seenAt` was never refreshed.** The redetection branch marked a contact old and left its first
sighting time in place, so a target tracked without interruption expired `CAP_WATCHDOG_DELAY * 2` after
it was first seen and came back as brand new on the next tick — the wall of "new detection of
targetName=Pilot #009" in the log — pushing a fresh `EngageUnit` onto an AI that was already attacking
it.

**4. The cleanup used `resetTask`.** Its own comment says *"taking care not to remove the original
task, which is to fly along the route"*, and it counted the tasks it had pushed for exactly that
reason. Then it called the one that removes everything. ED's own descriptions, from the vendored API
reference:

| Call | ED's description |
|---|---|
| `pushTask` | adds a task to the **front** of the queue |
| `popTask` | removes the **highest priority** task from the queue |
| `resetTask` | clears **all** tasks from the queue, causing controlled units to cease their current activity |

`resetTask` was never reached in the 2026-09-01 session (`numberOfTasksAddedByWatchdog` was 0 on every
cleanup), so this one is latent — but it sits in the branch this ticket exists to make reachable.

**5. The sort sorted nothing.** `targetsList` is keyed by DCS unit id, so it is a map: `#targetsList`
is 0 and `table.sort` on it returns immediately. The whole priority ladder above it — fighters first,
then bombers, drones, AWACS, transports, helicopters — decided the *value* of each target and then
never ordered anything by it.

## What was done

- the list holds the **target**, and the engage loop re-runs ticket 01's predicate on it;
- `seenAt` is refreshed on every redetection, along with the priority and the object;
- `engagedTargets` counts targets actually engaged. `PROHIBIT_AA` is lifted and weapons go free on the
  **first task actually pushed**, and when the count is zero the CAP gets its tasks back and returns to
  `PROHIBIT_AA` + return fire;
- the cleanup calls `popTask`, the inverse of the `pushTask` it is undoing;
- the entries are copied into a real array before being sorted, which is also what makes it safe to
  delete from the map while walking it.

## Definition of done

- [x] A sky holding nothing but parachutes leaves the CAP on patrol, air-to-air prohibited
- [x] A target still on radar is engaged on every tick and never expires under the CAP's nose
- [x] A target that is gone is dropped, and the CAP goes back on patrol
- [x] The cleanup takes back its own tasks and never clears the queue
- [x] Tests go through `startCapWatchdog`, not through the predicate alone
- [x] Tests red before the change, green after
