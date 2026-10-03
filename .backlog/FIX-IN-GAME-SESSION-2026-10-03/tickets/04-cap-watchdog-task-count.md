# 04 — the CAP watchdog keeps adding tasks

Status: ✅ done — verified in game 2026-10-03
Type: fix

## Measured

A `-cap` MiG-29S pair, watchdog traced on 2026-10-03: `numberOfTasksAddedByWatchdog` read 38, 43, 49
on three consecutive passes ten seconds apart, while the CAP kept engaging the same targets. Nothing
seen removes a task the watchdog pushed.

The same passes kept as targets aircraft **105 km** from the CAP zone's centre: intended — a `-cap`'s
zone is 60 NM (111 km) unless the marker says otherwise (`veafSpawnAircraft.lua`, `capRadius or 60`).

## Why

Tasks really accumulated. Every tick pushed an `EngageUnit` for **every** target still tracked, so a
CAP tracking five aircraft stacked five more tasks every ten seconds. Two consequences worse than the
count:

1. no task could be taken back individually — `popTask` only removes the top — so a target leaving the
   zone kept its task and the CAP kept chasing it, weapons safe;
2. the cleanup popped as many tasks as it had counted, but DCS removes a dead target's `EngageUnit` by
   itself: the count ran ahead of the queue and the extra pops removed the **patrol route**.

## Done

- the controller is touched only when the set of targets changes; a change sets the patrol again
  (`veafAircraftSpawn.resumePatrol`: the role's stored route, its first point moved to where the
  leader is) and pushes one `EngageUnit` per target still there;
- a CAP outside its zone with tasks outstanding gets its patrol back the same way;
- nothing is popped any more;
- tests: one task for a target tracked over four ticks, the patrol handed back with nothing popped,
  its first point at the leader, a queue rebuilt around the target that stays, a CAP outside its zone
  giving up — each proven red under a sabotage of the fix.

## To see in game

That `setTask` followed by `pushTask` in the same frame keeps both, and that a CAP whose fight is over
flies its race-track again.

## Seen in game (2026-10-03, second pass)

Three `-cap` watched for seven minutes on the Caucasus mission: on a tick where the targets did not
change, **no** `EngageUnit` was pushed (this morning: five or six more each tick). When the C-130 left
the MiG-31's list, the queue was rebuilt in one go (six tasks) and the MiG-31 came back to 12 km from
its zone's centre. At At Tanf, the Sayqal MiG-29S fired six R-77 and an R-73 at an immortal intruder;
when it was removed, `resumes its patrol` was logged and the pair flew back over the zone centre
(ticket 06). Not seen: a new shot *after* a rebuild — the MiG-31 had most likely emptied its rails.
