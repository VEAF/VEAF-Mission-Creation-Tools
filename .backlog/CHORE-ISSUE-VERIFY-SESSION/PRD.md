# CHORE-ISSUE-VERIFY-SESSION — one DCS session to settle the twelve `verify` issues

Status: ✅ done — 2026-08-18. Twelve `verify` issues, twelve verdicts, in three sessions (A, B, C).
Seven lots came out of it; #245 moved to the smoke harness rather than a cockpit.

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

## Mission B — CAP behaviour — **runs on Mission A, there is no separate mission**

Discovered on 2026-08-17, after Mission A was built: the fork of `smoke-test-mission` already carries what
these two checks need — about a hundred `veafSpawn-*` templates on **both** sides, plus the `SPAWN`,
`SHORTCUTS` and `MOVE` modules. Both checks are marker commands, so they run in the mission already loaded.
No second folder, no rebuild.


| # | Issue | Gesture | What decides |
|---|-------|---------|--------------|
| 4 | [#240](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/240) `-cap` picks NATO units for red | Run `-cap` ten times on the red side, note the types | Any F-15C / F/A-18C on the red side = confirmed. Sharko's ask is a way to force the side's own inventory |
| 5 | [#209](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/209) `-cap` ignores its route | Give a CAP an explicit altitude, watch it fly | Flying at another altitude = confirmed. Check the altitude actually written into the group's route first — the defect may be in the writing, not the flying |

### Mission B outcome, 2026-08-17

Run by David on Mission A. Both checks answered, plus one false alarm worth recording.

- **#240 confirmed, and the cause is data rather than code.** A red-side `-cap` produced **7 NATO
  airframes out of 10** (4 M-2000C, 1 Mirage F1EE, 2 F-15C). Measured on the built mission: **14 of the
  36 shipped red templates are NATO cellules** — F1EE in eight variants, M-2000C in six. The selection
  is not misbehaving; it draws from a library where two red templates in five are Mirages. Those
  templates exist on purpose (credible training adversaries, hence the "EASY / Radar ON / ECM OFF"
  variants), but nothing lets a caller ask for authentically red. **This gives #284 the visible symptom
  it lacked**, so the two belong in one lot: template selection is opaque *because* a template carries
  a name and a coalition and no attributes.
- **#209 not reproduced, closed.** `alt 15000` gave an orbit at **15 800 ft** — a 5 % overshoot, the
  normal margin of an AI holding an orbit. David accepted it.
- **A false alarm to remember**: several `-cap` calls announced success with nothing visible, which
  looked like a silent spawn failure. Three theories were built on it — a missing `mist.goRoute`, an
  unchecked `dynAdd` return, a "Corrupt damage model" error in the log — and **all three were wrong**.
  The aircraft were spawning all along; they appear on their **orbit** rather than at the marker, and
  under load it takes seconds. David found it by reloading and seeing a sky full of CAPs. The only real
  defect left is that nothing tells the player *where* the CAP appeared, so they look in the wrong
  place and conclude failure — a small message improvement, not a bug hunt.

Method note, since it cost three rounds: `98` occurrences of "Corrupt damage model" were in that log,
starting before the mission even loaded. Correlating on the two nearest the symptom was coincidence
dressed as causation. **Count the occurrences before drawing a line between two of them.**

## Missions C and D — merged into one mission, built 2026-08-18

`test/veaf-tools/verify-mission-c/` covers checks **6, 7, 8, 9, 10 and 12** in one load. Mission B
had already shown that several checks ride on one mission; every check left here is driven from the
F10 menu or a map marker, so none of them needs its own. Its README carries the gesture and the
decision criterion for each. **Check 11 (#128) stays out**: it needs a real MP server with a
game-master client.

Two answers came out of building it, before DCS was launched at all:

- **#66 is confirmed by reading the code.** `veafShortcuts.ExecuteAlias` handles a `!30` delay with
  `mist.scheduleFunction` and returns immediately, so the `spawnedGroups` table the combat zone hands
  it is still **empty** when the zone iterates it (`veafCombatZone.lua:1117`). The group is never
  registered; deactivation cannot destroy what it does not know about. The zone was built with **two**
  fake units — `#command="-samsr!30"` and `#command="-samsr" #spawndelay=30` — so the session shows
  which mechanism leaks rather than just that one does.
- **Half of #87 too.** `rootPathBlue` and `rootPathRed` are created without a `coalitionSide`
  (`veafCarrierOperations.lua:922`) and the renderer only filters when that argument is set, so red
  sees the blue menu. The other half — "red cannot run its own" — looks already fixed, which matches
  RexAttaque's own test on the issue.

One deliberate configuration choice: **`veafSkynet.DynamicSpawn` is ON**. It defaults to `false`,
which the documentation already states means no dynamically spawned group joins a network — testing
#151 at that default would re-measure the doc. It is set through `mission.yaml`'s `module_settings:`
block, which lands in the generated Lua **before** `veafSkynet.initialize()`; `mission-script.lua`
would be too late, since initialize() is what reads it.

A defect met on the way, worth a ticket of its own: **`create_combat_zone` appends its
`combat_zones[]` entries after the trailing comment block** rather than next to the list, which
parses but reads as if the zones belonged to a different section.

### Mission C run, 2026-08-18 — first pass

| Check | Outcome |
|---|---|
| 6 (#151) | **answered: the mechanism works.** With `DynamicSpawn` on, a SAM spawned by a combat zone does join the red IADS. So #151 is a **configuration** defect, not a broken path: the option is off by default and is not exposed in `mission.yaml` at all. The fix is a YAML field plus documentation. |
| 7 (#261) | **CONFIRMED, with the whole chain measured.** It took three instruments to get there, and the first two were wrong: element state (`isActive`) reports whether a radar is emitting — a Skynet SAM stays dark by design, and `deactivate()` never touches that field anyway (`cleanUp` only strips scan tasks and event handlers), so David read the same thing before and after and said so twice. What settles it is wrapping the chain the code describes: `addGroupToNetwork` → `delayedActivate` → `_activateIADS`. Measured in game: a SA-15 spawned after deactivation joined the RED network and **reactivated it** (`group added (3) / delayedActivate (4) / REACTIVATED (1 since deactivation)`), with the BLUE network at 0 elements, ruling out the country default. MacFlorent's analysis holds. |
| 8 (#66) | **CONFIRMED** by David, matching the code reading: the `!30` delayed alias leaks its group. |
| 9 (#107) | **CONFIRMED** on the third attempt (the first two measured the mission's own defects: a SAM battery 17 km away, then `fuel = 0`). The respawned escort holds, then **leaves to land after ~10 minutes** — a delayed RTB, which a short observation would have called fixed. Cause proven: `veafAssets.respawn` never re-establishes the Escort task DCS destroys on respawn. → `FIX-ESCORT-RESPAWN-TASK` |
| 10 (#101) | **NOT REPRODUCIBLE — close it.** Teleported with `_move tanker, name Arco, teleport`, the escort stayed with the tanker for the 30 minutes David watched. The teleport path works *because* `veafMove.teleportEscort` rebuilds the Escort task with the new group id (`veafMove.lua:648`) — which is precisely what check 9 shows the respawn path failing to do. |
| 12 (#87) | **CONFIRMED** from the red A-10: a red player can start the *blue* carrier's operations. Cause already located: both carrier submenus are created without a `coalitionSide` (`veafCarrierOperations.lua:922`), and the renderer only filters when that argument is set. The other half of the issue — "red cannot run its own" — is already fixed. The first attempt also **answered #128**: no command at all in the Carrier menu as a game master, every one of them being `USAGE_ForGroup`. |

## Mission C — IADS (a Skynet network plus a combat zone holding a SAM)

| # | Issue | Gesture | What decides |
|---|-------|---------|--------------|
| 6 | [#151](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/151) combat-zone SAMs absent from IADS | Activate a zone containing a standard DCS SAM group; read the Skynet monitor | `veafSkynetIadsHelper` **does** add dynamically spawned groups (`:495-537`, `DynamicSpawn`); the question is whether a combat-zone spawn reaches that path |
| 7 | [#261](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/261) IADS deactivation | Deactivate a network, then spawn a SAM into it | The network coming back to life = confirmed. MacFlorent's analysis (`DynamicSpawn` is global, so switching it off is all-or-nothing) is on the issue and worth reading first |

## Mission D — escorts, delayed spawns, and the multiplayer pair

> Runs on `verify-mission-c` (see above), except check 11 which needs multiplayer.

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
- **A game master sees no `USAGE_ForGroup` command — that is issue #128, and it is reproducible
  solo.** The role itself works fine in single player (an earlier note here claimed otherwise, from a
  code reading of DCS's own Lua; David: "faux, ça marche très bien en solo"). What a game master does
  not have is a **group**, and `veafRadio` renders a `USAGE_ForGroup` command by adding it group by
  group — so it never appears for him. Measured on `verify-mission-c`, 2026-08-18: the Carrier menu
  is present and **empty** in game master, every one of its commands being `USAGE_ForGroup`.
  Consequence for every verification mission: **any check that goes through a `USAGE_ForGroup` menu
  must be run from an aircraft**, so ship a playable slot per side.
- **Pick that aircraft from the modules actually enabled on the machine.** `grep "plugin: SKIPPED"`
  in `dcs.log`: the Su-25T — chosen here precisely because it is free — is *disabled by user* on
  David's install, and the symptom is a slot you can select but not take ("je reste en vue carte").
  Use the generic **CJTF Red (id 81)** country for a red slot: it accepts any airframe, and it is
  what the project's own red templates use.
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

- [x] The twelve checks run, each with one of the three outcomes recorded on its issue
- [x] Check 1 (#245) taken out of the flying session and given its own lot,
      [`FEAT-SMOKE-CSAR-WATER`](../FEAT-SMOKE-CSAR-WATER/PRD.md) — checks 6 and 8 were answered in
      game instead, and both left instrumentation in `verify-mission-c` that their fix lots re-use
- [x] The `verify` label carries only what the follow-up lots need

## What the twelve became

| Issue | Verdict | Where it went |
|---|---|---|
| #232 rearm truck | confirmed | `FIX-FARP-ESCORT-PLACEMENT` (closed 2026-08-18) |
| #290 convoys | confirmed | `FIX-COMBATZONE-CONVOY-ALARM` (closed 2026-08-18) |
| #240 `-cap` picks NATO for red | confirmed — 7 NATO airframes out of 10, from a library where 14 of 36 red templates are Mirages | joins #284 |
| #209 `-cap` ignores its route | not reproduced (15 800 ft for a requested 15 000) | closed |
| #151 combat-zone SAM in IADS | the path works; the flag is invisible | `FIX-SKYNET-DYNAMICSPAWN-SCOPE` |
| #261 IADS deactivation | confirmed, whole chain measured | `FIX-SKYNET-DYNAMICSPAWN-SCOPE` |
| #66 delayed command | confirmed, cause in `ExecuteAlias` | `FIX-COMBATZONE-DELAYED-COMMAND` |
| #107 respawned escort | confirmed — RTB after 10 min | `FIX-ESCORT-RESPAWN-TASK` |
| #101 teleported escort | **not reproduced** — 30 min in formation | closed |
| #128 game-master menus | reproduced, unplanned | `FEAT-ROLE-AWARE-RADIO-MENU` |
| #87 red carrier ops | confirmed; second half already fixed | `FIX-CARRIER-MENU-COALITION` |
| #245 CSAR on water | never needed a pilot | `FEAT-SMOKE-CSAR-WATER` |

## What the sessions cost, and what that teaches

Three of the six mission-C checks first measured **the verification mission's own defects**: a tanker
parked 17 km from a SAM battery, then the same tanker spawned with `fuel = 0` by `add_air_group`
(twice attributed to the check under test), then a radio menu whose handlers a careless edit had
deleted. Two more measured the wrong thing entirely — an instrument reporting whether a radar was
emitting, when the issue was about whether a network gets reactivated.

The rule that came out of it, and that the next verification mission should start from: **instrument
the mechanism the issue names, not a symptom near it**. #261 was settled in one pass once the three
links the code describes — `addGroupToNetwork` → `delayedActivate` → `_activateIADS` — were each
counted, after two passes reading radar states got nowhere. The tooling defects met on the way are
in [`FIX-MCP-AUTHORING-GAPS`](../FIX-MCP-AUTHORING-GAPS/PRD.md).
