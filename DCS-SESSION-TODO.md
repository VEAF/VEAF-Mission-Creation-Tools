# What to do next time DCS is running

Everything the backlog is waiting on that **needs DCS started** — nothing here can be done from a
keyboard on a workstation without the game. Each item says what to run, what to look at, and what it
unblocks, so a session can be worked through without re-reading the whole backlog.

**Tick a line off by deleting it**, and update the ticket it names. The backlog indexes (`.backlog/README.md`)
stay the source of truth for scope and status; this file is only the running order for a session in front of
the game.

Written 2026-08-12, reordered 2026-08-14 when items 0 and 0b arrived — they gate a release, so they
come first.

---

## ⏱ RELEASE GATE — fixes that are shipped and nobody has ever seen work

Added 2026-09-01, taking the inventory of open lots. Several lots sit at `🧑 waiting-human` with
their **code already merged**: it will go out with the next release whether or not anyone looks at it.
Two of them had no entry in this file at all, so the wait had nowhere to end. Items are appended here
as later lots land in the same state, so read the list rather than a count.

Each item below states what to run, what to look at, and **what each of the two outcomes means** — a
check that cannot come out negative proves nothing.

**Session of 2026-10-03, flown without a pilot** — R1, R2, R3, R5, R9, R11, R12, R13, R14, R15, R16,
R18, R21, R22, R32 and the three French items on the cloned QRA, the zone SA-6 and the neutral slot
were run and are removed below; the results are in the lots and in
[`FIX-IN-GAME-SESSION-2026-10-03`](.backlog/FIX-IN-GAME-SESSION-2026-10-03/PRD.md). R7, R17 and R19
are rewritten to what is left. The missions are in `D:\dev\_VEAF\tmp\dcs-session-2026-10-03\`, with
the plan and a `fiddle.sh` that runs a Lua file in the live mission.

**Second pass prepared 2026-10-03 afternoon** — `D:\dev\_VEAF\tmp\dcs-session-2026-10-03b\`, built
from branch `fix/in-game-session-2026-10-03-followups`, plan in `SESSION-DCS-2026-10-03b.md`: the
#1054 colours and AirWaves fixes never seen in game, R7 (QRA half), R9 (the new floor), R17 (last
line), R19 (the escort beside its own props), and tickets 03, 04 and 06 of
`FIX-IN-GAME-SESSION-2026-10-03`. **Run the same afternoon**: R7 (QRA half), R17 (last line) and R19 passed and are removed below; the results are in those lots and in `FIX-IN-GAME-SESSION-2026-10-03`.

**Third pass, 2026-10-03 evening — the 6.27.0 release gate** —
`D:\dev\_VEAF\tmp\dcs-session-2026-10-03c\`, three missions built from `develop` (`d3823f7e`,
CTLD `2.0.0-rc12`), plan in `SESSION-DCS-2026-10-03c.md`, probes `probes\c_*.lua` run through
`fiddle.sh`. **Run the same evening**: R7 (wave half — each wave within 250 m of its offset), R34
(CTLD rc12 builds its menu and keeps a seated player) and R37 (the fixed CAP engages; without the task,
or with it after the orbit, it does not) passed and are removed; the results are in their lots.
R35 and R36 are rewritten to what is left, and the ticket 04 reconstruction is at the end of this file.
R38 needs a server, not the local game.

**Fourth pass prepared 2026-10-03 night** — `D:\dev\_VEAF\tmp\dcs-session-2026-10-03d\`, plan in
`SESSION-DCS-2026-10-03d.md`, probes `probes\d_*.lua`: every item left that needs no pilot. M1 is
GermanyCW rebuilt from `develop` (`ed94463b`) with `airbase_logistics_radius: 1100` — R39 and R36;
M2 is the Syria Open Training of 2026-08-30, unchanged — R4, measured by a probe instead of the editor.
**Run the same night, M1 only**: R39 (each call by the unknown name shows *introuvable*, no Lua error),
R36 (the C-130 on Ramstein stand #111, 997 m out, reads `EQUIPMENT (AB_Ramstein)`) and R4 passed and are
removed; GermanyCW turned out to have type-100 stands, so M2 was not needed. R4's answer — a C-130 on a
`100` is moved up to 1 473 m away or seated inside a hangar — is in `known-limitations.yaml`.

### R40. The welcome brief and the ATIS give the tower's frequencies — **no pilot needed**

[`FEAT-AIRFIELD-FREQS-IN-ATIS`](.backlog/FEAT-AIRFIELD-FREQS-IN-ATIS/PRD.md), tickets 02 and 03.
The lines are built from a table rendered at build time and from `veafAirbases.MissionChannels` in `veaf-config.lua`; the mocks prove the text, not that `Airbase:getID()` in DCS is the airdrome id the table is keyed by.

**Run** on a copy of Open Training Caucasus v6 built from the branch **before** its base channels are corrected (its `Base-Batumi` is on 270.3 where DCS's tower is 260.0), through `fiddle.sh`:
`return veafWeatherAtis.getAtisString(veafAirbases.getAirbaseByName("Batumi"))`, then the same for a field whose `bases` channel matches DCS, and for the carrier if the mission has one.
Then take a slot on Batumi, or call `veafWeather.buildWelcomeBrief(Unit.getByName("<a parked unit>"))`.

- **Verified**: Batumi's ATIS ends with `Tour 260.000 UHF / 131.000 VHF / 40.400 FM — TACAN 16X` — what Batumi's card shows in the F10 view — followed by `Canal de la mission …: 270.300 UHF …`; the matching field has one line; the carrier has none.
- **Re-opened, the key**: no `Tour` line on Batumi at all, or another field's frequencies — `getID()` does not answer the airdrome id in DCS; log `veafAirbases.getAirbaseByName("Batumi").DcsAirbase:getID()`.
- **Re-opened, the match**: the tower line right but no mission-channel line — read `veafAirbases.MissionChannels` in the live mission to tell a build that wrote nothing from a lookup that missed it.

**Then the silenced tower**: run `veaf.silenceAtcOnAllAirbases()` in the live mission and ask both ATIS again.
The ATIS records once an hour per field, so clear it first: `veafWeatherAtis.ListInEffect = {}`.

- **Verified**: Batumi now gives the mission channel alone (`Canal de la mission …`, no `Tour` line); a field with no `bases` channel still gives its `Tour` line.
- **Re-opened**: Batumi still shows `Tour 260.000 …` — `getRadioSilentMode()` does not answer `true` after `setRadioSilentMode(true)`; log it on the airbase.

### R35. Combat-zone ground units start warm — the thermal look

[`FIX-COMBATZONE-DEAD-UNIT-HAS-NO-GROUP`](.backlog/FIX-COMBATZONE-DEAD-UNIT-HAS-NO-GROUP/tickets/02-zone-defences-start-warm.md)
ticket 02. **The script half passed on 2026-10-03**: the five vehicles `combatZone_WahnerHeide_Easy`
handed DCS all carried `coldAtStart = false`. What DCS makes of it cannot be read by a script.

**Run** (session c, M3, `c_warm.lua`, slot `TEST-WARM A-10 TGP`): the zone plus three BMP-2 controls
600 m north of its centre, west to east `coldAtStart = true`, `false`, no key. Pod in white-hot:

- **Verified**: the `true` control dark, the `false` control bright, the zone's vehicles bright — and
  the `no key` control says what DCS does with a missing key.
- **Nothing concluded**: the three controls alike (the pod cannot tell at that range or hour).
- **Re-opened**: controls distinct but the zone's vehicles dark. A second look 15 min later says
  whether a warm vehicle cools standing still.

### R38. `/secu login` and a listed pilot on a live server — **needs a server, not the local game**

[`FIX-SECU-VERB-AND-LOG-NOISE`](.backlog/FIX-SECU-VERB-AND-LOG-NOISE/tickets/01-secu-login-promises-nothing.md)
ticket 01. The mission half shipped in 6.26.0; the hook half (`VEAF-Server-hook.lua` v2.7.1, sending
the pilot's level with every slot change) was copied by hand to all six servers on 2026-10-01. The
reported scenario needs a multiplayer server and a pilot listed in `veaf-pilots.txt`, which a local
single-player session cannot give.

**Run**, on any VEAF server running a 6.26.0+ mission: a pilot listed at level ≥ 10 takes a slot and
clicks a secured `+` combat-zone command **without any verb**; then, **still connected**, the mission
is reloaded and he clicks it again; then `/secu login` in chat. With `VEAF-REMOTE` and
`VEAF-SECURITY` at `debug`, the log shows which way in each click took.

- **Verified**: both clicks pass with no verb, no `took [...] with no known level` warning, and
  `/secu login` answers that there is no global login any more, pointing to `/secu elevate`.
- **Re-opened**: the click after the reload is refused (the slot was registered with no level —
  the hook's level did not arrive), or `/secu login` still announces "authenticated for 10 minutes",
  or the `unusable auth duration []` warning is back (an old mission or an old hook is loaded:
  check the version lines before concluding).

### R20. Does a departing player's slot change still arrive after DCS forgot the player, in 2.9.30?

Re-measures the known limitation `player-leaves-slot-after-dcs-forgot-the-player`
(`known-limitations.yaml`, measured 2026-09-30 on **2.9.29**). DCS 2.9.30.28536, released the same day,
says only *"Coalition change and aircraft Slot change events are corrected"* — which may or may not
be this ordering. Nothing breaks either way: `VEAF-Server-hook.lua` accepts a nil player info.

**Run**: no game needed, only the six VEAF servers running **2.9.30** for a day of ordinary play. Over
SSH, grep each instance's `dcs.log` for the disconnects and the slot changes that follow them, the same
count as the 2026-09-30 measurement (21 disconnects → 21 slot changes with no player info). Check the
version line at the top of each log first: a log still on 2.9.29 answers nothing.

- **Unchanged**: every disconnect is still followed by a slot change with no player info. Update
  `measured` to the date and add the DCS version to the symptom, then regenerate
  `docs/agents/dcs-runtime-traps.md` (`poetry run python -m veaf_libs.known_limitations`).
- **Changed**: the slot change arrives before the disconnect, or with the player info still readable.
  Record the new order in the entry, mark it fixed by DCS 2.9.30, and decide whether the hook's
  remembered-disconnect list is still needed.


**Partial reading, 2026-10-03 morning**: all six servers on **2.9.30.28536** since 2026-10-02 19:50.
Four disconnects overnight (private1 ×2, private2, public1): DCSServerBot logs `disconnect` then
`change_slot` in the same second every time — the order is unchanged. Whether the player info is nil
at the second call no longer shows in these logs (the hook writes it at `debug`). Four cases on a
quiet night: count again after an ordinary evening before touching `known-limitations.yaml`.

**Second reading, 2026-10-03 14:15**: five real departures since 2.9.30 (private1 ×3, private2,
public1), each `onGameEvent(disconnect)` then `onGameEvent(change_slot)` in the same millisecond, and
no `_playerDetails is nil` warning from the VEAF hook. Still unchanged, still few: an ordinary
evening is what is missing. The hundreds of `ASYNCNET … Client connect timeout` lines are aborted
connections, not players — do not count them.

### ✅ R23. How does DCS keep a scripted helicopter on the ground? — **run 2026-10-02**

**Result** (DCS session of 2026-10-02 15:49 UTC, `dcs.log` lines `HELITEST`, 5 min after the spawn):

| | Variant | What it did |
|---|---|---|
| A | `_spawn group` today | **refused**: `Mi-8MT MISMATCH DESCRIPTOR TYPE`, `Invalid Unit Module: "Mi-8MT"` — no group |
| B | `HELICOPTER`, no route | appeared 16 m up (ground height read as a height above ground), started its engine at once and **hovered 5–12 m up** for the whole 5 minutes |
| C | `TakeOffGround` | sat cold, started its engine at T+80 s, **took off at T+278 s**, landed at T+466 s (where, not measured) |
| D | `TakeOffGroundHot` | took off at T+11 s, flew off at ~50 m/s, landed at T+193 s (where, not measured) |
| E | `TakeOffGround` + `uncontrolled` | **stayed put** — on the ground, engine off, speed 0, the whole 5 minutes |

Only E keeps a helicopter on the ground. C and D behave alike once started: take off, fly about three
minutes, land. David, watching: C's rotor was still, then it started; D he never saw turning — which
the log contradicts (engine start at T+0, 54 m/s at T+90 s) unless D had already come back to its spot
when he looked. Positions were not logged, and the Tacview file is empty: `dcs.log.old` stops dead at
15:57:58 with no shutdown lines, so the session ended without Tacview writing it. Not worth a rerun —
the design takes E — but a rerun should log each helicopter's distance from its spawn point. Each of B–E logged `Error: Unit [Mi-8MT]: Corrupt damage model.`
on spawn, and all four kept `life=18` throughout — not investigated.

The original protocol follows.

Not a shipped fix but a **measurement**, which decides the design of
[`FEAT-HELICOPTER-SPAWN`](.backlog/FEAT-HELICOPTER-SPAWN/PRD.md) ticket 02
([#164](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/164)): a helicopter spawned by
`_spawn group` should sit where the marker is, and nobody knows which group data DCS keeps on the ground.

**Run**: `D:\dev\_VEAF\tmp\verify-helicopter-spawn\missions\Verify-Helicopter-Spawn_noon.miz` (built
2026-10-02 with 6.26.0, outside the repository; its script is `src/scripts/mission-script.lua` there).
Take the A-10C at Kobuleti and do nothing: **60 s after start** five Mi-8MT appear in a line on the
runway, 120 m apart, and a table is printed on screen every 15 s for 5 minutes — one line per variant,
`cat=1` meaning DCS sees a helicopter. `F10 Other… > HELITEST: relevé maintenant` prints it on demand.
Takeoffs, landings and crashes are printed as they happen. Everything also goes into `dcs.log`
(`grep HELITEST`).

| | Variant | What it stands for |
|---|---|---|
| A | `veafSpawn.doSpawnGroup("helotest")` | `_spawn group` as it is today: category `AIRPLANE`, speed 0, no route |
| B | category `HELICOPTER`, no route, altitude as `doSpawnGroup` writes it | fixing the category alone |
| C | one waypoint `TakeOffGround` | a cold helicopter on open ground |
| D | one waypoint `TakeOffGroundHot` | rotors running |
| E | `TakeOffGround` + `uncontrolled = true` | parked, waits for a start order |

**Read, for each letter, after the 5 minutes** (the last table, or `dcs.log`):

- `AGL=0`, `inAir=false`, `speed=0` all along: **it stays put** — a candidate for ticket 02.
- a `TAKEOFF` event or `AGL` rising: **it leaves** — it needs a task or the uncontrolled flag.
- `GONE`, a `CRASH` or `DEAD`: **it falls or is refused** — expected for A, and probably B, the altitude
  being read as a height above the ground.
- `not spawned` or a `… ERROR:` line: the group data was refused; the error text says why.

The answer to give is the five letters, each with what it did. Also say whether C and D look the same on
the ground (rotors stopped or turning).

### ✅ R33. An undamaged helicopter escorts a moving ground group — **run 2026-10-02**

**Result**: D took off from grass, kept its **20 life** to the end, and stayed **74 m to 2.9 km** from G
the whole drive, coming back close again and again (74, 136, 346 m) — circling the group within its 3 km
engagement radius. David, watching: "ça a l'air de bien fonctionner". `escort` ✅; R31 and R32 had been
spoilt by D hitting a map object as it took off from the runway.


R32's question again, without what spoilt it: D now takes off from grass away from the runway, where it
hit a map object in R31 and R32, and only G and D are in the mission. Expected: D's `from-escorted`
under ~2 km the whole way, and D's life staying at 20.

### ⚠ R32. A helicopter escorts a moving ground group — **run 2026-10-02, spoilt by damage**

**Result**: G drove ~2.9 km at 8 m/s; D was 262 m from it once and up to **6.4 km** in between — but D
was damaged from T+39 s (life 20 → 4), hitting a **map object** (a numeric scenery id) just after taking
off from the runway, as in R31, and David saw it **land at Senaki**: a damaged AI going home, not an escort
measured. C hit a map object too (T+49 s), and the tank again at T+217 s — `attack` ✅ twice. Hence R33.

The protocol was:


R31's mission with G driving to `ROUTE`, 3 km out on land (`_spawn unit, name M1126 Stryker ICV, dest
ROUTE`), so that D escorts a group that moves; HIT events now name what they hit; 20 minutes of
readings.

- **Fixed**: G's `from-spawn` grows as it drives, and D's `from-escorted` stays under ~2 km the whole
  way. `escort` is done.
- **D still wanders kilometres off**: `GroundEscort` does not hold a scripted helicopter on its group;
  `escort` leaves this lot for a known limitation.
- The HIT lines say what hit D and C around T+45 s in R31, if it happens again.

### ⚠ R31. Helicopters patrol, attack and escort — R30 with a passive target — **run 2026-10-02**

**Result** (21:39–21:49 UTC): **C** fired at T+160 s and T+174 s, hit twice, and the tank was gone at
T+197 s; it then circled 1.8–2 km from the target — `attack` ✅. **B** landed 16 m from `SHUTTLE`, took off
after its time on the ground and landed 100 m from home at T+570 s — a full shuttle ✅ (the next round not
watched). **A** looped as in R29 ✅. **D** came back near G now and then (460–590 m) but wandered up to
**7.2 km** from it in between — `escort` ❌ on a stationary group; `GroundEscort` is meant for a moving
convoy, not yet tried. Unexplained: D fell from 20 to 4 life around T+45 s and C from 15 to 13 around
T+60 s, each with a gun `HIT` of its own and no target logged. Hence R32.

### R31. Helicopters patrol, attack and escort — R30 with a passive target

R30's mission again, three placements corrected: the red tank spawned `alarm 1` (green: it does not
fire), A's engagement radius cut to 500 m (`capradius 500`) so it cannot reach the tank 1.1 km away, and
G moved to the other side of the runway, far from the tank. Read with R29's table below.

### ⚠ R30. Helicopters patrol, attack and escort — **run 2026-10-02, spoilt by the test's placements**

**Result** (21:07–21:12 UTC, events matched by group this time): the red tank, 200 m from G, opened
fire at T+11 s, **destroyed G** and hit D (life 4) and A. **A** fired at T+138 s and destroyed the tank —
an armed `patrol` engages a ground unit inside its zone ✅. **C** never fired: the tank was gone before it
was in a position to. **D** had nothing left to escort. **B** took off and landed at `SHUTTLE` as in R29.
Hence R31.

### R30. Helicopters patrol, attack and escort — the R29 mission corrected

Same mission, rebuilt: the red tank on open grass beside the far end of the runway rather than in a
village, G a real type (`M1126 Stryker ICV`), events matched by **group** name (R29 logged none), and
20 minutes of readings so B's shuttle goes round twice. Read it with R29's table below.

### ⚠ R29. Helicopters patrol, attack and escort — **run 2026-10-02, half-readable**

**Result** (20:53–21:08 UTC): **A** looped for 15 minutes 1.3–2.4 km from its point without drifting
— ✅. **B** landed **17 m** from `SHUTTLE`, stayed ~4 min 30, took off, landed **63 m** from home, and
was still down when the readings stopped — the `Land` task with a duration hands the route back ✅, the
second round not seen. **C** made attack passes down to 39 m and 750 m from the tank, which never lost a
point of life — the tank was hidden in a village (David's F10 capture) — then wandered 4 km off: not
readable. **G** and **D** were never spawned: `M1128` is not a DCS type, the script's mistake. No event
was logged: the script matched unit names against group names. Hence R30.

The protocol:

Tickets 05 and 06 of [`FEAT-HELICOPTER-SPAWN`](.backlog/FEAT-HELICOPTER-SPAWN/PRD.md): none of
`SwitchWaypoint` loops, `Land` with a duration, `EngageTargetsInZone` or `GroundEscort` is measured on a
scripted helicopter.

**Run**: `D:\dev\_VEAF\tmp\verify-helicopter-combat\missions\Verify-Helicopter-Combat_noon.miz` (built
2026-10-02 from the branch, `--dev-mode`). Take the A-10C at Kobuleti; **10 s after start** six real
marker commands run, and a table is printed every 15 s for 15 minutes (`grep HELITASK` in `dcs.log`).
Takeoffs, landings, shots, hits and deaths are printed as they happen.

| | Marker command | Expected |
|---|---|---|
| A | `mi24, task patrol` | `AIR`, `from-spawn` around 1 km for the whole run |
| B | `mi8, task patrol, dest SHUTTLE` (grass beside the far end of the runway) | `LAND` near `SHUTTLE` (`from-shuttle` < 100 m), `GND` ~5 min, takes off, `LAND` back home, and again |
| T | `T-72B, side red`, 3 km out on open ground | the target: `GONE` or a `DEAD` event once C has done its job |
| C | `ka50, task attack, dest TARGET` | flies to `TARGET`, `SHOT` events, T destroyed, then circles (`from-target` stays under ~2 km) |
| G | `M1126 Stryker ICV` beside the runway | the escorted vehicle, `GND` |
| D | `ah64, task escort, dest <G>` | `AIR`, `from-escorted` staying under ~2 km |

**What each outcome means:**

- **As expected**: tickets 05 and 06 are done.
- **B never takes off again after its first landing**: a `Land` task with a duration does not hand the
  route back; the shuttle needs another shape.
- **A or B stops after one pass**: the `SwitchWaypoint` loop does not hold.
- **C reaches the target and never shoots**: `EngageTargetsInZone` is not honoured (or the Ka-50's
  loadout is not what it uses) — the `SHOT` events say which.
- **D flies off or circles its spawn point**: `GroundEscort` is not honoured.
- **`NOTHING SPAWNED` or an `ERROR` line**: the command was refused — the text says why.

### ✅ R28. A transport helicopter lands on open ground — **run 2026-10-02**

The destination moved to grass 150 m beside the far end of the Kobuleti runway (182 m from the field's
reference point), to separate the landing from the forest. **Result** (20:25–20:29 UTC): D flew 1.2 km,
was down **30 m from its point** 90 s after taking off, and stayed down to the end. The `Land` task
works, an airfield next to the point does not divert it, and ticket 04 is done.

### ❌ R27. A transport helicopter sent into a forest lands in the nearest clearing — **run 2026-10-02**

**Result**: as R26 — D hovered 8–34 m up, 106–121 m from its point, for minutes. David, watching: it was
trying to land where it stood, over the open field next to the forest (F10 capture). The clearing search
does not help here: asked for 30 m, `veaf.findSpawnPoint` steps down to 10 m, and the DCS call under it is
a lottery (`disposition-getsimplezones-is-a-lottery`). Recorded as
`helicopter-hovers-at-a-forest-edge`. The protocol was:


R26 showed the `Land` task working — D flew to its point, slowed and tried to land — but the point was
in a forest, and it hovered over the forest's edge 110–130 m from it for minutes (David's F10 capture,
2026-10-02). The landing point is now moved to the nearest clearing within 300 m, 30 m clear, found by
`veaf.findSpawnPoint`. Same mission, rebuilt, **same forest destination** on purpose.

- **Fixed**: a `LAND` event, then `GND`, with `from-dest` under ~300 m (the clearing, not the point).
- **Still hovering**: the search found nothing usable or DCS still finds no room — read `from-dest`.

### ⚠ R26. A transport helicopter lands on its point, with a `Land` task — **run 2026-10-02**

**Result**: the detour to Kobuleti is gone — D flew straight to its point, slowed to 15 m/s at 199 m
from it and descended — but it did not land: 2 min 30 s hovering 10–28 m up, 110–130 m from the point,
which was in a forest. Hence R27.

R25 again, the mission rebuilt: the landing is now a `Land` **task** handed over by the cruise point,
500 m short of the destination — no waypoint of type `Land` any more. Same mission, same outcomes to
read as R25 below; D is the one that matters.

### ❌ R25. A transport helicopter lands on its point, on open ground — **run 2026-10-02**

**Result** (20:07–20:11 UTC, `HELITASK`): the destination was 2 851 m from Kobuleti, on land. D
flew to it, passed **193 m** from it at 59 m/s without slowing, turned back and landed on Kobuleti's
parking again (David, watching). So not the airfield under the point: the `Land` waypoint sends the
helicopter to the nearest field (`helicopter-land-waypoint-goes-to-the-nearest-airfield`). The role now
lands with a `Land` task — **R26**.

The original protocol:

R24 again, after two changes: the cruise now ends 500 m short of the landing point, and D's
destination is searched for by the script — 3 km from the runway, on land, more than 2.5 km from every
airbase (logged as `HELITASK HELIDEST x=… z=…, … m from <airbase>`). Same mission, rebuilt:
`D:\dev\_VEAF\tmp\verify-helicopter-tasks\missions\Verify-Helicopter-Tasks_noon.miz`. A, B, C and E are
there as a regression check.

- **Fixed**: D's `from-dest` falls without a loop, a `LAND` event, then `GND` with `from-dest` under
  ~100 m. Ticket 04 is done.
- **Lands, but far from the point**: the `Land` waypoint is not honoured on open ground either — the
  role needs another way to land (a `Land` task rather than a waypoint type).
- **Loops again**: the approach point is not enough; read `from-dest` against time in `dcs.log`.

### R24. A helicopter spawned from a marker parks, orbits and transports — **run 2026-10-02**

**Result** (DCS session of 2026-10-02 19:57 UTC, `dcs.log` lines `HELITASK`, read to T+5 min):

| | Command | What it did |
|---|---|---|
| A | `mi8` | stayed `GND`, speed 0 — ✅ |
| B | `mi24, task orbit` | airborne at T+15 s, circled 1.5–1.9 km from its point at ~150 m AGL — ✅, wider than the 1 km guessed below |
| C | `uh1, task orbit` | the same, 1.5–2 km — ✅ |
| D | `mi8, task transport, dest HELIDEST` | passed 291 m from the point at 150 m without descending, flew on 1.9 km, came back and landed **1 678 m from it, on Kobuleti's parking** (David, watching) — ❌ |
| E | `helopair, task orbit, alt 1000` | both Ka-50 airborne by T+36 s, ~300 m AGL, 1–2.3 km — ✅ |

D first read as two things: the cruise point sat right over the landing point (the cruise now ends
500 m short, `HELICOPTER_APPROACH`), and the destination was on an airfield. R25 showed the second
reading wrong: it is the `Land` waypoint itself that sends a helicopter to the nearest field.

The original protocol follows.

The checkpoint of [`FEAT-HELICOPTER-SPAWN`](.backlog/FEAT-HELICOPTER-SPAWN/PRD.md) ticket 04, before
`patrol`, `attack` and `escort` are written: none of the DCS tasks the roles use is measured on a
scripted helicopter.

**Run**: `D:\dev\_VEAF\tmp\verify-helicopter-tasks\missions\Verify-Helicopter-Tasks_noon.miz` (built
2026-10-02 from the branch `feature/FEAT-HELICOPTER-SPAWN`, `--dev-mode`; outside the repository, script
in its `src/scripts/mission-script.lua`). Take the A-10C at Kobuleti and do nothing: **10 s after start** (60 s until R25)
five real marker commands run on the runway, 120 m apart, and a table is printed every 15 s for
8 minutes (`AIR`/`GND`, height above the ground, speed, distance from the spawn point). Events —
takeoff, landing, crash, shots — are printed as they happen; everything also goes into `dcs.log`
(`grep HELITASK`).

| | Marker command | Expected |
|---|---|---|
| A | `_spawn unit, name mi8` | `GND`, speed 0, the whole 8 minutes |
| B | `_spawn unit, name mi24, task orbit` | `AIR` within ~15 s, then `from-spawn` staying under ~1 km at ~150 m AGL |
| C | `_spawn unit, name uh1, task orbit` | the same, unarmed |
| D | `_spawn unit, name mi8, task transport, dest HELIDEST` | takes off, `from-dest` falling, a `LAND` event, then `GND` with `from-dest` under ~100 m |
| E | `_spawn group, name helopair, task orbit, alt 1000` | two lines, both `AIR`, around 300 m AGL |

**What each outcome means:**

- **As expected**: the role works; ticket 07 records it, and 05–06 can be built on it.
- **`NOTHING SPAWNED` or an `ERROR` line**: the command was refused — the text after it says why.
- **`from-spawn` growing without end (B, C, E)**: the `Orbit` task does not hold a scripted helicopter;
  the route needs another shape.
- **D never lands, or lands far from `HELIDEST`**: the `Land` waypoint is not honoured on open ground.
- **A takes off**: `uncontrolled` stopped holding it — R23 said otherwise, so read `dcs.log`.

The answer to give: the five letters, each with what it did.

---

---

## ✅ SETTLED — there was no DCS SAM bug (2026-08-22)

**Ground SAMs fire in 2.9.28.26385.** Measured twice on a bare map with no scripts whatsoever:

| Control test | Result |
|---|---|
| Three **SA-15 (Tor 9A331)**, red, alarm red, ROE fire-at-will | locked and fired |
| A complete **SA-6** — 2 × `Kub 1S91 str` + 4 × `Kub 2P25 ln` **in one group** — alarm red, ROE fire-at-will | **fired** |

So the theory this page carried for two days — *"ground SAMs do not engage at all in the current DCS
build"* — was wrong, and the second test is what closes it: the SA-6 is the multi-unit family, the one
whose launchers depend on a separate tracking radar, and it engages normally.

### What the first attempt at that test taught, which is the transferable part

The SA-6 control test **failed on its first run**: locked, launchers inert. The mission had the six
vehicles in **six separate groups**, one unit each. In DCS a SAM site *is* a group — the group's
controller is what hands a target from the radar to a launcher. Four launchers alone have no radar and
never fire; a lone `1S91` has its own radar and locks perfectly with nothing to command. That is
precisely what was seen, and it is indistinguishable from "DCS is broken" unless you look at the group
structure.

Which raises a question worth putting to Sharko rather than assuming: his report was *"j'ai reproduit le
bug sans script aucun, juste 3 sams sur une carte"*, with no mention of how they were placed. If they
were dropped as individual units — the natural thing to do when throwing a quick test together — his
mission had no SAM sites in it at all. **Unverified**, and his to answer.

### What this moves onto us

The cycling seen inside `verify-mission-c` — the SA-6 locks, slews, elevates, then returns to travel
state, five times, without firing — is therefore **ours**. A site that behaves correctly with no scripts
and stands down mid-engagement with Skynet running is being switched off by Skynet. See
[`FIX-SKYNET-SITE-GOES-DARK-BEFORE-FIRING`](.backlog/FIX-SKYNET-SITE-GOES-DARK-BEFORE-FIRING/PRD.md).

It also reopens **Tripack's** report of silent zone SAMs on 6.15.2, which had been filed under "DCS is
broken for everyone". It never was.

Items **11** and **16** are fully measurable, with no double reading and no caveat.

## The session mission — built 2026-08-27, twice corrected 2026-08-28

`D:\dev\_VEAF\tmp\dcs-session-2026-08-27\` — **load
`missions\VEAF-session-2026-08-27-escortfix_noon.miz`**, the newest of the three. Caucasus, noon,
`language: fr`, security off, built with `--dev-mode` against the repository so it carries fixes no
release has yet.

Items 21, 22 and 10 were all run on it on 2026-08-28 and are closed — item 21's counts are recorded in
[`FIX-PLACEMENT-IGNORES-SCENERY` ticket 04](.backlog/FIX-PLACEMENT-IGNORES-SCENERY/tickets/04-refuse-the-farp-when-the-escort-cannot-be-placed.md),
item 22's answer in the `scenery-death-events-in-dcs` note and in `DROP-MIST` ticket 09. What remains
here is the mission itself, still the right one to load for anything needing a live VEAF mission on
Caucasus.

⚠️ **Two defects of the 27th's build, both fixed on the 28th — do not reintroduce them.**

1. **It carried two VEAF configurations.** `src/scripts/` held the demo mission's v5 `missionConfig.lua`
   (59 KB, `MISSION_NAME = "VEAF-Demo-Mission"`) *next to* the generated `veaf-config.lua`. Both ran, so
   every module initialised twice and **every radio submenu appeared twice**, the second one inert —
   19 submenus under the VEAF root where there should be 9. Deleting `missionConfig.lua` and rebuilding
   fixed it, confirmed by probing the live menu tree. The repository's own demo mission
   (`test/veaf-tools/demo-mission/src/scripts/`) is clean; the stale file came from extracting a v5
   `.miz`. **Anyone converting a v5 mission will hit this** — worth a guard of its own.
2. It was built before the `findEscortTask` fix, so item 10 could not pass on it.

**The item 10 control is built in and worth keeping**: one escort is named `Arco escort` (matching the
`<asset name> .. " escort"` convention, [`veafMove.lua:37`](src/scripts/veaf/veafMove.lua)) and the other
deliberately left as `Arco-escort1`, so a run can tell a working repair from a silent no-op.

⚠️ **The folders for items 3 and 4 are gone.** `dcs-session-2026-08-14` and `dcs-session-2026-08-24` no
longer exist; `tmp/` holds only the Foothold archives, now **4.7.0** where item 4's text targets 4.4.1.
Those two need rebuilding before they can be run — see `LIRE-MOI.md`.

⚠️ **`mission extract` → `mission build` does not round-trip.** The demo `.miz` stores its members under
lowercase `l10n/default/`, the extractor reproduces that faithfully, and the builder demands
`l10n/DEFAULT/` — it aborts with *"These components are missing … they are mandatory in a DCS
mission!"*. Renamed by hand for this session; worth a lot of its own, since a repository test mission
triggers it.

## An older mission, for items 0 and 0b — both since closed

`D:\dev\_VEAF\tmp\dcs-session-2026-08-14\TestMenuFR.miz` — Caucasus, `language: fr`, with the modules
that build menus (RADIO, SPAWN, COMBATZONE, ASSETS, WEATHER, NAMEDPOINTS, MOVE, TRANSPORTMISSION,
CASMISSION, SHORTCUTS, SECURITY) and security **left on**.

**It embeds the repository's scripts, not the published ones**, and that matters: release 6.13.0 has
none of these fixes, so a mission built the ordinary way would show the old behaviour and read as
"the fix does not work". Verified before shipping it here — the embedded bundle contains
`ZONES DE COMBAT`, `APPARITION`, `Activer la mission` and `menu.combatzone.root`, and its
`veaf-config.lua` declares `veaf.config.language = "fr"`.

**Utiliser `TestMenuFR-fixed.miz`**, à côté, et non `TestMenuFR.miz` : la première corrige les trois
défauts mesurés le 2026-08-15 sur la seconde — l'A-10 marqué `dynSpawnTemplate`, sa radio coupée, et un
démarrage à 03:48 ([ticket 04](.backlog/archive/FIX-SCRATCH-MISSION-PLAYABLE.md)). Tout
le reste est identique, octet pour octet.

Rebuild it, if needed, with:

```bash
veaf-build build --version 6.13.100 --skip-python
```

then from the mission folder:

```bash
veaf-tools mission build TestMenuFR . --dev-mode --scripts-path D:/dev/_VEAF/VEAF-Mission-Creation-Tools
```

## ✅ 0. The F10 menu reads French — verified in game 2026-08-14

David, in front of the game: the labels are correct. The 90 localised labels of
[`FIX-RADIO-MENU-I18N`](.backlog/archive/FIX-RADIO-MENU-I18N.md) are confirmed, and the release is no
longer gated on this. Kept as a line rather than deleted because it is the release's evidence.

## ✅ Le slot A-10 du 2026-08-14 : `dynSpawnTemplate`

David, en jeu : *"je le prends, et je reste spectateur"*. Le différentiel contre l'A-10 qu'il a ajouté
lui-même dans l'éditeur (mission `-david`) donne :

| | mon script (ko) | éditeur (ok) |
|---|---|---|
| `dynSpawnTemplate` | **`true`** | **`false`** |
| `communication` / `frequency` | `false` / 121.5 | `true` / 251 |
| `skill` | `Client` | `Player` |
| ids | 9001 | 9003 |
| parking | `43` / `16`, `airdromeId` 24 | `6` / `01`, `airdromeId` 22 |

`dynSpawnTemplate = true` ne décrit pas un slot : il désigne le groupe comme **modèle de spawn
dynamique**, ce qui suppose une base aérienne configurée pour ça — cette mission n'en a aucune. J'avais
copié le groupe depuis la démo avec son drapeau. David l'avait dit dès le premier jour : *"il n'y a que
des templates de groupe, et pas de base aérienne configurée pour les slots dyn"*.

**`skill` est innocenté** : David, 2026-08-15 — *"c'est pas le slot Client ; ça fonctionne dans une
mission DCS"*. Les ids forcés aussi (l'éditeur écrit 900x lui-même), et la paire parking, complète des
deux côtés. Consigné dans
[`FIX-SCRATCH-MISSION-PLAYABLE` 03](.backlog/archive/FIX-SCRATCH-MISSION-PLAYABLE.md).

**`TestMenuFR-fixed.miz`** corrige les trois défauts (drapeau, radio, midi), et **le slot a été pris en
jeu le 2026-08-15** — *"le A-10 fonctionne"*. Le correctif est donc mesuré, pas supposé, et cette
mission est celle à utiliser pour la suite de la session.

### ❌ R6. A FARP escort on clear ground must not move — **run 2026-09-01, negative**

**Run 2026-09-01: the escort moved on all three markers, open ground included.** The guard's line
never appeared. Instrumented in #898, twelve decisions gave gaps of 43.9 m to 127 m against a 12 m
clearance — the condition cannot hold, because `Disposition.getSimpleZones` samples at random rather
than tessellating. `FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND` is reopened with these numbers, and its
ticket 03 replaces the method. **Re-run this item once that lands.**

Unblocks [`FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND`](.backlog/FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND/PRD.md)
(shipped 2026-09-01) and item 04 of `FIX-PLACEMENT-IGNORES-SCENERY`. **Written up as item 25 at the
end of this file** — three markers, and the point worth repeating here: *a run where nothing moves in
any of the three is a failure, not a pass*. It would mean the fix turned tier 1 off.

### ✅ R8. Does a teleported escort hold formation — and does it engage? — **both yes, 2026-09-01**

Gates [`FIX-TELEPORT-ESCORT-WAYPOINT`](.backlog/archive/FIX-TELEPORT-ESCORT-WAYPOINT.md), which cannot be
started without this. Nothing shipped depends on it: this morning's escort fix
(`FIX-ESCORT-RESPAWN-DISTANCE`, #882) respawns the escort and repairs the task, and never touches the
teleport path's waypoint arithmetic.

**Why it needs measuring rather than reading.** The repository tells two stories. In the code, right
after the call that is supposed to make the escort escort:

```lua
veafMove.replaceMission(unitGroup_escort, EscortData)
--this method appears to not work very well, the escort just doesn't defend the group
```

And `FIX-ESCORT-RESPAWN-TASK`'s PRD says the opposite — *"works (escort held for 30 min)"* — and used
this path as the reference the respawn path was ported from. **They are not actually contradictory**:
an escort can fly formation for thirty minutes without ever engaging anything. Which is why this is
**two** observables and not one.

**Run**: on the session mission, drop a map marker somewhere clear and type

```
_move tanker, name Arco, teleport
```

Then watch two things, separately:

1. **Formation** — does the escort end up with Arco and stay with it?
2. **Engagement** — bring a threat to the pair (a `-spawn` fighter, or fly at them red) and does the
   escort actually engage it?

**What each answer means.** Four combinations, and they do not lead to the same repair:

| Formation | Engages | What it means, and what the lot then does |
|---|---|---|
| yes | yes | the path works; the code comment is wrong and gets deleted, and the lot is only the waypoint arithmetic |
| yes | **no** | **both notes are true** — the author was right about engagement, `RESPAWN-TASK` right about formation. The Escort task is being written to a waypoint that is not the one carrying it: the arithmetic *is* the defect, and finding 2 of the PRD is the whole fix |
| no | yes | unexpected; record exactly what was seen before anyone theorises |
| no | no | the path has never worked. The answer is probably to rebuild it on the respawn mechanism shipped in #882 rather than correct its waypoints — and the ASSETS / MOVE pages need updating |

**The control that is already built into the mission**, worth using here too: one escort is named
`Arco escort` (matching the `<asset name> .. " escort"` convention) and the other is deliberately left
as `Arco-escort1`. So a run can tell a working repair from a silent no-op — only the first is ever
found by name.

**Answered in game 2026-09-01, on the session mission's Arco: formation yes, engagement yes.** Every
escort engaged a threat brought to the pair. That is the first row of the table above — *the path
works* — so the code comment claiming the escort "just doesn't defend the group" was wrong and has
been removed, and `FIX-ESCORT-RESPAWN-TASK`'s PRD was right all along. The repository tells one story
now.

What remains is finding 2 only: the rewrite still targets the **last** waypoint, while `findEscortTask`
searches every one of them because the demo mission puts the task on waypoint 2 of 3.

**What to write down**: the mission, the date, and the two answers. Whichever of the two notes turns
out wrong gets corrected in the code comment *and* in `FIX-ESCORT-RESPAWN-TASK`'s PRD — the point of
this item is that the repository stops telling two stories.

### Reste de la session

- **0b** — l'avertissement de dépréciation dans `dcs.log`, qui doit être **absent**.
- **1** — la capture parking, 5 min par carte. Débloque le ticket 09 *et* la moitié au sol du slot
  joueur.
- Les items 2 à 8 inchangés ci-dessous.

---

## ✅ 0b. Les deux correctifs de sécurité — vérifiés en jeu 2026-08-15

Tous deux issus de [`FIX-DOCAUDIT-CODE`](.backlog/archive/FIX-DOCAUDIT-CODE.md) (PR #730). Gardés comme
preuve de release plutôt que supprimés.

- **Les noms de paliers passent.** `dcs.log` ne contient **aucun** avertissement de dépréciation — la
  migration des 24 déclarations vers `ADMIN` / `SENIOR_PILOT` / `KNOWN_PILOT` est donc complète. Le
  message qu'on cherchait est celui de [`veafSecurity.lua:112`](src/scripts/veaf/veafSecurity.lua:112),
  émis une seule fois par ancien nom rencontré.
- **`_transport` et le pilote listé.** Éprouvé le 2026-08-14 : la commande refuse bien, et l'essai a
  fait tomber un **second** défaut — le message affiché trois fois — corrigé depuis par la PR #735.

⚠️ **#735 n'est pas dans `TestMenuFR-fixed.miz`** : cette mission embarque les scripts du dépôt tels
qu'ils étaient le 2026-08-14, donc avant ce correctif. Pour vérifier que le message ne s'affiche plus
qu'une fois, reconstruire la mission d'abord.

## ✅ 1. La capture parking — faite le 2026-08-15

Caucasus, Syria et PersianGulf : **276 aérodromes, 6521 places**, dans
`veaf_build/dcs_data/airbase_dumps/parking/`. Le ticket
[08](.backlog/archive/FEAT-MCP-MUTATION-ACTIONS.md) est clos.

Ce que la donnée a **révélé, et qui bloque le 09** : `Term_Index_0` vaut `-1` sur les 6521 places,
donc `parking_id` **ne vient pas** de cette capture — voir l'item 9 ci-dessous. Au passage, `Term_Type`
change de jeu de valeurs d'une carte à l'autre (PersianGulf n'a aucun `68`, Syria est seule à avoir
`100`). D'autres cartes peuvent être capturées à l'identique : `tmp\bridge-maps\collect\` contient
aussi des missions pour GermanyCW, MarianaIslands, Normandy et SinaiMap.

## 🔎 9. D'où vient `parking_id` ? — débloque le ticket 09

[`FEAT-MCP-MUTATION-ACTIONS` 09](.backlog/archive/FEAT-MCP-MUTATION-ACTIONS.md)
(*"un deux-ship de F-16 sur la ramp à Incirlik"*) a besoin de `parking` **et** `parking_id` pour un
départ au parking. La capture donne `parking` (= `Term_Index`) et la **position exacte** du stand, mais
**pas** `parking_id` (`Term_Index_0` = -1 partout, et les paires parking/parking_id des vraies missions
n'ont aucune fonction dérivable). David, 2026-08-15 : investiguer d'abord, ne rien deviner.

Deux mesures à faire, dans cet ordre :

1. **D'où sort `parking_id`.** Dans l'éditeur, poser 3-4 avions sur des stands **connus** d'un même
   aérodrome (p. ex. Kobuleti), sauver, et me donner pour chacun `(parking, parking_id)` + le stand
   visé. Je corrèle à `Term_Index` et à la position de la capture : soit `parking_id` correspond à
   quelque chose de capturable (alors on étend la capture du ticket 08 pour le sortir), soit il est
   interne à l'éditeur et il faut l'obtenir autrement.
2. **Est-il indispensable si la position est exacte ?** Je te prépare une mission bâtie via
   `add_player_slot` avec la position + `parking` capturés et `parking_id` = `parking` ; tu la charges
   et tu regardes si l'avion se pose sur le bon stand. Si DCS se cale sur la position quoi qu'il
   arrive, un départ ramp n'a pas besoin du vrai `parking_id` et le 09 est débloqué tel quel ; s'il
   déplace l'avion ou refuse, le 09 attend le vrai `parking_id` de l'étape 1.

Rien à lancer côté outils pour l'étape 1 (c'est de l'éditeur) ; pour l'étape 2 je fabrique la mission
quand tu me diras que tu es en jeu.

## ✅ 2 et 2b — faits le 2026-08-15

Les deux aller-retours dans l'éditeur ont eu lieu. Résultats consignés dans
[`FIX-MCP-EDITOR-ROUNDTRIP`](.backlog/archive/FIX-MCP-EDITOR-ROUNDTRIP.md) (4 tickets) et dans le
[ticket 07](.backlog/archive/FEAT-MCP-MUTATION-ACTIONS.md), qui donne naissance au
[ticket 10](.backlog/archive/FEAT-MCP-MUTATION-ACTIONS.md).

Ce que l'éditeur a **gardé** : le groupe déplacé de 6 km avec sa route, le renommage, l'emport, la
ligne et l'étiquette sur la couche Blue, le waypoint retiré avec son reverrouillage d'heure — et la
**zone à 6 sommets**, ce qui tranche une question ouverte : `edit_zone` ne doit pas se mettre à
refuser au-delà de 4.

Ce qu'il a **jeté** : la tâche `Bombing`, écrite avec 6 paramètres là où une vraie en porte 11.

Ce qu'il a **recalculé** : le cap d'un avion en vol, remplacé par l'`atan2` du premier segment de sa
route, à la septième décimale. DCS recalcule, il ne casse rien.

Les cinq formes de dessin sont mesurées (`bridge-Syria-editeur.miz`) — et il y en avait cinq, pas six.

Ce qui reste de l'item 2, non fait : **voler** la route avec sa tâche d'attaque (l'éditeur l'ayant
supprimée, ça attend le correctif du ticket 01), et le rebuild qui confirme qu'un dessin survit à une
reconstruction depuis le dossier.

<details>
<summary>Consigne d'origine de l'item 2, conservée pour le prochain aller-retour</summary>

## 2. Open a mutated mission in the Mission Editor

The acceptance criterion of
[`FEAT-MCP-MUTATION-ACTIONS` 02 and 03](.backlog/archive/FEAT-MCP-MUTATION-ACTIONS.md), and the only half
no test can cover — `FIX-MAPRESOURCE-KEY` is what a plausible-looking write the editor rejects costs.

Take any built `.miz`, then through the MCP (or a Python call):

- `set_unit_properties` — change a loadout and a heading on one aircraft.
- `set_group_properties` — move a group **that has a route** a few km, and rename another.

Then open it in the ME and **save it**. What to watch for: no complaint on load, the moved group's
route still attached to its units, the loadout as asked, and — the one that would be silent — the
group still where you put it after the save.

Four more edits ship in the same lot and want the same pass, each with one thing that could be
silently wrong:

- `edit_route` — add a waypoint with an **attack task**, then *fly it*. The editor accepting a task
  table is not proof DCS runs it, and a flight that quietly does nothing is this ticket's worst case.
  Also remove the route's only ETA-locked waypoint and check the mission still **saves** (the action
  re-locks the first, which is what `FIX-WAYPOINTS-ETA-LOCKED` says DCS itself does).
- `edit_zone` — reshape a combat zone into a polygon with **more than four vertices**, save, reopen.
  The VEAF runtime handles any polygon through mist, but the ME has **no UI** for a non-quad zone, so
  whether it preserves or flattens the shape is unknown. If it flattens it, the action should refuse
  above four rather than warn.
- `add_map_drawing` — place a line and a textbox on the **Blue** layer, and check red cannot see them.
- The **rebuild**: build the mission from its folder again and confirm the drawing is still there. That
  is the entire reason drawings are not left to the editor.

## 2b. Measure the five drawing shapes that no mission here contains

`FEAT-MCP-MUTATION-ACTIONS` ticket 07 ships three shapes — line, rect, textbox — because those are the
only field layouts present in any `.miz` in this repository. `circle`, `oval`, a free-form `Polygon`,
`arrow` and `icon` are **refused by name** rather than guessed, since inventing a layout is
what `FIX-MAPRESOURCE-KEY` and `FIX-COMMUNITY-SOUNDS-PRUNED` both cost.

**It was six until 2026-08-15**, when David opened the editor and found no `chevron` tool. That name
came from a table of proposed verbs, never from a measurement — so the list that exists to stop
invented shapes was carrying one of its own. Removed from the code, the test and the ticket.

Five minutes in the editor closes it: draw **one of each** on any layer, save, and send the `.miz` (or
just its `mission` file). Each shape is then a table entry, not an investigation.

</details>

## ✅ 11. Checks 6 and 7 of `verify-mission-c` — verified in game 2026-08-22

`FIX-SKYNET-DYNAMICSPAWN-SCOPE` confirmed: `group added to RED IADS`, and `0 actual reactivations`
on a spawn into a dark network. The cycling seen alongside it is a **different** defect and now has
its own lot, [`FIX-SKYNET-SITE-GOES-DARK-BEFORE-FIRING`](.backlog/FIX-SKYNET-SITE-GOES-DARK-BEFORE-FIRING/PRD.md).

---

## ✅ 12. Check 8 of `verify-mission-c` — verified in game 2026-08-22

`FIX-COMBATZONE-DELAYED-COMMAND`: a delayed `#command` dies with its zone.

