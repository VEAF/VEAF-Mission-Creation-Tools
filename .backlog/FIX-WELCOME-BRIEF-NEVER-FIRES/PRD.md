# FIX-WELCOME-BRIEF-NEVER-FIRES — the brief shipped dead

Status: ✅ done

Found in game on 2026-08-24, reported as "rien sur un aérodrome ni sur le Stennis". Confirmed fixed in
game the same evening.

## The defect

The welcome brief said **nothing at all**. Not a wrong message, not a message on the wrong slot — nothing,
on an airfield and on a carrier alike. The feature had shipped dead and no test noticed.

## Two causes, and the first fix was wrong

**First reading: the wrong event.** The brief subscribed to `S_EVENT_PLAYER_ENTER_UNIT` only, and DCS does
not raise that event when a single-player pilot occupies his starting slot. `veafGrass.onBirth` and
`veafQraManager.eventHandler` both take `S_EVENT_BIRTH` **and** `S_EVENT_PLAYER_ENTER_UNIT`, with a human
test, and have for years — this had invented a third answer instead of following them.

Adding the birth event **did not fix it**, and David reported "toujours pas de brief météo" on the rebuilt
mission. That mattered: it proved the diagnosis was incomplete rather than the fix being unlucky.

**Real cause: the timing, not the event name.** In single player the pilot occupies his slot *before* the
mission's scripts load, so his birth event fires before this module — load order **210** — can subscribe to
anything. An event that has already happened cannot be caught by subscribing to it. And changing slot
**restarts the mission** in single player, so the carrier attempt lost exactly the same race.

## The fix

The brief now **looks at who is already flying**, shortly after it initializes, instead of only waiting to
be told: it walks `mist.DBs.humansByName` and briefs every slot whose `getPlayerName()` answers. The
subscription stays, for pilots joining a running server later. Both paths share a `briefedUnits` table, so
nobody hears the runway twice.

The scheduling log line moved from `debug` to **`info`**: when a feature is silent in game the first
question is whether it was ever asked to speak, and a debug line cannot answer that from a default log.

## Mutations

| Mutation | Result |
|---|---|
| back to `S_EVENT_PLAYER_ENTER_UNIT` alone | 1 test fails |
| the human test removed | 1 test fails |
| the once-per-slot memory removed | 1 test fails |
| de-dup made global instead of per slot | 1 test fails |
| subscribes even when the setting is off | 1 test fails |
| empty slots briefed too | 2 tests fail |
| the sweep does not mark who it briefed | 1 test fails |
| already-briefed pilots swept again | 1 test fails |
| **the sweep never scheduled** | 1 test fails |
| **the subscription reverted** | 1 test fails |

**Two mutations killed nothing at first, and both were the same hole in the same place: the wiring.** Every
test called the handler — and later the sweep — *directly*, so nothing noticed when the module stopped
asking to be told, or stopped scheduling the sweep. Reverting the actual fix passed all 37 suites twice.
That is three times in one day that a mutation found this exact gap; it is now recorded in
`docs/agents/` territory rather than only here.

## Definition of done

- [x] The brief fires on an airfield — **confirmed in game**, 2026-08-24
- [x] The brief fires on a carrier and names the ship's heading rather than a runway
- [x] Lua tests covering both entry paths, the human test, and the once-per-slot rule
- [x] Tests that assert the **wiring** — the subscription and the scheduling — not only the handlers
