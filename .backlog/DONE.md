# Done lots

[Back to the backlog](README.md)

Closed lots still on disk; each moves to the archive three days after it closed.

## ✅ Done

### [CHORE-BACKLOG-INDEX-SPLIT](CHORE-BACKLOG-INDEX-SPLIT/PRD.md) · ✅

The backlog index split into active, ready and done indexes, one short paragraph per lot; the archived lots got their own index (#1058).

### [CHORE-DROP-MACOS-INTEL](CHORE-DROP-MACOS-INTEL/PRD.md) · ✅

The macOS Intel target leaves the release matrix: it never published an asset and held the 6.27.0 run open overnight.

### [CHORE-REQUIRED-CHECKS-GATE](CHORE-REQUIRED-CHECKS-GATE/PRD.md) · ✅

Path-filtered workflows made usable as required checks; the 11 checks are now required on `develop`, so auto-merge waits for them.

### [CHORE-VENDOR-CTLD-RC12](CHORE-VENDOR-CTLD-RC12/PRD.md) · ✅

CTLD `2.0.0-rc12` vendored (#1051): reoccupied slots, `EXZ_` extraction zones, UH-1H / Mi-8MT catalogue changes.

### [FEAT-AIRCRAFT-ROLES](FEAT-AIRCRAFT-ROLES/PRD.md) · ✅

One way to spawn an aircraft with a job: `veafAircraftSpawn` roles, given to QRA and AirWaves CAP groups at clone time. Verified in game (R21).

### [FEAT-AIRFIELD-CHANNELS-FROM-DCS](FEAT-AIRFIELD-CHANNELS-FROM-DCS/PRD.md) · ✅

Airfield radio channels generated from DCS's own reference instead of typed by hand, plus a CLI/MCP tool writing the channels a mission's fields deserve (#1041).

### [FEAT-CTLD-AIRBASE-LOGISTICS](FEAT-CTLD-AIRBASE-LOGISTICS/PRD.md) · ✅

Airfields become CTLD logistic zones (#1007): blue-from-start fields keep them, captured ones after two minutes of ground presence, marked by a green circle. Seen in game 2026-10-03: at Ramstein a C-130 parks 997 m out, so a mission raises `airbase_logistics_radius` (1 100 m there).

### [FEAT-HELICOPTER-SPAWN](FEAT-HELICOPTER-SPAWN/PRD.md) · ✅

Helicopters spawned from a marker, landed as targets or given a job (orbit, transport, patrol, attack, escort) (#1050, #164).

### [FEAT-OBJECTIVE-MISSION-PROMPT](FEAT-OBJECTIVE-MISSION-PROMPT/PRD.md) · ✅

A prompt for a one-session objective mission with numbered scenarios and a PPTX/PDF briefing; operations active at start and scenery targets came with it.

### [FEAT-SPOTTER-DEMO-MISSION](FEAT-SPOTTER-DEMO-MISSION/PRD.md) · ✅

Missions that show a spotter report reaching a battery that never saw the aircraft: a durable wake-up history, the rig and its smoke suite, and a Syria walkthrough validated by David on 2026-09-21.

### [FEAT-TERRAIN-ELEVATION](FEAT-TERRAIN-ELEVATION/PRD.md) · ✅

A ground-elevation grid per theatre, read without DCS running: point elevation, cell maximum, profiles (#1045).

### [FIX-AIR-SPAWN-ALTITUDE-GUARD](FIX-AIR-SPAWN-ALTITUDE-GUARD/PRD.md) · ✅

The aircraft height check read the easting; it now reads the altitude, and every aircraft given a role is floored 150 m above the ground (#1055).

### [FIX-AIRCRAFT-ROLE-REGISTRY-PURGE](FIX-AIRCRAFT-ROLE-REGISTRY-PURGE/PRD.md) · ✅

The aircraft role registry forgets a group once it is gone: through the CAP watchdog for `cap` and `zone_defense`, on the next spawn with a role for the others (#1079, #1080).

### [FIX-AIRFIELD-CHANNEL-TITLE-ACCENTS](FIX-AIRFIELD-CHANNEL-TITLE-ACCENTS/PRD.md) · ✅

`content airfield-channels --apply` kept the DCS spelling (`Büchel` → `Buchel`) and its matching ignored accents; titles now keep the author's spelling, and accents fold.

### [FIX-AIRWAVES-COMMAND-EASTING](FIX-AIRWAVES-COMMAND-EASTING/PRD.md) · ✅

A command-driven air wave (and the same branch in QRA) spawned with a nil easting, being handed a vec2 where a vec3 was expected. Fixed, and both halves seen in game on 2026-10-03: each wave within 250 m of its offset.

### [FIX-CAP-ENGAGES-PARACHUTES](FIX-CAP-ENGAGES-PARACHUTES/PRD.md) · ✅

A spawned CAP flew weapons free with nothing tasked: its watchdog dropped every fresh contact. Repaired with an `Air`-attribute target filter; verified in game (R11).

### [FIX-CAP-RADIUS-UNIT-DOCS](FIX-CAP-RADIUS-UNIT-DOCS/PRD.md) · ✅

Docs: `-cap` `capradius` is in nautical miles, not metres, and `distance` is the race-track leg (#1056).

### [FIX-CAP-SIDE-TEMPLATES](FIX-CAP-SIDE-TEMPLATES/PRD.md) · ✅

A red `-cap` drew from every side's templates, 7 in 10 of them western; `-cap` and `-afac` now draw from their own side (#1052, #240).

### [FIX-CHATBOT-DAILY-QUOTA](FIX-CHATBOT-DAILY-QUOTA/PRD.md) · ✅

The documentation assistant hit Google's free tier (23 of 20 a day on 2026-09-22); a spent day now falls back through `gemini-2.5-flash` and two Gemma 4 models, each with its own allowance, and the limit says so when the whole chain is spent (#916, #1066).

### [FIX-CLEARSKY-METAR](FIX-CLEARSKY-METAR/PRD.md) · ✅

A `clearsky` variant's `${METAR}` announced the uncapped published sky; it is now composed from the capped weather.

### [FIX-COMBATMISSION-UNKNOWN-NAME](FIX-COMBATMISSION-UNKNOWN-NAME/PRD.md) · ✅

An unknown combat mission name — the bare name of an on-demand CAP — raised a Lua error; it is now reported on screen (#1060), seen in game 2026-10-03.

### [FIX-COMBATZONE-RENAME-OPTION](FIX-COMBATZONE-RENAME-OPTION/PRD.md) · ✅

A combat zone's unit renaming became a zone-level `combat_zones:` switch (#289, shipped in 6.15.16); Sharko told on 2026-09-01.

### [FIX-CONVERT-V5-SILENT-LOSSES](FIX-CONVERT-V5-SILENT-LOSSES/PRD.md) · ✅

`convert-v5` silently dropped settings: multi-line `setBriefing` truncated the chain, six `combat_zones` setters had no key. Shipped in 6.15; closed without Sharko's harnesses, which never came.

### [FIX-DESTROY-NAME-KEY](FIX-DESTROY-NAME-KEY/PRD.md) · ✅

`_destroy, name X` destroys X only; it used to clear everything within 150 m of the marker (#1069).

### [FIX-ESCORT-RESPAWN-DISTANCE](FIX-ESCORT-RESPAWN-DISTANCE/PRD.md) · ✅

A respawned asset reappeared ~80 km from its escort; the escort now respawns with its charge. Verified in game (R5).

### [FIX-IN-GAME-SESSION-2026-10-03](FIX-IN-GAME-SESSION-2026-10-03/PRD.md) · ✅

What a pilotless DCS session found: colour names, a freezing `logger:warning`, the CAP watchdog's task pile-up, `_spawn signal`, and the zone SAM respawn id (#1054, #1055).

### [FIX-IN-GAME-TEST-FINDINGS](FIX-IN-GAME-TEST-FINDINGS/PRD.md) · ✅

The first in-game test of an MCP-built mission: statics without `shape_name`, zones initialised twice, sanctuary weapon check, CTLD sample names, no cities. Fixed; verified in game (R17), the sanctuary case by tests only.

### [FIX-LOGS-EXE-STARTUP-AND-VERSION](FIX-LOGS-EXE-STARTUP-AND-VERSION/PRD.md) · ✅

`veaf-logs.exe` opened in ~10 s because it reconnected remote tabs before showing the window (now 2.3 s), and reported `tool.version: unknown` (now stamped) (#1057).

### [FIX-OBJECTIVE-COMPLETION](FIX-OBJECTIVE-COMPLETION/PRD.md) · ✅

A combat zone holding a static never completed, and the destroyed-scenery register never subscribed to `S_EVENT_DEAD`. Both fixed.

### [FIX-PER-MODULE-LOGLEVEL-INERT](FIX-PER-MODULE-LOGLEVEL-INERT/PRD.md) · ✅

A module's `logLevel:` never applied because nothing called `veaf.initialize()`. Fixed; verified in game (R18).

### [FIX-PLACEMENT-IGNORES-SCENERY](FIX-PLACEMENT-IGNORES-SCENERY/PRD.md) · ✅

Ground units placed inside buildings and forests, and a crowded FARP giving up silently. All tickets shipped; the probe sweep (R16) and the `-farp` refusal (R19) verified in game.

### [FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND](FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND/PRD.md) · ✅

A FARP escort moved even on free ground; it now checks the wanted spot itself and stands beside its own FARP's props (#1055).

### [FIX-QRA-COMMANDS-AND-OFFSET](FIX-QRA-COMMANDS-AND-OFFSET/PRD.md) · ✅

A QRA config accepted then ignored: VEAF commands refused by `validate` in deploy lists, and `respawn_default_offset` never emitted. Fixed; verified in game (R7, QRA half).

### [FIX-RELAY-STOPS-AT-CLOSE](FIX-RELAY-STOPS-AT-CLOSE/PRD.md) · ✅

Closing a support issue cut its Discord relay for good, so a reopened issue went silent; deleted issues were retried for ever. Fixed; the live repair of #946 (ticket 03) was dropped — by then the issue was closed again and the reporter had followed it on GitHub.

### [FIX-SCRATCH-MISSION-FINDINGS](FIX-SCRATCH-MISSION-FINDINGS/PRD.md) · ✅

What building Open Training Germany CW from an empty folder found: 22 tickets merged, and the mission rebuilt with the fixed tools on 2026-09-25, its five workarounds removed.

### [FIX-SKYNET-ADDS-DESTROYED-GROUPS](FIX-SKYNET-ADDS-DESTROYED-GROUPS/PRD.md) · ✅

The IADS enrolled groups a combat zone had just destroyed (#946). Verified in game (R14); the deactivated-zone half closed by the 2026-10-03 session lot (#1055).

### [FIX-SKYNET-HELPER-AND-VENDORING](FIX-SKYNET-HELPER-AND-VENDORING/PRD.md) · ✅

The VMCT half of The Reaper's report: dead actAsEW blocks removed, what a network SAM sees documented, Skynet 3.5.0 vendored and seen in game, drift watch repaired.

### [FIX-SKYNET-SITE-GOES-DARK-BEFORE-FIRING](FIX-SKYNET-SITE-GOES-DARK-BEFORE-FIRING/PRD.md) · ✅

A SAM site went dark every other Skynet cycle and never launched; fix proposed upstream and verified in game (R1).

### [FIX-TUTORIAL-FIRST-RUN](FIX-TUTORIAL-FIRST-RUN/PRD.md) · ✅

Paluche's first run through the walkthrough: three steps that could not be followed, plus zone smoke that never appeared. Shipped in #908; the smoke verified in game (R12).

### [FIX-USER-REPORTS-985-989](FIX-USER-REPORTS-985-989/PRD.md) · ✅

#985: shipped spawnables under real countries instead of CJTF, now pinned by a test. #989: no CSAR menu in a dynamic-slot helicopter, fixed.

### [FIX-WAREHOUSES-INCREMENTAL](FIX-WAREHOUSES-INCREMENTAL/PRD.md) · ✅

Assigning one airfield to a coalition disabled all the others; the airfield table is now completed rather than filled only when empty. Verified (R2).

### [FIX-WAREHOUSES-LIST-FORM](FIX-WAREHOUSES-LIST-FORM/PRD.md) · ✅

Every base came out neutral in 6.14.2: a contiguous airfield table read as a list was replaced by an empty one. Verified (R3).

### [INVESTIGATE-SKYNET-AWACS-BLIND](INVESTIGATE-SKYNET-AWACS-BLIND/PRD.md) · ✅

Not a defect: measured in game, an A-50 enrolled by the helper detects by radar and feeds Skynet, and the three A-50s of the report orbited more than its 204 km from every Georgian base, which the ground radars reached — consistent, not proven, the log being lost. The contact flag that can stay `DLINK` for minutes is now a recorded DCS trap.

## 🚫 Won't fix

### [FEAT-MISSION-RECIPES](FEAT-MISSION-RECIPES/PRD.md) · 🚫

Not needed for an always-current demo: the versioned mission folder is already the replayable source, content is added through the MCP, and CI can build and run it as is. A new demo mission replaces the idea.