---

## ✅ 13. Check 12 of `verify-mission-c` — verified in game 2026-08-22

`FIX-CARRIER-MENU-COALITION`: the carrier menu is there from the red side.

---

## ✅ 14. The FARP escort — verified in game 2026-08-24, after five rounds

[#232](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/232), open since 2023 and "fixed" in
6.15.11 by a change that could not work. Confirmed still broken on 2026-08-22, then fixed for real
in #792 — **five** distinct defects, three of them sizing guesses of mine that a measurement would
have killed sooner. David's verdict: *« c'est bon, tout est en dehors du farp statique »*.

The transferable lesson, and the reason this took five in-game rounds instead of one: the placement
logged nothing about **why** it refused a spot, so each hypothesis cost a full DCS reload. It logs
at info now.

---

## ✅ 16. The combat zone alarm state — verified in game 2026-08-22

`FIX-COMBATZONE-ALARM-BY-NATURE`, as far as it was testable: the convoy drives. The armour half
was **not** a valid check — see the withdrawal of item 17 below, which is the same mistake.

---

## 17. ~~A tag on one unit of a group~~ — withdrawn 2026-08-22, the criterion was wrong

[`FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY`](.backlog/archive/FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY.md), 6.15.14.
Closed on unit coverage instead. **Nothing to do in game.**

This check told the tester to activate the zone and watch two M-1 Abrams: *"they stay put"* meant the tag
had been read, *"they drive off"* meant it had not. David ran it and reported the tanks moving — which
turns out to be what happens either way.

`#alarm=2` reduces to `setOption(AI.Option.Ground.id.ALARM_STATE, 2)` in `veaf.readyForCombat`
(`veaf.lua:2117`), reached from `veafCombatZone.lua:1505`. Nothing on that path immobilises a group. A
mobile group with a route drives it under RED exactly as under AUTO, so the two states this check meant to
tell apart are **visually identical for this group**. The observation could not have failed, and could not
have succeeded either.

What the game would have added is only "DCS honours the option", which is not our code. The part that *is*
ours — reading a tag off any unit of the group rather than the first one met — is covered by enumerated
tests over the whole tag family with the tag on the **second** unit
(`test/lua/test_veafCombatZone.lua:1674`, `:1872`).

Also recorded because it cost real time: the zone shows as **"Convoy Test Zone"** in the radio menu, its
`friendly_name`. `SmokeZone` is the trigger-zone name and appears nowhere a player looks.

The lesson worth keeping is not about alarm states. An in-game check is only worth a session if it can
**come out both ways**; this one was written from an assumption about DCS behaviour that was never tested,
and the assumption was wrong. Two waypoints were even added to the group on 2026-08-21 to make the check
possible — and that hand-copied waypoint is what later broke the mission for the DCS editor
([`FIX-VALIDATE-CONTRADICTORY-WAYPOINT-LOCKS`](.backlog/archive/FIX-VALIDATE-CONTRADICTORY-WAYPOINT-LOCKS.md)).
The whole cost came from a check that could never conclude.

## ✅ 18. The dispersion — verified in game 2026-08-22

`FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT`: *« tout est comme prévu »*.

---

## ✅ 19. A convoy walking an itinerary — verified in game 2026-08-22

`FEAT-CONVOY-WAYPOINTS`: the commands work. The ergonomic reservation David raised at the same
time — one command per submenu — was fixed separately in #791.

---

## ✅ 20. The two CSAR-over-water checks — run 2026-08-23

`FEAT-SMOKE-CSAR-WATER`. Worth recording what it actually cost: **five successive defects in the
harness**, each of which read as a product regression and none of which was one — no bridge
injected, bridge and CSAR on different branches, `CSAR: false`, the check calling a function the
replacement had superseded, and an "open sea" defined at 150 m against a 500 m search radius. The
checks pass, and #790 is what made them able to fail.

---

## 3. Confirm a rebuilt checklist picture is not served stale — **prepared 2026-08-24**

[`FEAT-ASSIST-FOLLOWUP` 01](.backlog/FEAT-ASSIST-FOLLOWUP/PRD.md) shipped the fix: a checklist image's
file name now carries 8 hex of its own content hash, so DCS cannot serve a cached bitmap under a name
it already knows. **No unit test can see DCS's resource cache**, hence this flight.

Four missions are built and waiting, with the full procedure, in
`D:\dev\_VEAF\tmp\dcs-session-2026-08-24\` (`LIRE-MOI.md` + `missions-a-charger\`). F-16C at
Kobuleti parking, cold; **F10 → Assistance → Démarrage à froid** (the missions build `language: fr`),
and the picture appears at state 0 on its own. The marker sits on the highlighted first line:
`AVANT -- cache probe build A` / `APRES -- cache probe build B`.

**Three loads, no DCS restart between them** — a restart clears the very cache under test:

| # | Mission | Must read | What it says |
|---|---|---|---|
| 1 | `2-item3-controle-A-AVANT` | AVANT | the picture enters DCS's cache |
| 2 | `3-item3-controle-B-APRES` | **AVANT** (stale) | DCS still caches by file name → the check means something |
| 3 | `4-item3-corrige-B-APRES` | APRES | the fix works |

**Why a control pair at all**, and the reason this is three loads rather than one: missions 1 and 2 are
built normally and then rewritten back to the **pre-fix** naming (`assist-f16c-cold-start-0.png`, no
digest) in both the archive and `mapResource` — two different pictures under one name, the artefact the
bug was made of. Without them, mission 3 showing the right text would be equally consistent with "the
fix works" and with "DCS stopped caching between 2.9 builds", and we would not know which. If step 2
reads APRES, the check is void and step 3 proves nothing.

Measured on the built files: the fixed pair changes **7 file names out of 7** with the label while
keeping identical resource keys (so a label edit does not move the mission's Lua, which was the design
constraint); the control pair shares **7 out of 7**.

## 4. Confirm the staggered script loading — **prepared 2026-08-24, and half of it is already answered**

[`FEAT-CUSTOM-SCRIPT-LOAD-DELAY`](.backlog/archive/FEAT-CUSTOM-SCRIPT-LOAD-DELAY.md) is ✅ and verified
against the real Foothold Caucasus 4.4.1 `.miz`, but never watched in game.

**The staging itself no longer needs DCS.** Foothold Caucasus 4.4.1 was adopted fresh today and the
built `.miz` was read back: `Mission scripts loading - static` carries 8 files at t=0,
`- delayed 3s` carries 5, `- delayed 12s` carries AIEN alone — exactly the upstream table. The mission
runs in **static** mode (both selector triggers `return false`), so those are the triggers that execute,
and the generated `veafDynamicConfig.lua` schedules the same delays, so the documented claim that both
modes stage alike holds. Nothing left to look at there.

**What the game still has to say is the PRD's own open question:** does the delay change anything? The
lot settled it by reading code — AIEN inventories ground groups once, at load, and Foothold creates part
of its groups from t+2 s — but never measured it.

AIEN's log cannot answer: its line that would count each inventoried group is **commented out** upstream
(only MLRS-with-guidance and unidentified-class groups log), and it writes no total. So
`1-item4-foothold-echelonnement.miz` (same folder as item 3) carries an instrument in
`mission-script.lua` that counts ground groups at t=0, +3 s, +12 s and +30 s.

Load it, take any slot, let it run 40 s, quit, and grep `dcs.log` for `VEAF-PROBE` (five lines) and
`STATIC Mission scripts loading` (three, for their timestamps).

- count at +12 s **equal** to t=0 → the upstream staging is caution, and the lot is a fidelity nicety;
- count at +12 s **higher** → AIEN at t=0 was demonstrably shown fewer groups, and the lot delivered a
  correctness fix as it claimed.

Either way it is a result, which is why it is worth the load.

## 5. Fly the F-14B(U) startup checklist

[`FEAT-ASSIST-AUTHORING` 06](.backlog/FEAT-ASSIST-AUTHORING/tickets/06-f14b-manual.md) — written,
resolved, and its four automatic steps already verified in game on 2026-08-03. All that is left is
your verdict on whether the procedure matches what you actually do.

## ✅ 6. The smoke harness's remaining slice — closed 2026-08-15

[`FEAT-DCS-SMOKE-HARNESS`](.backlog/archive/FEAT-DCS-SMOKE-HARNESS.md) — locate, launch, load, quit.
The runner shipped; the unattended single-player load was **dropped rather than built** — DCS does
not document it, David's call. Nothing left here.

This is the lever that pays: run once on 2026-08-06 it closed `FEAT-COMBATZONE-MENU-COALITION` (open
since July) and turned `Disposition` from assumed into existing.

## ✅ 7. Test a token on the fiddle-server port — validated in game 2026-08-15

[`FIX-SECREV2-EXPIRED-DEFERRALS` 02](.backlog/archive/FIX-SECREV2-EXPIRED-DEFERRALS.md) — **VMR-013**, and
it is a live security hole rather than a nicety: the port executes arbitrary Lua from unauthenticated
HTTP, and with `cors='*'` plus a GET channel, any web page visited while the hook is installed gets
code execution.

It was deferred for want of a DCS to test a token on, over the transport the smoke harness speaks
through — and the harness has since run in game, so the dependency is live.

## 8. Two lower-priority pilot items

- [`FEAT-ASSIST-FOLLOWUP` 02](.backlog/FEAT-ASSIST-FOLLOWUP/PRD.md) — whether an
  `a_cockpit_highlight` leaks into another cockpit. Needs **a second pilot**; the per-session id
  exists for it and has never been exercised.
- [`FEAT-ASSIST-FOLLOWUP` 03](.backlog/FEAT-ASSIST-FOLLOWUP/PRD.md) — an F-16C pilot's review of the
  six shipped steps. The engine was flown and works; the *procedure* was never checked by a pilot.

---

## ✅ 23. CSAR sans MiST — vérifié en jeu le 2026-08-31, et il a trouvé deux défauts

Les quatre étapes passées : pilote abattu créé (`Wounded Pilot #200084`, identifiant de
l'allocateur VEAF), message radio `requests SAR at bullseye 333 for 62, beacon at 300.00 KHz`,
direction « 2 heures » recoupée par un calcul indépendant, et ramassage effectif. `mist` était
`nil` du début à la fin.

Deux défauts trouvés au passage, qu'aucun des 3950 tests ne voyait : l'assertion de dépendance
s'exécutait au chargement, là où `veaf` ne peut pas encore exister ; et un groupe créé en vol
n'avait pas de pays, ce qui cassait **tout** téléport de groupe dynamique. Détail complet dans
`.backlog/archive/REFACTOR-CSAR-WITHOUT-MIST.md`.

## ✅ 24. Skynet sans MiST — vérifié en jeu le 2026-08-31, sans un seul décollage

Piloté par le hook fiddle plutôt que volé, David n'ayant pas de matériel sous la main — et c'est
mieux tombé ainsi : les deux morceaux risqués sont du comportement dans le temps, qui se mesure
mieux qu'il ne se regarde.

Ordonnanceur exact (13 exécutions en 26 s à 2 s d'intervalle), annulation propre, défense HARM qui
éteint **et rallume** à l'échéance, 13 sites SAM et 8 radars EW recensés par préfixe, site créé en
vol vu immédiatement. Le piège MiST a mordu 31 fois, **31 fois depuis `dcs-bridge.lua`** (l'outil
d'observation lui-même) et **zéro depuis Skynet**.

Détail complet, y compris mes deux fausses alertes de méthode, dans
`.backlog/archive/REFACTOR-SKYNET-WITHOUT-MIST.md`.


---

## 25. The FARP escort on clear ground must not move — unblocks `FIX-PLACEMENT-IGNORES-SCENERY` 04

Opened by [`FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND`](.backlog/FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND/PRD.md),
whose code fix and tests landed 2026-09-01. Item 21's own non-regression case failed on 2026-08-28: a
`-farp` on open ground, nothing within a kilometre, logged `FARP escort: bearing 0 requested, 25 used at
1.054x distance`. Tier 1 of `findClearBearing` selected out of `Disposition`'s cloud before testing the
requested bearing, and the wanted spot is never one of the cloud's candidates.

Three markers, on the session mission rebuilt with `--dev-mode` against the fix. Grep `dcs.log` for
`FARP escort:` and `findClearBearing:`.

| Marker | Case | Expected |
|---|---|---|
| open ground, nothing within a kilometre | the non-regression | bearings **equal**, `1x`, plus `bearing N is inside a scenery-clear area, keeping it` |
| in or beside a wood | the reason tier 1 exists | bearings **differ**, escort visibly out of the trees |
| beside a static FARP | the reason the occupancy probe still decides | bearings differ or scale above 1, escort off the apron |

**A run where nothing moves in any of the three is a failure, not a pass** — it would mean the fix
turned tier 1 off. The last two rows are the half that makes this a real check.

`no usable point in Disposition's cloud, walking the bearings instead` now logs at **info**, so the
old instruction to set `veafGrass.LogLevel = "debug"` for this no longer applies.

Full protocol: [ticket 02](.backlog/FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND/tickets/02-verify-in-game-that-nothing-moves.md).

---

## Zone de combat : un groupe très étalé garde-t-il sa forme ?

Ouvert par `FIX-TRIPACK-FIELD-REPORTS` (ticket 04), correctif du 2026-09-05.

Ce qui est établi sans DCS : le décalage qui translate tout le groupe d'une zone était lu à **deux
sources différentes** — le spawner le mesure contre `units[1]` de l'enregistrement de mission (l'unité
que l'éditeur a mise en premier), la zone ancrait l'élément sur `Group:getUnit(1)` (la première unité
**vivante**, dont l'indice glisse quand DCS compacte sa liste). Dès qu'elles divergent, le décalage
devient l'écart entre deux unités différentes et tout le groupe se déplace d'autant. Mesuré dans le
harnais sur les vraies coordonnées de `CMBT_ABU_MUSA_AIRPORT - AAA` (cinq ZU-23 étalées sur 4 330 m) :
**1 975,9 m** si la première ZU-23 est perdue avant la construction de la zone, **3 340,4 m** si la
liste vivante n'est pas dans l'ordre de l'éditeur. Après correctif, ≤ 50 m dans les deux cas.

Ce qu'ils ne peuvent pas dire : **lequel des deux scénarios s'est produit chez Tripack**, ni même si
l'un des deux s'est produit. Au démarrage de la mission les cinq ZU-23 sont vivantes, et les deux
« unité 1 » devraient donc désigner le même objet. Le correctif supprime toute la famille, il ne
referme pas un cas observé.

**À faire** : lancer `Snowfox_20260903.miz` avec le niveau de log **`trace`** sur la zone de combat
(`logLevel: trace` sous `COMBATZONE` dans `mission.yaml`), activer `CMBT_ABU_MUSA_AIRPORT`, et
relever dans `dcs.log` les deux lignes que la zone trace — `spawnElement` : `position=[...]` (la
position déclarée) puis `found=[...]` (le point retenu).

> **Corrigé le 2026-09-07.** Cette consigne demandait `debug` et **trois** nombres. Elle était
> inexécutable : les deux positions sont tracées en `trace`, pas en `debug`, et le troisième nombre —
> le décalage calculé par `_drawOrigin` — n'est journalisé à aucun niveau. Elle aurait consommé une
> session DCS pour rien. Trouvé par la relecture post-merge de la PR #921.

Comparer `position` aux coordonnées éditeur de `AAA-1` — attention à la convention : la trace runtime
écrit l'est en `z`, là où le fichier de mission l'écrit en `y`. Donc `position.x` se compare à
`x = -30382,9` et `position.z` à `y = -122247,2`.

- **Attendu après correctif** : `position` tombe sur `AAA-1` à quelques mètres près, le décalage est
  inférieur à 50 m, et les cinq ZU-23 sont à terre sur la carte F10.
- **Ce qui rouvrirait le sujet** : `position` tombe sur une **autre** ZU-23 (donc l'ancrage par nom
  n'a pas suffi), ou les cinq sont bien à leur place et deux restent quand même dans l'eau — ça
  voudrait dire que le déplacement n'était pas la cause du rapport de Tripack et qu'il faut chercher
  ailleurs. Candidat restant, non traité ici : la validation de terrain
  (`veaf.findSpawnPoint` dans `spawnElement`) ne teste que le point d'ancrage, jamais les quatre
  autres unités du groupe — une unité déjà au bord de l'eau dans l'éditeur peut donc passer dedans
  sans que rien ne le remarque.

**Première piste préparée le 2026-10-03 au soir** (M4 de `D:\dev\_VEAF\tmp\dcs-session-2026-10-03c\`).
`Snowfox_20260903.miz` **n'est pas sur DAVID-BUREAU** (cherché sur `D:\` et le profil) : la zone a été
reconstruite dans une mission Persian Gulf vierge à partir des chiffres de ce ticket — même centre,
même rayon, pas de `#spawnradius`, les cinq ZU-23 aux coordonnées éditeur exactes, rien d'autre sur la
carte. Les sondes `c_t04_*.lua` enveloppent `coalition.addGroup` et donnent, unité par unité et sur
cinq cycles d'activation, trois écarts : **remise à DCS − éditeur** (une translation commune > 50 m =
l'ancrage), **position réelle − remise** (> 5 m = DCS déplace l'unité après le spawn), et la **nature
du sol** sous la position éditeur. Tout propre sur les cinq cycles ne clôt rien : cela dit seulement
que les données éditeur ne suffisent pas à reproduire, et qu'il faut le `.miz` de Tripack.

**Mesuré le soir même : non reproduit.** Sur les cinq cycles, les cinq ZU-23 reçoivent à chaque fois
un même vecteur de 4 à 43 m (la dispersion de 50 m), DCS ne les déplace pas après le spawn, et toutes
les positions — éditeur comprise — sont sur `LAND`. Il reste à rejouer la mesure sur `Snowfox_20260903.miz`
quand il sera disponible ; la question n'est pas reposée d'ici là.

---
