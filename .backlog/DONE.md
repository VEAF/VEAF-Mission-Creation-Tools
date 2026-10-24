# Done lots

[Back to the backlog](README.md)

Closed lots still on disk; each moves to the archive three days after it closed.

## ✅ Done

### [FIX-GO-VEAF-LOGS-UI](FIX-GO-VEAF-LOGS-UI/PRD.md) · ✅

The Go `veaf-logs` window brought level with the Python one. The filters panel no longer spreads three groups over its whole height on a short journal (a walk custom widget is greedy; each group is now pinned to its content, checked by the smoke test). Then seven of the nine differences found by comparing the two windows side by side: flat buttons and fields, compact number fields, the panel's toggle, the bars' height, the panel's width, the table's empty area, the font dialog. Merged in #1185.

### [FIX-LOGS-SEARCH-REDACTION](FIX-LOGS-SEARCH-REDACTION/PRD.md) · ✅

The search criteria the excerpt's header repeats went to the VEAF Worker as typed, unredacted, when *Analyser en ligne* was pressed: they are now redacted like the records. Found by a security review of the Go port's J5, fixed on both sides.

### [FIX-VEAF-LOGS-VIEWER-DEFECTS](FIX-VEAF-LOGS-VIEWER-DEFECTS/PRD.md) · ✅

Three defects of the Python `veaf-logs` found by the Go port: *Aller à la fin* had no shortcut, `^` and `$` bound to the 8 MB search block instead of the line (Go follows), and a glob starting with `*` froze the window for a minute on a 130 MB journal. Split from FEAT-GO-VEAF-LOGS-ISOFUNCTIONAL; merged in #1177, 2026-10-24.

### [POC-GO-VEAF-LOGS](POC-GO-VEAF-LOGS/PRD.md) · ✅

Proof of concept: veaf-logs rewritten in Go in an isolated module (`src/go/veaf-logs/`). Same classification as the Python viewer on every entry tested, 9.5 MB instead of 47.2 MB, window in 0.3 s instead of 2.1 s, a 130 MB journal indexed in 2.4 s instead of 13.3 s; Gio chosen for the UI (ADR 0021); remote journals over SFTP included. Memory is the one figure where Go loses. The follow-up decision is David's. Done 2026-10-24.

### [FIX-DEMO-VIDEO-FINDINGS](FIX-DEMO-VIDEO-FINDINGS/PRD.md) · ✅

What the AI worked around while building missions with the VEAF tools, from David's demo video and Martinho's session (2026-10-22): Texaco refused for a tanker, 123.5 MHz on the UH-1H, an empty ATO with dynamic slots, the tanker missing from the briefing, accents lost in what the AI writes, waypoint numbers that no longer match the route, a PDF of the briefing from the executable, and six smaller frictions of the actions. Each measured first.

### [DOC-DEMO-VIDEO](DOC-DEMO-VIDEO/PRD.md) · ✅

The demo video (a free AI installs the VEAF tools and builds a mission with its briefing) embedded under the five-step box of "Create with an AI", with subtitles forced in the page's language, and linked from the home page card.

### [DOC-AI-MODEL-CHOICE](DOC-AI-MODEL-CHOICE/PRD.md) · ✅

The install page says how to choose the model in OpenCode, Codex or Antigravity: the install is the test, prefer a model that keeps no data, and the models tested in October 2026 (DeepSeek v4.1 Flash succeeded, Big Pickle did not). From David's demo tests.

### [FIX-MISSION-LANGUAGE-FOLLOWS-USER](FIX-MISSION-LANGUAGE-FOLLOWS-USER/PRD.md) · ✅

The English mission prompts told the AI to write the mission, its briefing and README in French; an English-speaking user now gets `mission.language: en` and English documents. The parking limitation, whose id made an AI deny dynamic slots on GermanyCW, is now `ai-ground-start-needs-a-parking-capture`. Afghanistan, GermanyCW, both Marianas and TheChannel now ship their parking capture. Also Pillow 13 and certifi (15 Dependabot alerts), "0 aircraft" stopping the combat missions' auto scale (#1151) and a checked campaign state write (#1146). From David's OpenCode test on 6.31.2, fixed in 6.31.3.

### [FIX-OPENCODE-TEST-FINDINGS](FIX-OPENCODE-TEST-FINDINGS/PRD.md) · ✅

What David's end-to-end OpenCode test on 6.31.1 met, fixed in 6.31.2 (PR #1162): the self-update stages the new exe and swaps it in only at a lone server start; `edit_mission_file` across CRLF and an LF scaffold; reference data with no mission folder (`theatre`, `list_countries`, the shipped scaffold); a lone FARP's dynamic slots; lighter reads; `inspect_built_mission`, and a guide that never parses a `.miz` in a shell. Ticket 04 (presets) measured as not a defect.

