# CHORE-ISSUE-VERIFY-SESSION — one DCS session to settle the twelve `verify` issues

Status: 🧑 waiting-human — the whole lot is one in-game session; nothing here can be done at a keyboard.

Origin: `CHORE-GITHUB-ISSUE-TRIAGE`, 2026-08-17. After closing the thirteen that code reading could
settle and reclassifying four more, twelve issues carry the `verify` label — each one a behaviour a
grep cannot decide.

## Why group them

Twelve separate verifications means twelve mission loads. Grouped by what they touch, they need
**four** missions, and several answers fall out of the same flight. The point of this lot is that the
session is prepared *before* DCS is launched: each check below states the gesture, and what the
answer means. A session where you have to work out what to look at is a session that answers three
issues out of twelve.

**Prefer the smoke harness where it fits** (`FEAT-DCS-SMOKE-HARNESS`): checks 1, 6 and 8 are
assertable from a script rather than by eye, so they can become regression tests instead of one-off
observations.

## Mission A — ground placement (Syria, one marker, one FARP)

| # | Issue | Gesture | What decides |
|---|-------|---------|--------------|
| 1 | [#245](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/245) CSAR spawns on water | **Moved out of the flying session 2026-08-17** — see below | Needs no pilot |
| 2 | [#232](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/232) rearm truck misplaced | Place a **static** FARP, then `-farp` next to it | Compare with Sharko's screenshot on the issue: the truck sitting inside/behind the existing FARP |
| 3 | [#290](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/290) convoys never move | Activate a combat zone containing a convoy; watch 60 s | All vehicles stationary = confirmed. His proposed fix (a watchdog re-issuing the route) is in the issue |

### #245 needs no pilot, and should never have been in a flying mission

David has nothing to fly this in, and the check does not need it. The lot already noted #245 as
"assertable from the smoke harness" without drawing the conclusion: a script can call the CSAR
trigger at a position over the sea, read back the spawned group's position, and ask
`land.getSurfaceType` what is under it. Binary verdict, no aircraft.

Do it that way instead:

- a `csar-avoids-water` check in `FEAT-DCS-SMOKE-HARNESS`, asserting the spawn point is not
  `land.SurfaceType.WATER`
- run it at two positions: open sea (the reported case) and just off the coast (the interesting one,
  since `FEAT-SCENERY-AWARE-SPAWN` gave `veaf.findSpawnPoint` land awareness and the question is
  whether CSAR goes through it at all)
- a regression test rather than an observation, which is what the lot wanted for it anyway

**Mission A therefore covers #232 and #290 only.** Its client slot is an A-10C_2 inherited from the
smoke mission; if that module is not available either, the two remaining checks only need *a* slot —
change the type before building.

## Mission B — CAP behaviour (any theatre, red and blue templates present)

| # | Issue | Gesture | What decides |
|---|-------|---------|--------------|
| 4 | [#240](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/240) `-cap` picks NATO units for red | Run `-cap` ten times on the red side, note the types | Any F-15C / F/A-18C on the red side = confirmed. Sharko's ask is a way to force the side's own inventory |
| 5 | [#209](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/209) `-cap` ignores its route | Give a CAP an explicit altitude, watch it fly | Flying at another altitude = confirmed. Check the altitude actually written into the group's route first — the defect may be in the writing, not the flying |

## Mission C — IADS (a Skynet network plus a combat zone holding a SAM)

| # | Issue | Gesture | What decides |
|---|-------|---------|--------------|
| 6 | [#151](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/151) combat-zone SAMs absent from IADS | Activate a zone containing a standard DCS SAM group; read the Skynet monitor | `veafSkynetIadsHelper` **does** add dynamically spawned groups (`:495-537`, `DynamicSpawn`); the question is whether a combat-zone spawn reaches that path |
| 7 | [#261](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/261) IADS deactivation | Deactivate a network, then spawn a SAM into it | The network coming back to life = confirmed. MacFlorent's analysis (`DynamicSpawn` is global, so switching it off is all-or-nothing) is on the issue and worth reading first |

## Mission D — escorts, delayed spawns, and the multiplayer pair

| # | Issue | Gesture | What decides |
|---|-------|---------|--------------|
| 8 | [#66](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/66) delayed command not despawned | `#command="-samsr!30"` in a zone; activate, wait 30 s, deactivate | The SAM surviving the deactivation = confirmed. The plumbing exists (`addDelayedSpawner`, reset at `veafCombatZone.lua:605`), so this may already be fixed |
| 9 | [#107](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/107) respawned escort does not follow | Spawn a tanker + escort, respawn both | Escort ignoring the tanker = confirmed |
| 10 | [#101](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/101) teleported escort stops defending | Move the pair with `veafMove` | Escort neither defending itself nor the group = confirmed. RexAttaque notes moving instead of teleporting works — that is the comparison to make |
| 11 | [#128](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/128) game masters lack `USAGE_ForGroup` commands | **Multiplayer, as a game master**: open the F10 menu | Missing entries = confirmed. Needs a real MP slot, not a solo session |
| 12 | [#87](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/87) red carrier operations | As red, try to run carrier ops; then try to stop blue's | Being able to stop blue's, and unable to run your own = confirmed. The issue cites `veafCarrierOperations.lua` around line 836 |

## Two rules every verification mission obeys

Both learned the hard way on Mission A, on 2026-08-17, after David hit them in game.

- **Security off.** `security: { disabled: true }` at the **root** of `mission.yaml`, not inside
  `modules:`. A check that asks for a password is a check you cannot run — `-farp` is SENIOR_PILOT-gated,
  so verification #232 stopped at a prompt instead of placing a truck. Turn it on only when the security
  layer is itself what the mission verifies.
- **Player slots on the ramp, engines cold.** Never an air start. An air start puts the pilot in the air
  at load, flying the aircraft before he can look at what he was asked to check. Mission A shipped with an
  airborne A-10C_2 because a **fork inherits its source's defaults** — `smoke-test-mission` is airborne on
  purpose, being script-driven. Check the template's slot, not only what you add to it.

`add_player_slot` with `start: "ground-cold"` needs `parking`, `parking_id` and `airdrome_id` and refuses
to guess; they come from `veaf_libs/data/parking/<Theatre>.json`, whose `by_airbase` is keyed by airdrome
id **as a string**, each spot carrying `p` (parking number) and `t` (the `Term_Index` to pass as
`parking_id`).

## How to record the outcome

For each check, one of three:

- **confirmed** → the issue keeps `verify`, gains the reproduction in a comment, and becomes eligible
  for a lot. A reproduction written down is worth more than the original report.
- **not reproducible** → say so on the issue with what was tried, and close it. Five years of doubt
  is worse than a wrong closure that can be reopened.
- **already fixed** → close it citing what fixed it, the way the thirteen closed on 2026-08-17 were.

## Definition of done

- [ ] The twelve checks run, each with one of the three outcomes recorded on its issue
- [ ] Checks 1, 6 and 8 turned into smoke-harness assertions rather than one-off observations
- [ ] The `verify` label empty, or carrying only what a further session needs
