# Verification mission C — IADS, delayed commands, escorts and carriers (Syria)

Missions C **and** D of [`CHORE-ISSUE-VERIFY-SESSION`](../../../.backlog/CHORE-ISSUE-VERIFY-SESSION/PRD.md),
merged into one load. Mission B already showed that several checks ride on one mission; these five
are all driven from the F10 menu and a map marker, so none of them needs its own.

| Check | Issue | Question |
|-------|-------|----------|
| 6 | [#151](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/151) | Does a SAM spawned by a combat zone join the IADS? |
| 7 | [#261](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/261) | Does a SAM spawned into a **deactivated** network wake it back up? |
| 8 | [#66](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/66) | Does a **delayed** command's group survive the zone's deactivation? |
| 9 | [#107](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/107) | Does a respawned escort still follow its tanker? |
| 10 | [#101](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/101) | Does a **teleported** escort still defend? |
| 12 | [#87](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/87) | Can red run carrier ops, and can red stop blue's? |

**Check 11 (#128) IS here now, and the sentence that used to stand here was wrong.** It read *"it needs
a real multiplayer server with a game-master client; a solo session cannot answer it"* — which came from
reading DCS's Lua rather than from trying, and David refuted it the same day by taking the game-master
role in a solo session and finding the carrier menu **empty**. That is the reproduction of #128.

It was answered on **2026-08-20** by a probe carried here for one session, since deleted. The results
are in [`docs/exploration/DCS-UNATTACHED-PLAYER-ROLES.md`](../../../docs/exploration/DCS-UNATTACHED-PLAYER-ROLES.md);
see [check 11](#check-11) for what is left to measure.

## What was decided before launching DCS

Three things, so that the session measures what is worth measuring.

- **`veafSkynet.DynamicSpawn` is ON** (`module_settings:` in `mission.yaml`). It defaults to `false`,
  which the doc already says means *no dynamically spawned group ever joins a network* — testing #151
  at that default would only re-read the documentation. The question worth a DCS session is whether a
  combat-zone spawn reaches the dynamic path **when that path is on**. It is also what #261 assumes:
  its whole premise is a dynamically integrated group waking a network that was just deactivated.
- **#66 is already confirmed by reading the code**, and this mission is built to show *why*.
  `veafShortcuts.ExecuteAlias` handles a `!30` delay with `mist.scheduleFunction` and returns
  immediately, so the `spawnedGroups` list the combat zone passes in is **still empty** when the zone
  iterates it ([veafCombatZone.lua:1117](../../../src/scripts/veaf/veafCombatZone.lua#L1117)) — the
  group is never registered, and deactivation cannot destroy what it does not know about. The zone
  therefore carries **two** fake units, one per delay mechanism, so the session tells them apart.
- **Half of #87 is already answered too.** `rootPathBlue` and `rootPathRed` are created **without a
  `coalitionSide`** ([veafCarrierOperations.lua:922](../../../src/scripts/veaf/veafCarrierOperations.lua#L922)),
  and the renderer only filters when that argument is set — so red sees the blue menu. The other half
  of the issue ("red cannot run its own") looks fixed: `rootPathRed` exists and RexAttaque tested it.
  Check 12 is a confirmation by eye, not an investigation.

## Where things are, and why

Ground content stays at the smoke mission's anchor `(-32220, 405386)` — the empty-desert spot where
DCS reliably processes events. The carriers cannot: they need water.

| Object | Position | For |
|--------|----------|-----|
| `RedIadsEwr` — 55G6 EWR, red | `(-25000, 400000)` | the network that must exist at start |
| `RedIadsSa6Static` — SA-6 (1S91 + 2× 2P25), red | `(-26500, 401500)` | idem — the control element |
| `IadsZone` + `IadsZone-Sa6Dynamic` — SA-6, red | `(-29000, 400000)`, r=1200 | check 6 |
| `DelayZone` + two fake units | `(-29000, 410000)`, r=1200 | check 8 |
| `Arco` — KC-135, 3-point track at 20 000 ft | `(-90000, 380000)` — 67 km from the SA-6 | checks 9, 10 |
| `Arco escort` — 2× F-15C, **Escort task on its last waypoint** | `(-90500, 380300)` | checks 9, 10 |
| `CarrierBlue` — CVN-74 Stennis | `(63079, -36221)`, off Latakia | check 12 |
| `CarrierRed` — Kuznetsov | `(48000, -36221)`, 15 km south | check 12 |

Two naming rules are load-bearing, not cosmetic:

- the escort **must** be called `Arco escort`. `veafMove.teleportEscort` builds that name by
  concatenation ([veafMove.lua:570](../../../src/scripts/veaf/veafMove.lua#L570)) and gives up if no
  such group exists.
- its **last waypoint carries an enabled `Escort` task** pointing at Arco's group id. Without it
  `teleportEscort` returns false before doing anything, and check 10 would measure nothing. No MCP
  action writes that task — it is hand-written into `src/mission/mission`.

### The `VERIFY C` radio menu is an instrument, not a feature

`veafSkynet` exposes no deactivation command, and the only Skynet radio menu is the community
script's own status printout. So `src/scripts/mission-script.lua` adds three commands under
**F10 → VERIFY C**:

- **List RED IADS elements** — prints what the red network *actually holds*, element by element.
  This is what checks 6 and 7 are read from, rather than off a status page.
- **Deactivate RED IADS** / **Activate RED IADS** — the gesture #261 needs and that no menu offers.

They go away with the mission.

## Build it

```bash
veaf-tools mission build VerifyMissionC . --dev-mode --scripts-path <repo root>
```

Run `veaf-tools mission validate .` first — it is clean as shipped.

`security.disabled: true` is at the **root** of `mission.yaml` — a password prompt would make
`-samsr` unrunnable.

### Fly a slot — the game master cannot drive most of these checks

The game master role works fine in single player, but a game master **has no group**, and
`veafRadio` renders a `USAGE_ForGroup` command by adding it group by group. Every command in the
Carrier menu is `USAGE_ForGroup`, so that menu is **empty** for him — which is issue #128 itself,
reproduced on 2026-08-18. Use it for the map and for marker commands; take a slot for the rest.

| Slot | Side | Aircraft | Where |
|------|------|----------|-------|
| `VerifyPlayerCold` | blue | A-10C_2 | Bassel Al-Assad, stand 57 |
| `VerifyPlayerRed` | red | A-10C_2 | Palmyra, stand 5 |

Both are parked, engines cold. The red one is `CJTF Red` (country 81 — the generic side that accepts
any airframe) and exists for check 12: #87 asks what a **red player** sees in the carrier menu.
Both slots are A-10C_2 because that is a module David actually owns: the Su-25T is `disabled by
user` on his install (a disabled module gives a slot you can select but never take), and the C-101
plugin in the log turned out to be the AI-only build. Read `plugin: SKIPPED` in `dcs.log` before
picking an airframe — and do not infer ownership from a loaded plugin name.

## The protocol

### Before anything — the control reading

F10 → **VERIFY C** → *List RED IADS elements*.

You must see `RedIadsEwr` and `RedIadsSa6Static`. **If that list is empty, stop**: the red network
does not exist, and checks 6 and 7 would be measuring its absence rather than the thing they ask
about. Skynet initialises a few seconds after mission start — wait, then read again.

### 1 · #151 — is the combat-zone SAM in the network? (check 6)

1. F10 → Combat zones → **IADS Zone (#151)** → activate.
2. Wait ~10 s for the SA-6 to spawn.
3. F10 → VERIFY C → *List RED IADS elements*.

- **The SA-6 appears** (a name derived from `IadsZone-Sa6Dynamic`) → the dynamic path does catch
  combat-zone spawns. #151 is then a **configuration** defect: `DynamicSpawn` is off by default and
  is not exposed in `mission.yaml` at all. The fix is a YAML field plus documentation, not a rewrite.
- **It does not appear** → a real defect in the path. Next question for the lot that follows: does
  `mist.teleportToPoint` (how the zone respawns a group) raise the `S_EVENT_BIRTH` that
  `veafSkynet.OnDynamicSpawn` listens for, or does `isGroupUsable` reject the group?

### 2 · #261 — does a spawn wake a deactivated network? (check 7)

**Do not read an element's radar state for this.** `isActive()` reports whether that radar is
emitting, and a Skynet SAM stays dark on purpose until it has a contact — David measured the
consequence on 2026-08-18: "que ce soit activé ou désactivé, même compte". `SkynetIADS:deactivate()`
does not touch that state at all; it removes the scan tasks and the event handlers
(`SkynetIADSAbstractRadarElement:cleanUp`). The radar column in the menu is information, not evidence.

What the issue is actually about is visible in the code: `veafSkynet.addGroupToNetwork` ends with
`veafSkynet.delayedActivate(networkName)` (`veafSkynetIadsHelper.lua:794`), so integrating **any**
group schedules an activation of the whole network. The mission wraps `veafSkynet._activateIADS` to
count exactly that, and announces each one in game.

The menu reports the status **it** knows — Skynet exposes none, which is why comparing two listings
before and after deactivation showed the same thing twice.

1. VERIFY C → *List RED IADS elements* — the header reads `status:` and a `->` verdict line.
2. VERIFY C → **Deactivate RED IADS**.
3. *List* again: `status: DEACTIVATED from this menu, nothing has reactivated it since`.
4. Drop a map marker near the red IADS, text: `-samsr, country russia`.
5. *List* once more.

- **`status: REACTIVATED 1x since it was deactivated`**, and the verdict line says CONFIRMED →
  integration reactivated a network that was switched off, because `DynamicSpawn` is global. The
  in-game message `RED IADS REACTIVATED` fires at the moment it happens.
- **The element count grows but the status stays DEACTIVATED** → the SAM was integrated without
  waking the network. Worth recording: it narrows the issue rather than confirming it.
- **The new SAM does not appear at all** → nothing was integrated; that is check 6's territory, not
  this one.

### 3 · #66 — the delayed command's group (check 8)

1. F10 → Combat zones → **Delayed Command Zone (#66)** → activate.
2. Wait **30 s**. Two SAM batteries appear: one from `-samsr!30` (delay handled by the alias parser),
   one from `#spawndelay=30` (delay handled by the combat zone).
3. Deactivate the zone.

- **The `!30` one survives and the `#spawndelay` one is destroyed** → confirmed, and the cause is
  pinned: the delayed alias path never returns its group to the zone. That is the expected outcome,
  and the comparison is the reproduction to write on the issue.
- **Both are destroyed** → already fixed; close it citing what fixed it.
- **Both survive** → the defect is wider than the delay path; do not close, and say so.

### 4 · #107 — respawned escort (check 9)

1. Find Arco on the F10 map: KC-135 orbiting at 20 000 ft north-west of the anchor, two F-15C on it.
2. F10 → Assets → **Respawn Arco (KC-135)**.
3. Watch the escort for **more than ten minutes**.

!!! warning "Sixty seconds is not enough, and this step used to say sixty seconds"
    The failure is a **delayed** return to base: the escort holds formation for a while and *then*
    leaves, after roughly ten minutes. A one-minute look passes in both cases, so it would have called
    the old behaviour fixed. David watched the teleport path hold for thirty minutes on 2026-08-18;
    that is the bar.

- **It drifts off, goes home, or ignores the tanker** → confirmed. Worth knowing for the fix:
  `veafAssets.respawn` calls `mist.respawnGroup` on the tanker and then, separately, on each `linked`
  group — nothing re-points the escort task at the tanker's **new** group id, and RexAttaque's note on
  #107 says DCS destroys that task when the escorted group respawns.
- **It rejoins and holds formation** → not reproduced.

### 5 · #101 — teleported escort (check 10)

1. Drop a marker 30–50 km away, text: `_move tanker, name Arco, teleport`.
2. Watch the escort: does it follow? Does it react when threatened?
3. Then do it again **without** the flag: `_move tanker, name Arco` — the tanker flies there instead.

- **Escort correct when moved, broken when teleported** → confirmed, exactly as RexAttaque described.
- **Broken in both cases** → the defect is not about teleporting; record that, it changes the fix.

### 6 · #87 — red carrier operations (check 12)

Do this one from the **`VerifyPlayerRed` A-10C_2 at Palmyra** — not from the game master, who
sees none of these commands (see above).

1. F10 → Carrier operations.
2. Look at what is offered: a *Blue* submenu, a *Red* submenu, or both.
3. Try to start ops on the Kuznetsov; then try to **stop** blue's.

- **Red can act on the blue carrier** → confirmed, and the cause is already located (see above): both
  submenus are created without a coalition, so neither is filtered.
- **Red can run its own** → the other half of the issue is already fixed; say so when closing.

### 7 · #128 — what a game master and a spectator actually are (check 11) {#check-11}

**Answered for the game master on 2026-08-20** (DCS 2.9.28.26385, single player) — full write-up in
[`docs/exploration/DCS-UNATTACHED-PLAYER-ROLES.md`](../../../docs/exploration/DCS-UNATTACHED-PLAYER-ROLES.md).
In short: he is invisible to the scripting API and raises no event, yet the global **and** the
coalition-scoped menu paths reach him, while `USAGE_ForGroup` never can.

**Two things still worth a sample**, if the probe is ever rebuilt (it was deleted, per its ticket):

- **A spectator**, taking no slot. He has no side, so coalition scoping probably cannot reach him and only
  the global path could — a hypothesis, not a result.
- **A contrasting `humanGroups` reading with a slot taken**, so the zeros measured for the game master sit
  against a known-good value rather than standing alone.

## Recording the outcome

Per `CHORE-ISSUE-VERIFY-SESSION`, each issue gets exactly one of three:

- **confirmed** — the reproduction written on the issue; it becomes eligible for a lot
- **not reproducible** — say what was tried, and close it
- **already fixed** — close it citing what fixed it