### [FEAT-AI-ZERO-SETUP](FEAT-AI-ZERO-SETUP/PRD.md) · ✅

Installing veaf-tools is all an AI needs: `veaf-tools ai-setup` declares the MCP server in Claude Desktop, Claude Code and Gemini CLI, the server updates itself, the authoring guide and the two mission prompts ship in the executable, and the plugin is removed. Asked by David on 2026-10-20 after a demo in a clean sandbox behaved unlike his PC; found on the way: the plugin's binary had been stuck on 6.22.1 since September. Merged in #1155, released in 6.31.0; David's PC set up on 2026-10-20 with 6.31.1, Claude Desktop from the Store included (#1160).
### [FIX-AI-SETUP-STORE-DESKTOP](FIX-AI-SETUP-STORE-DESKTOP/PRD.md) · ✅

`veaf-tools ai-setup` finds Claude Desktop when its Store install keeps its data in `%LOCALAPPDATA%\Claude-Data\`, as on David's PC, where it answered `not_found`; and the updater's first-install message stops sending the AI install page's users to run `prepare .` in their tools folder. Merged in #1160. Found by FEAT-AI-ZERO-SETUP ticket 08 on 2026-10-20.
### [FEAT-MCP-MISSION-BRIEFING](FEAT-MCP-MISSION-BRIEFING/PRD.md) · ✅

An MCP action that builds the VEAF mission briefing — PPTX, maps, DCS briefing pictures — from the built mission and the content the assistant passes, so an assistant with no shell (Claude Desktop in chat mode) produces it too. The builder exists for campaign missions (`campaign_manager/mission_deck.py`). Asked by David on 2026-10-20.
### [FEAT-TERRAIN-DATA-DOWNLOAD](FEAT-TERRAIN-DATA-DOWNLOAD/PRD.md) · ✅

Terrain data an AI can use without DCS: the elevation grids swept in DCS are published as the `terrain-data` GitHub release, and veaf-tools downloads a missing theatre on first use, checksum verified; a local grid keeps priority, offline the answer stays "sweep it in DCS" (#1154). 11 theatres published on 2026-10-20, TheChannel made sweepable on the way.

### [FEAT-KNEEBOARD-PRESETS-REDESIGN](FEAT-KNEEBOARD-PRESETS-REDESIGN/PRD.md) · ✅

The radio presets kneeboard page redrawn for the 2:3 window DCS stretches every image into: cockpit radio names, no empty rows, two columns, a shared calibration page, header and footer clear of the window's own controls, 256-colour PNGs (#1148, #1149). Seen right in game by David on 2026-10-18; demo step added (VEAF-Demo-Mission-v6 #10); the eight v6 OT and the eight foothold2 Foothold missions rebuilt the same day, and deployed (Foothold Syria by stopping foothold2 while empty).

### [FIX-FOOTHOLD-5-3-0-INTAKE](FIX-FOOTHOLD-5-3-0-INTAKE/PRD.md) · ✅

Refreshing the ten Foothold missions to Lekaa 5.3.0 (2026-10-17) found four defects: the batch matched no folder (theatre read in one key form only, and the Open Training missions on the same maps counted as candidates), `--update` kept `zoneCommander.lua` in `custom_scripts:` when the release renamed it `zoneCommanderv2.lua`, `validate` failed on the `hercules: false` left after #843, and the batch turned an LF `mission.yaml` into CRLF. All fixed (#1147); the ten missions refreshed, built and committed on their `main`.

### [FIX-SOLAR-DEFAULT-POSITION](FIX-SOLAR-DEFAULT-POSITION/PRD.md) · ✅

The shipped `versions.yaml` put every mission's sunrise at Damascus: 24 minutes late on the Caucasus in March, 50 in June. Without `position`, solar times are now computed at the theatre's point; an explicit one still wins, warned when off the map. `campaign next` was not affected.

### [FIX-CONVOY-FROZEN-STANDOFF](FIX-CONVOY-FROZEN-STANDOFF/PRD.md) · ✅

A convoy held at its standoff in front of an enemy DCS does not make it engage stayed frozen for ever (*Kolkhida* test, 2026-10-10). A fighting convoy with an enemy in sight and no shot fired or taken for 2 minutes now drives onto the nearest enemy. R48 in game (2026-10-15): both sides fired at once, no push, the convoy drove on after the fight; the push itself not seen in game.

### [FIX-CAMPAIGN-VISIBILITY-MISMATCH](FIX-CAMPAIGN-VISIBILITY-MISMATCH/PRD.md) · ✅

`campaign next` reported a drawn 10 000 m while the mission carried 80 km: the weather converter writes 9 km or more as DCS's maximum, a METAR's `9999`. The report now gives the value written and the convention is documented; what DCS flies is unchanged (David's option B, 2026-10-15). Kolkhida mission 2 was consistent: only its report was wrong.

### [FEAT-COMBAT-ZONE-ELEVATION](FEAT-COMBAT-ZONE-ELEVATION/PRD.md) · ✅

The zone's ground elevation at its centre in a combat zone's radio briefing, under the bullseye line, in feet and metres, only when the zone shows its position — one ticket done, tested on the mocks.

### [FIX-OPEN-TRAINING-NORMANDY-FINDINGS](FIX-OPEN-TRAINING-NORMANDY-FINDINGS/PRD.md) · ✅

What building the Normandy 1944 Open Training v6 through the MCP found, the first WW2 mission built this way: loadouts for module aircraft, era in the catalogue, CAS tables and shortcuts, 251 MHz refused by the editor, known limitations by area, theatre bounds — thirteen tickets done (#1136). Ticket 07 (`gun: 0` on ten WW2 slot templates) closed unmeasured by David, the known limitation stays; ticket 15 measured in DCS, not a defect.

### [FIX-OPEN-TRAINING-FALKLANDS-FINDINGS](FIX-OPEN-TRAINING-FALKLANDS-FINDINGS/PRD.md) · ✅

What building the Falklands Open Training v6 found: the map missing from the theatre table and its frequency and parking data left uncommitted, a FARP on a lake or on a tower frequency, a convoy that starts off road at 5.6 m/s, no warning for a group inside a combat zone's circle, ground placement unchecked with no clear-ground catalogue — all delivered. Ticket 06 (a convoy-on-road action through the bridge) closed unbuilt by David: we will see in game.

### [FIX-AIR-SLOT-HEADING](FIX-AIR-SLOT-HEADING/PRD.md) · ✅

An air-start player slot flew north whatever its heading: DCS orients an air start toward its second waypoint, as the Mission Editor's own files show. `add_player_slot` now writes one 10 km ahead on the heading; measured in DCS, a slot asked for 180° flew 180.5°.

### [FEAT-SINAI-PARKING-DATA](FEAT-SINAI-PARKING-DATA/PRD.md) · ✅

Sinai ships its parking capture: 3 614 stands on 56 airfields, taken in DCS on 2026-10-12 for the Sinai Open Training v6. `add_air_group` and `create_qra` start from the ramp or the runway there, and the build filters Sinai's dynamic-slot stock by what each parking accepts.

### [FIX-SECURITY-GROUP-LEVEL](FIX-SECURITY-GROUP-LEVEL/PRD.md) · ✅

Every secured `+` radio command was refused to every pilot whenever security was on, since 6.14.0: the group's level went through `Group.getByID`, which DCS does not have. The occupants now come from `coalition.getPlayers`, and `RADIO` pulls in `SECURITY` so `/secu elevate` exists. Merged in #1120; *Escort me* seen working on `private1` on 2026-10-10 with *Kolkhida* mission 2 rebuilt.

### [FIX-QRA-GROUND-START](FIX-QRA-GROUND-START/PRD.md) · ✅

A QRA scrambled from the runway was destroyed 5 s later: the watchdog took a group not yet airborne for a landed one and reset the QRA. A group is now landed only once it has flown; one still on the ground ten minutes after the scramble is reset as before. Seen in game: wheels up 25–35 s after the scramble. Merged in #1118.

### [FIX-CAPTURE-ZONE-MEMBERSHIP](FIX-CAPTURE-ZONE-MEMBERSHIP/PRD.md) · ✅

Poti, taken on *Kolkhida* by the blue convoy, drew a garrison anyway: the capture trusted `world.searchObjects`, which overshoots its sphere, and the absorption measured the exact distance. Both now ask the same search; a strong enough assault convoy drives into its target zone while fighting; a shell is never a threat. To be checked in game, with ticket 02's measurement of why the convoy halted at the zone's edge (test mission ready). Seen in game 2026-10-10: the convoy became Poti's garrison and drove on to the centre.

### [FIX-MCP-SESSION-PREP-FINDINGS](FIX-MCP-SESSION-PREP-FINDINGS/PRD.md) · ✅

What preparing the *Kolkhida* in-game test through the MCP broke: `loadout_from` failing on pylons numbered 1 to n, two groups of one name written, then both removed by `remove_group`; and CTLD `2.0.0-rc13` vendored, the release that gives crates a country of the coalition. Merged in #1116.

### [CHORE-BACKLOG-INDEX-SPLIT](CHORE-BACKLOG-INDEX-SPLIT/PRD.md) · ✅

The backlog index split into active, ready and done indexes, one short paragraph per lot; the archived lots got their own index (#1058).

### [CHORE-DCS-SCHEMA-V0-5-0](CHORE-DCS-SCHEMA-V0-5-0/PRD.md) · ✅

dcs-world-schema `v0.5.0` vendored: the scripting API and the LuaLS annotations do not move, only reference-data types grow; closes #1076.

### [CHORE-DROP-MACOS-INTEL](CHORE-DROP-MACOS-INTEL/PRD.md) · ✅

The macOS Intel target leaves the release matrix: it never published an asset and held the 6.27.0 run open overnight.

### [CHORE-REQUIRED-CHECKS-GATE](CHORE-REQUIRED-CHECKS-GATE/PRD.md) · ✅

Path-filtered workflows made usable as required checks; the 11 checks are now required on `develop`, so auto-merge waits for them.

### [CHORE-VENDOR-CTLD-RC12](CHORE-VENDOR-CTLD-RC12/PRD.md) · ✅

CTLD `2.0.0-rc12` vendored (#1051): reoccupied slots, `EXZ_` extraction zones, UH-1H / Mi-8MT catalogue changes.

### [DOC-ENTRY-POINTS](DOC-ENTRY-POINTS/PRD.md) · ✅

The main ways into the docs made obvious: "I want to…" cards on the home page and the Mission Maker overview, the AI pages right after the tutorial in the menu, and the Mission Maker labels that showed in English on the French site translated (#1112).

### [DOC-TUTORIAL-NEXT-STEPS](DOC-TUTORIAL-NEXT-STEPS/PRD.md) · ✅

The tutorial stops before the three things a mission maker does next: set the tool's language, get security back for the server build through a profile, and update the tools.

### [FEAT-AI-ASSISTANT-ANY-CLIENT](FEAT-AI-ASSISTANT-ANY-CLIENT/PRD.md) · ✅

Using VMCT with Claude, Gemini or another AI: the tutorial points to the install page from its first lines, the install page covers another MCP client and a chat AI without MCP, and the server serves the authoring skill to any client through `describe_authoring_guide` (#1110).

### [FEAT-AIRCRAFT-ROLES](FEAT-AIRCRAFT-ROLES/PRD.md) · ✅

One way to spawn an aircraft with a job: `veafAircraftSpawn` roles, given to QRA and AirWaves CAP groups at clone time. Verified in game (R21).

### [FEAT-AIRFIELD-CHANNELS-FROM-DCS](FEAT-AIRFIELD-CHANNELS-FROM-DCS/PRD.md) · ✅

Airfield radio channels generated from DCS's own reference instead of typed by hand, plus a CLI/MCP tool writing the channels a mission's fields deserve (#1041).

### [FEAT-CTLD-AIRBASE-LOGISTICS](FEAT-CTLD-AIRBASE-LOGISTICS/PRD.md) · ✅

Airfields become CTLD logistic zones (#1007): blue-from-start fields keep them, captured ones after two minutes of ground presence, marked by a green circle. Seen in game 2026-10-03: at Ramstein a C-130 parks 997 m out, so a mission raises `airbase_logistics_radius` (1 100 m there).

### [FEAT-DCS-REFERENCE-DATA](FEAT-DCS-REFERENCE-DATA/PRD.md) · ✅

Airfield names, ids and positions generated from the `dcs-world-schema` reference database (positions now on the runways' centre), numeric callsigns for the ten countries the Mission Editor numbers. Liveries and spotter sight dropped on measurement. #1098.

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

### [FIX-RADIO-MENU-ID-RECYCLING](FIX-RADIO-MENU-ID-RECYCLING/PRD.md) · ✅

A VEAF F10 menu left open fires another command than the one the player sees: DCS gives a removed entry's id to the next one created, and the builder recreated the whole tree on every refresh. Measured in game 2026-10-09; the render is now incremental, each freed id parked on an inert command, pages stable (#1113).

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

### [FEAT-PORTABLE-PREFABS](FEAT-PORTABLE-PREFABS/PRD.md) · 🚫

Bundling mission content to reuse elsewhere: nobody asked for it, its selection front end lives in the Mission Editor that ADR 0017 rules out, and the MCP composites already place the same content.
