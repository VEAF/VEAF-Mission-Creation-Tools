# Backlog — VEAF Mission Creation Tools v6

Per-lot backlog. Active lots are directories under `.backlog/<LOT-ID>/`; completed
lots are compacted into `.backlog/archive/<LOT-ID>.md`. Sequencing lives in
[ROADMAP](../ROADMAP.md); this index is the source of truth for **scope and status**.

## Legend

- **Status**: ⬜ ready · 🔄 in-progress · 🧑 waiting-human · ⏸ paused · ✅ done · 🚫 wontfix
- ⏸ **paused** is *deliberately parked*, not blocked: unlike 🧑 nothing is expected of
  anyone, and unlike ⬜ an agent should not pick it up. See
  [`docs/agents/triage-labels.md`](../docs/agents/triage-labels.md).

## Active lots

| Lot | Status |
|-----|--------|
| [FIX-MARKER-PARAM-CRASHES-2](FIX-MARKER-PARAM-CRASHES-2/PRD.md) — the sequel exists because the first lot's "family closed" claim rested on **thirteen hand-picked cases**, not a sweep. Re-run with every keyword **enumerated from the source** (`veafSpawn`'s 53 read from `ParameterRules`), each tried bare, non-numeric, negative and huge, plus degenerate inputs — **485 cases** — three sites still raised: `_transport, from`, whose string keyword the first lot never probed after fixing that module's three numeric ones, and `_spawn` on `defense`/`armor`/`disperse`/`delayed`. Groups B and C are clean across 75 further cases. **The finding outlives the fix**: four of the nine live in `veafSpawnParser`, the module the refactor plan designates as the *source* of the shared parser for being declarative and "proven in production" — `VMR-025` fixed `_num` and left its sibling `_numNonNegative` directly below it. VMR-019's pattern a third time, inside the module held up as healthy; that phrase was an assumption and the PRD now rests on measurement. The sweep ships as a test reading `ParameterRules`, so tomorrow's unguarded parameter fails in CI — proven by injecting one and watching it fail by name | ✅ |
| [FIX-MARKER-PARAM-CRASHES](FIX-MARKER-PARAM-CRASHES/PRD.md) — six marker parameters still take the whole command down when the pilot omits or mistypes their value, proven by a `pcall` probe over the real parsers: `_cas, side`, `_move group, name`, and `_transport` on `size`/`defense`/`blocade`. `VMR-019` fixed exactly this shape and introduced `veaf.safeNumber` for it, but reached only four sites in `veafCasMission` — it left that module's `%s`-on-nil log for `side`, never scoped `veafMove`, and **never touched `veafTransportMission` at all**, whose `size` is the same parameter with the same 1..5 bounds and still carries the original `tonumber(val) <= 5`. That is the argument for `REFACTOR-MARKER-PARSER` stated as a bug: the code is copied, so a fix reaches one copy. Runs **before** that lot on purpose — its first ticket pins today's behaviour so the refactor is reviewable, and six of those behaviours are crashes. **Fixed**, with a control worth keeping: among the new tests, `_cas, size` and `_cas, size banana` passed *before* the fix, which is what proves the suite measures the VMR-019 gap rather than the parsers in general | ✅ |
| [FIX-ATIS-NIL-MESSAGE](FIX-ATIS-NIL-MESSAGE/PRD.md) — a pilot asking for ATIS at a vanished airbase got a **DCS scripting error from a display call**, not a message: issue #302's crash was fixed where the value is *computed*, so the `nil` travelled one level further and reached `trigger.action.outTextForUnit` unchecked — reading in `dcs.log` as a weather bug rather than as "somebody passed nothing". Fixed at two levels on purpose: the ATIS path names the airbase, and `veaf.outTextForUnit` **refuses a nil or blank message**, a floor under dozens of callers. Picks up the half of **[MacFlorent's PR #303](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/303)** nobody reviewed, with the message routed through `veaf.t` since his was hardcoded English. The path had no coverage at all | ✅ |
| [REVIEW-SECURITY-LAYER](REVIEW-SECURITY-LAYER/PRD.md) — review the security layer David was uneasy about. The per-player identity path already exists end to end, but `veafSecurity.authenticated` is **one global boolean** tested first, so a single `/login` unlocks every secured command for everyone; and the tier ordering contradicts its own documentation (`L0` is the tightest, the guide said the loosest). Both shipped in **#676** — tiers renamed with deprecated aliases, authentication per **group** (a group acts at its lowest occupant's level, since `missionCommands` cannot tell which occupant clicked), plus a bounded 2-minute elevation. Ticket 03 came later and from a different method: **running** the converted demo mission in DCS showed security silently off, and the log said why — `veafSecurity.SecurityDisabled` was a **public config field** that missions set, retired as dead code by SECREV-009 because nothing *in the repository* assigned it. Fail-safe, so three years of missions broke quietly | 🔄 |
| [SECREV-2](SECREV-2/PRD.md) — act on `CODE_DOC_REVIEW_2026-07-01.md`, a 140-finding security review that sat untracked at the repository root for a month, with every finding checked for currency rather than taken on trust. Tickets 02 and 03 delivered — both criticals, the shell command built from marker text, and the four marker handlers that ran for anyone. **The server hook was deployed by David on 2026-08-11**, so both criticals are finally closed in production and not only in the repository. Ticket 04 delivered its two integrity findings — the updater verified nothing whenever its metadata was absent (four fall-through paths, not the two reported) and `read_miz` read archive members with no cap at all; the publish side was hardened with them, since a fail-closed updater turns any silent gap in publishing into an uninstallable release. Ticket 05 closed both high-severity correctness bugs, each proven by a failing test before being fixed: enabling the DCS bridge silently rewired **every** pre-existing trigger to the wrong condition/action pair (the shift moved the Lua strings without rewriting the indices they hardcode), and the live METAR fetch never fetched — `Metar(icao)` constructs, `.update()` fetches, so missions asking for live weather got canned weather while the log claimed success. Ticket 04's network-download caps, plus 06-07, remain | 🔄 |
| [TOOLING-REPO-LINK-GATE](TOOLING-REPO-LINK-GATE/PRD.md) — `docs-check` guarded the published documentation and stopped there, leaving 340 files unchecked — **92 links were broken, 68 of them a regression from the archive sweep (#655)**, because line-level verification is not link validity. Repaired candidate-first, 0 ambiguous cases. Ticket 04 asked David keep/fix/delete on the historical documents and he chose **exempt**: repairing a record of a past state into one that never existed is worse than a link that does not resolve. Deletion refused for now — `SECREV-2` still sources open tickets from `CODE_DOC_REVIEW_2026-07-01.md` | ✅ |
| [FEAT-MCP-MUTATION-ACTIONS](FEAT-MCP-MUTATION-ACTIONS/PRD.md) — the MCP can **create** a mission but cannot **change** one: not one of its 29 actions mutates an object the mission already contains, so "move that group 5 km east" is impossible while every other link in the chain exists. Ticket 01 triages by mission-maker **intent** rather than porting dcs-sms's 126 verbs, and decides what the later tickets even are | ⬜ |
| [FEAT-DCS-SMOKE-HARNESS](FEAT-DCS-SMOKE-HARNESS/PRD.md) — assert VEAF behaviour inside a running DCS, since `test-lua` asserts against mocks we wrote and can only confirm what we already believed. **Its evidence clause is met**: run on the DCS workstation it closed `FEAT-COMBATZONE-MENU-COALITION` and answered the `Disposition` probe, at the cost of three of its own defects — all the same mistake, *"it came back" is not "it worked"*. Launch/load/quit and the committed test mission remain | 🔄 |
| [TOOLING-DOC-AUTOGEN](TOOLING-DOC-AUTOGEN/PRD.md) — scoped as *generate two references*, shipped as a **drift check**, because checking the premise showed both were wrong — one page is not a rendering of any data file, and the other tells mission makers they need not know the technical names. Asserts instead that every name the code defines is mentioned by the page documenting it; proven by two live gaps | ✅ |
| [FEAT-PORTABLE-PREFABS](FEAT-PORTABLE-PREFABS/PRD.md) — **a design lot, not a port**. A prefab bundles mission content — groups, statics, zones, drawings, media *and its mod dependencies* — and re-instantiates it elsewhere with an anchor and a country, which is what the MCP composites already do in code-shape rather than data-shape. Blocked structurally: TUM's version is GPL and leans on the live editor ADR 0017 rejected, so how a mission maker *picks* what goes in has to be invented. **A rejection is an acceptable outcome** | ⬜ |
| [REFACTOR-CLI-COMMAND-TREE](REFACTOR-CLI-COMMAND-TREE/PRD.md) — file the 25 commands by **subject** instead of by verb. The wizard already groups them, so the question was whether that grouping works, and measuring it said no: `config` holds **10 of 21** and mixes starting, converting, configuring and `ask` — a group holding half the options narrows nothing. Worse, the split is by verb, so `inject-waypoints` and `extract-waypoints`, the two halves of one job, sit in different menus and you must know which direction you are going before you can find either. The CLI has no tree at all. Five groups replace four, the largest drops to 6, and **nothing breaks**: every flat name stays registered with `hidden=True`, so `veaf-tools build` keeps working while `--help` shows only the tree. **Done**: five headings instead of four, largest down to 6 of 21, `extract`/`inject` pairs adjacent, all asserted. Two findings on the way — the CLI↔TUI bridge really did break on the grouped form, as ticket 02 predicted, and the new `docs-check` coverage rule (which first passed while extracting **zero** names, anchored on `$` without MULTILINE) then reported **16 of 30** commands missing from the guide's table | ✅ |
| [FIX-COMMUNITY-SOUNDS-PRUNED](FIX-COMMUNITY-SOUNDS-PRUNED/PRD.md) — opening a built mission in the DCS Mission Editor and saving it **deletes the CSAR and beacon sounds**. Measured by diffing the archives: five files gone, none of them in `mapResource`, so the editor prunes them as orphans — it cannot know CTLD and CSAR ask for them by filename at runtime from a script it never reads. The gap is deliberate: `BUILD-COMMUNITY-SOUNDS-001` scoped itself *"files-only — no mapResource entry, no out_sound trigger"* and the sequel lived only in a code comment. The build already knows how to **remove** the legacy preload trigger; it never learned to create it. The recipe was in the v5 missions themselves — play each sound to a country nobody uses. **Fixed**, with the ticket's own scope corrected mid-flight: written as *"when CTLD or CSAR is enabled"* it did not fix the reported bug, because the measured sounds came from the mission's own folder with both modules **disabled**. The rule is about orphan sounds, not about CTLD. The country now comes from the **top** of the DCS table too — `min` would have handed out id 3, Turkey, on a Syria map | ✅ |
| [CHORE-SMS-QUICK-WINS](CHORE-SMS-QUICK-WINS/PRD.md) — three small things from the dcs-sms study, grouped so they ship together: document the DCS coordinate convention (the mission table is `{x=north, y=east}`, a runtime vec3 is `{x=north, y=altitude, z=east}`, and confusing them is silent), ship the authoring skill to agents beyond Claude, and a `dev_condition` hatch so a checklist step can be tested without staging the cockpit | ⬜ |
| [FIX-LUA-RUNNER-VERSION-CHECK](FIX-LUA-RUNNER-VERSION-CHECK/PRD.md) — `test-lua` took the first `lua` on PATH without asking its version, so on a workstation where that is 5.4 the whole suite ran on an interpreter the VEAF scripts do not target — **34 failures on a clean checkout**, reported as if the code were broken, and green in CI. Every candidate is now version-checked | ✅ |
| [FEAT-SCENERY-AWARE-SPAWN](FEAT-SCENERY-AWARE-SPAWN/PRD.md) — ground units stop spawning inside villages and forests: placement knew only water from land, so a marker over a hamlet put a platoon in the houses. Three bounded tiers around `Disposition`, an undocumented native DCS singleton from TUM ([ADR 0018](../docs/adr/0018-undocumented-dcs-api-dependency.md)). **Probe answered in game 2026-08-06, avoidance included** — and it found a correctness bug in the day-old code: the singleton's radius does not bound its answers, and tier 1 had no distance test, so a spawn could move kilometres in silence | ✅ |
| [FEAT-ASSIST-CHECKLISTS](FEAT-ASSIST-CHECKLISTS/PRD.md) — a **guided-checklist engine** driven by YAML: the mission boxes the cockpit control the current step needs and ticks the line when it reaches the right position, F-16C cold start first. Emits **zero trigger rules** — the machinery ED's own training missions use is one `net.dostring_in` away — and displays as a generated image, since ED keeps a picture up at duration 0. Step order still wants a pilot's sign-off | ✅ |
| [FEAT-ASSIST-AUTHORING](FEAT-ASSIST-AUTHORING/PRD.md) — make a guided checklist writable by an **instructor** rather than a developer: `control: bouton power sur main pwr` instead of an element id read out of `clickabledata.lua`. Resolvable because that file is regular, but hint order is **not** value order, so the build never depends on a language model — a deterministic matcher, an explicit refusal, and in-game verification. **Paused by David 2026-08-03** | ⏸ |
| [FEAT-COMBATZONE-MENU-COALITION](FEAT-COMBATZONE-MENU-COALITION/PRD.md) — every combat zone's F10 submenu was global, so with red-side zones possible either side could activate the other's. Coalition-scoped nodes with the side inherited down the subtree (ADR 0013). **DCS confirmed 2026-08-06 to accept a scoped submenu under a global parent**, by the smoke harness rather than by a person. **Changes existing missions**; `radio_menu_coalition: ALL` restores the old behaviour | ✅ |
| [FEAT-CUSTOM-SCRIPT-LOAD-DELAY](FEAT-CUSTOM-SCRIPT-LOAD-DELAY/PRD.md) — adopting a third-party mission flattens its **staggered** script loading: Foothold loads in four waves, AIEN at **12 s**, and the built `.miz` fires all fourteen scripts at once. Declared order survives; wall-clock delay does not. **Open question first**: run the built mission and read `dcs.log` for AIEN/CTLD init errors — nothing broken makes this a fidelity nicety, something broken makes it a correctness bug for every adopted mission | ⬜ |
| [FIX-RADIO-LAYOUT-GAPS](FIX-RADIO-LAYOUT-GAPS/PRD.md) — three gaps in the preset-plan radio data, all surfaced by converting Foothold over a 32-type fleet: a radio-compass classified as an FM radio (so a 30-channel list lands on an ADF), two of the AJS-37's seven specials stripped before the mission is written, and **no Flaming Cliffs aircraft at all** in `dcs-radio-specs.yaml` — where the ticket's plan to hand-write specs died on measurement: 110 FC3 player slots across 40 real missions carry no `Radio` table against 2105 non-FC3 slots that do, so DCS has no settable radio there and specs would have been invented hardware. David chose the **kneeboard** as the deliverable, all three bands; the ten types are declared `kneeboard_only` and the build writes nothing into them. Foothold's legacy override is gone (03). **Lot closed**: ticket 01's last open item — seeing the ADF leave the out-of-range report — turned out not to need the Foothold folder it was waiting on, since the local missions carry player slots for all four affected types; looking for the *aircraft* instead of the *mission* unblocked it, and it caught a docstring the fix itself had falsified. Gap 2 was rewritten on 2026-08-09 after David pushed back that Tripack had flown missions with those frequencies: he was right, and the dates say why — the out-of-range guard landed a month **before** the AJS-37 layout, and it exists so the *Mission Editor* can save, a path veaf-tools never takes. **Answered in game 2026-08-09**: the editor loads a v6 mission carrying 30-34 MHz on an AJS-37, saves it, and keeps every value unchanged. So `dcs-radio-specs.yaml` is simply wrong about this airframe and the guard has been deleting legal channels since July — a data fix with no trade-off to weigh | ✅ |
| [CHORE-TOOLING-GATES](CHORE-TOOLING-GATES/PRD.md) — three tooling items surfaced by the Foothold intake. **01 done**: the batch conversion script versioned, picking each mission's profile by content. **02 done**: both `.spec` files deleted — they claimed to bundle `convert-profiles` while the build ignored them entirely and had silently diverged (4 declared entries against a dozen assembled), the lie that made a missing-profiles bug hard to spot; `_veaf_tools_extra_data` is now stated as the single source of truth where someone will look. **03 done**: the ruff gate covers `src/python/ test/python/ veaf_build/`, and the workflow's **trigger paths** were widened with it — without that the wider gate would never have fired on a test-only change | ✅ |
| [REFACTOR-MARKER-PARSER](REFACTOR-MARKER-PARSER/PRD.md) — `SECREV-2` recommended fixing a family of crashes "in the shared marker parser", and there is none: the same `key value` loop is copied across the codebase, so a fix reaches the copy it was written against. Proven twice — VMR-019 fixed this crash shape four times in one function, and `FIX-MARKER-PARAM-CRASHES` then found **six live crashes it had missed**, three of them in a module the fix never scoped. **Inventory re-measured 2026-08-11 and the original was wrong on three counts**: not ten modules but nine (`veafRemote`'s was deleted by VMR-130), not one shape but three — 6 parsers take comma-separated pairs (575 lines) and are the target, 4 more loops hide under other names (~87 lines, missed because a search for `markTextAnalysis` cannot find them), and 3 are positional or a single regex (77 lines) and are **deliberately excluded**, since a comma-splitting parser would truncate a password or a point name. And `veafSpawnParser` is already declarative, so it supplies the machine rather than being the seventh target: the migration order inverts to put it first. Characterise, lift, migrate — behaviour identical throughout, which is what makes it reviewable. **Ticket 01 done**: every group A and B parser now has a suite pinning today's behaviour, and the quirk inventory went from 10 items read out of the code to **19 measured** — nine of them invisible from reading, such as a value keeping everything after the *first* space (so `side  BLUE` with two spaces silently means RED) and sub-verb chains being decided by the chain's order rather than the text's. Two findings changed the plan: `veafRadio`'s `elseif`, billed as the one structural difference worth migrating first, is **not observable** — no key is claimed by two live branches, so the permissive form is behaviour-preserving, now pinned by a test instead of argued; and the three `veafShortcuts` group-B loops are **not functions** at all but steps inside `execute`, characterised through spies on what they hand downstream, so ticket 03 must extract before it can migrate. Two new defects recorded, both wrong-input-accepted rather than crashes: `veafGroundAI` accepts an empty handler name (the same `""`-is-truthy guard bug SECREV-010 fixed in `veafMove`), and `_radio transmit, freq` destroys the `frequencies` default so the command does nothing at all without telling the pilot | 🔄 |
| [FIX-CONVERT-V5-PRESETS-SCHEMA](FIX-CONVERT-V5-PRESETS-SCHEMA/PRD.md) — a v5 `presets.yaml` survives `convert-v5` untouched and then kills the build. The converter treats `src/presets.yaml` as its *target*, so a file already sitting there is left alone — right for a v6 file, wrong for a v5 one that shares the name and the file format while its **schema** is the one thing that changed. Walking the demo file down by hand found **three** renames before the walk was abandoned, each announcing itself as an unattributed `AttributeError`. The build produces the `.miz` first and dies after, so it reads as "presets are broken" rather than "this mission never converted". Worse than the gap itself is the message: `'dict' object has no attribute 'lower'`, naming no file, no key and no expectation — and a third defect underneath both: `read_yaml` drops every unrecognised top-level key in silence, which is how a renamed block surfaced as an error accusing the one part of the file that was correct. Found converting the repository's own demo mission. **Fixed**: the loader now names the key, what it found and what belongs there — and refuses an unknown section instead of dropping it, which is a deliberate behaviour change. `convert-v5` detects the v5 schema **by structure** and rewrites the file in place. The diff turned out to be **six** renames, not one; the only thing not carried over verbatim is a radio's `type:`, mandatory in v6 and absent from v5, now inferred from the frequencies — and the acceptance test, the demo mission migrated then read by the real reader, is what caught that reading the code had got it wrong | ✅ |
| [ENRICH-DEFAULT-PRESETS](ENRICH-DEFAULT-PRESETS/PRD.md) — broaden the shipped default radio presets (fold into / sequence after FEAT-RADIO-PRESET-PROJECTION phase 1) | ⬜ |
| [REFACTOR-WORKER-TEST-FACTORY](REFACTOR-WORKER-TEST-FACTORY/PRD.md) — adding a field to `MissionBuilderWorker.__init__` broke a scattered set of test files, twice in one day. `__init__` reads `mission.yaml` and checks the loader on disk, so 14 files skipped it with `object.__new__` — **20 sites** — and each set a *different subset* of the 28 fields by hand. Every shell is therefore a partial copy of the field list, and a new field surfaces as an `AttributeError` naming something the failing test never heard of: `collected_community_sound_files` (#681), then `_dcs_bridge_temp_file` (15 files, two of them fixtures **inside** test classes that a grep over module-level helpers missed). **Done**: one `make_worker(**overrides)` defaults every field, keeps the "no mission folder needed" property that made these tests fast, and refuses an unknown key instead of silently creating an attribute nothing reads. The one edit is *enforced* rather than hoped for — a contract test `ast`-reads the `self.<field>` assignments out of `__init__`, branches included, and fails naming the field and the file, proven by injecting one. Test-side only, no production code touched | ✅ |

## Archived lots

One row per closed lot, oldest scope preserved in its file. A lot lands here once it has
been closed for more than 3 days; the archive holds its PRD and every ticket in full.

| Lot | Status |
|-----|--------|
| [BUILD-AUTOVERSION](archive/BUILD-AUTOVERSION.md) — auto-compute the release build number | ✅ |
| [BUILD-COMMUNITY-SOUNDS](archive/BUILD-COMMUNITY-SOUNDS.md) — Build owns CTLD/CSAR sound preloading | ✅ |
| [BUILD-PUBLISH-LOCAL](archive/BUILD-PUBLISH-LOCAL.md) — local publish mode for `veaf-build` | ✅ |
| [CHATBOT-CLI-WORKER](archive/CHATBOT-CLI-WORKER.md) — `ask` proxies the Worker (no user key) | ✅ |
| [CHATBOT-CLI](archive/CHATBOT-CLI.md) — doc chatbot as a `veaf-tools` CLI command + TUI entry | ✅ |
| [CHORE-RENAME-DEVELOP](archive/CHORE-RENAME-DEVELOP.md) — `develop-v6` → `develop` + canonical gitflow for releases | ✅ |
| [CI-NODE24](archive/CI-NODE24.md) — Migrate GitHub Actions off deprecated Node.js 20 | ✅ |
| [CLEANUP-LUPA](archive/CLEANUP-LUPA.md) — remove the dead `lupa` dependency | ✅ |
| [CLI-TUI-BRIDGE](archive/CLI-TUI-BRIDGE.md) — fall back to the TUI for missing options | ✅ |
| [CMT-YAML-DOCS](archive/CMT-YAML-DOCS.md) — doc comments and links in generated `mission.yaml` files | ✅ |
| [CONVERT-CUSTOM-LOADER-HINT](archive/CONVERT-CUSTOM-LOADER-HINT.md) — guide custom Lua loaders to v6 `custom_scripts:` | ✅ |
| [CONVERT-V5-UX](archive/CONVERT-V5-UX.md) — Two convert-v5 output/UX improvements (both in `v5_converter.py`). | ✅ |
| [CUSTOM-SCRIPTS-TRIGGERS](archive/CUSTOM-SCRIPTS-TRIGGERS.md) — unify trigger emission, fix custom_scripts loading | ✅ |
| [DCS-UPDATE-VERIFY](archive/DCS-UPDATE-VERIFY.md) — post-DCS-update verification campaign | ✅ |
| [DCSDATA](archive/DCSDATA.md) — DCS country data pipeline, missing-id crash fix, and generator consolidation | ✅ |
| [DOC-AUDIT-PASS](archive/DOC-AUDIT-PASS.md) — full documentation audit: coverage, correctness, both languages, no orphans | ✅ |
| [DOC-CHATBOT](archive/DOC-CHATBOT.md) — free RAG documentation chatbot embedded in the MkDocs site | ✅ |
| [DOC-DEV-MODE](archive/DOC-DEV-MODE.md) — documenter dev_mode + scripts_path ✅ | ✅ |
| [DOC-GUIDE-ANCHORS](archive/DOC-GUIDE-ANCHORS.md) — The `# Doc:` links in a generated `mission.yaml` (from `convert-v5`) did not resolve: | ✅ |
| [DOC-OVERHAUL](archive/DOC-OVERHAUL.md) — Complete, detailed, bilingual, ELI5 documentation | ✅ |
| [DOC-QUALITY-GATE](archive/DOC-QUALITY-GATE.md) — the documentation gets the gate every other artifact already had | ✅ |
| [DOC-REVIEW](archive/DOC-REVIEW.md) — full documentation proofreading pass | ✅ |
| [DOC-TRIPACK-FEEDBACK](archive/DOC-TRIPACK-FEEDBACK.md) — Documentation-only lot from Tripack's feedback. No code changes, no PR — direct | ✅ |
| [DYNSLOT-WAREHOUSE](archive/DYNSLOT-WAREHOUSE.md) — Wire dynamic-slot templates into the `.miz` warehouses | ✅ |
| [ENRICH-PREPARE-TEMPLATE](archive/ENRICH-PREPARE-TEMPLATE.md) — `prepare` generates the same rich mission.yaml preamble as convert-v5 | ✅ |
| [FEAT-ACTIVATION-CONTROLS](archive/FEAT-ACTIVATION-CONTROLS.md) — QRA start state + combat-zone completability in YAML | ✅ |
| [FEAT-AIRBASE-DUMPS-ALL-THEATRES](archive/FEAT-AIRBASE-DUMPS-ALL-THEATRES.md) — the last 7 theatres, captured by Reaper | ✅ |
| [FEAT-AIRDROMES-RUNTIME-SOURCE](archive/FEAT-AIRDROMES-RUNTIME-SOURCE.md) — Airdrome table from runtime dumps | ✅ |
| [FEAT-AIRFIELD-FREQS-DATA](archive/FEAT-AIRFIELD-FREQS-DATA.md) — bundle DCS airfield ATC frequencies per theatre | ✅ |
| [FEAT-ALL-THEATRE-COORDS](archive/FEAT-ALL-THEATRE-COORDS.md) — all DCS theatres for coordinate conversion (source: VEAF/dcs-maps) | ✅ |
| [FEAT-BLANK-MISSION-THEATRE](archive/FEAT-BLANK-MISSION-THEATRE.md) — synthesize a blank mission per theatre | ✅ |
| [FEAT-BUILD-VALIDATE-REFS](archive/FEAT-BUILD-VALIDATE-REFS.md) — build-time validation of mission.yaml references to Mission-Editor objects | ✅ |
| [FEAT-COMBATZONE-ACTIVATE](archive/FEAT-COMBATZONE-ACTIVATE.md) — declaratively activate combat zones at mission start | ✅ |
| [FEAT-COMBATZONE-RADIO-GROUPS](archive/FEAT-COMBATZONE-RADIO-GROUPS.md) — combat-zone radio grouping + global menu pagination | ✅ |
| [FEAT-COMBATZONE-RED-SIDE](archive/FEAT-COMBATZONE-RED-SIDE.md) — a combat zone can be played from the red side | ✅ |
| [FEAT-COMMUNITY-TOGGLE](archive/FEAT-COMMUNITY-TOGGLE.md) — Enable/disable community scripts from mission.yaml | ✅ |
| [FEAT-CONVERTV5-FREQ-ALIASING](archive/FEAT-CONVERTV5-FREQ-ALIASING.md) — replace hardcoded preset freqs with readable aliases | ✅ |
| [FEAT-CONVERTV5-PLAN-PRESETS](archive/FEAT-CONVERTV5-PLAN-PRESETS.md) — Type: feat · ADR 0010 | ✅ |
| [FEAT-CROSSPLATFORM-BINARIES](archive/FEAT-CROSSPLATFORM-BINARIES.md) — The release only ships Windows executables (`veaf-tools.exe`, `veaf-tools-updater.exe`) | ✅ |
| [FEAT-CTLD2-INTEGRATION](archive/FEAT-CTLD2-INTEGRATION.md) — replace the bundled CTLD v1 with CTLD 2 | ✅ |
| [FEAT-CUSTOM-SCRIPTS](archive/FEAT-CUSTOM-SCRIPTS.md) — custom_scripts section in mission.yaml | ✅ |
| [FEAT-DCS-BRIDGE](archive/FEAT-DCS-BRIDGE.md) — Optional dcs-bridge.lua injection | ✅ |
| [FEAT-EXPORT-BFR-PARSER](archive/FEAT-EXPORT-BFR-PARSER.md) — `veaf-tools export` as the safe mission parser for the BFR plugin | ✅ |
| [FEAT-EXPORT-MISSION](archive/FEAT-EXPORT-MISSION.md) — safe `.miz` export (JSON / YAML / Markdown) for interop & the BFR plugin | ✅ |
| [FEAT-FOOTHOLD-PRESETS-PLAN](archive/FEAT-FOOTHOLD-PRESETS-PLAN.md) — move the Foothold `presets.yaml` to the preset-plan model | ✅ |
| [FEAT-FOOTHOLD-RELEASE-INTAKE](archive/FEAT-FOOTHOLD-RELEASE-INTAKE.md) — adopt Lekaa's new release channel | ✅ |
| [FEAT-FOOTHOLD-V5-PARITY](archive/FEAT-FOOTHOLD-V5-PARITY.md) — two mission.yaml gaps the v5 Foothold relied on | ✅ |
| [FEAT-GEO-PLACEMENT](archive/FEAT-GEO-PLACEMENT.md) — place things by real-world geography | ✅ |
| [FEAT-GITIGNORE](archive/FEAT-GITIGNORE.md) — Template `.gitignore` VEAF MCT dans les defaults ✅ | ✅ |
| [FEAT-LUA-BUILD-STAMP](archive/FEAT-LUA-BUILD-STAMP.md) — single build stamp in the DCS log instead of per-module versions | ✅ |
| [FEAT-MCP-ADD-GROUP-FOLDER](archive/FEAT-MCP-ADD-GROUP-FOLDER.md) — make `add_group` write durably to the mission folder | ✅ |
| [FEAT-MCP-AIRBASES-WAREHOUSES](archive/FEAT-MCP-AIRBASES-WAREHOUSES.md) — airbase coalition, dynamic slots, alias-first | ✅ |
| [FEAT-MCP-MISSION-EDITOR](archive/FEAT-MCP-MISSION-EDITOR.md) — MCP server for LLM-assisted mission editing (v1: groups/units) | ✅ |
| [FEAT-MCP-ORACLE-COMMANDS](archive/FEAT-MCP-ORACLE-COMMANDS.md) — expose VEAF `#command` aliases in the oracle + fix binary bundling | ✅ |
| [FEAT-MCP-PLUGIN](archive/FEAT-MCP-PLUGIN.md) — ship veaf-mission-mcp as a self-hosted Claude plugin | ✅ |
| [FEAT-MIGRATE-MISSION-V6](archive/FEAT-MIGRATE-MISSION-V6.md) — promote `src/mission/` (the exploded `.miz`) from v5 to v6 on disk | ✅ |
| [FEAT-MODULE-UX](archive/FEAT-MODULE-UX.md) — Catégories, modules obligatoires, dépendances ✅ | ✅ |
| [FEAT-PRESETS-KNEEBOARD-TOGGLE](archive/FEAT-PRESETS-KNEEBOARD-TOGGLE.md) — disable preset kneeboard generation (with Tripack) | ✅ |
| [FEAT-PRESETS-PRIORITY-COLOR](archive/FEAT-PRESETS-PRIORITY-COLOR.md) — channel priority, colour & AJS-37 packing | ✅ |
| [FEAT-PROFILES](archive/FEAT-PROFILES.md) — profils de build dans mission.yaml ✅ | ✅ |
| [FEAT-RADIO-PRESET-PROJECTION](archive/FEAT-RADIO-PRESET-PROJECTION.md) — per-type radio-preset projection (preset plan model) | ✅ |
| [FEAT-RADIO-YAML-MENUS](archive/FEAT-RADIO-YAML-MENUS.md) — declare F10 radio menus in YAML (with Tripack) | ✅ |
| [FEAT-THIRD-PARTY-MODS](archive/FEAT-THIRD-PARTY-MODS.md) — strip third-party mod requirements at build | ✅ |
| [FEAT-YAML-MODULE-UX](archive/FEAT-YAML-MODULE-UX.md) — Module shorthand, uppercase community IDs, category sort | ✅ |
| [FIX-AIRCRAFT-DUPLICATE](archive/FIX-AIRCRAFT-DUPLICATE.md) — Duplicate aircraft groups in "add" injection mode | ✅ |
| [FIX-AIRCRAFT-INJECT-DICT-GROUP](archive/FIX-AIRCRAFT-INJECT-DICT-GROUP.md) — aircraft-group injection crashes when the group container is a dict | ✅ |
| [FIX-AIRCRAFT-ORPHAN](archive/FIX-AIRCRAFT-ORPHAN.md) — alerte fichier orphelin aircraft-templates.yaml ✅ | ✅ |
| [FIX-AIRWAVES-GENERATOR](archive/FIX-AIRWAVES-GENERATOR.md) — generated AirWaves configs call non-existent setters | ✅ |
| [FIX-AIRWAVES-OPTIONAL-TRIGGER-ZONE](archive/FIX-AIRWAVES-OPTIONAL-TRIGGER-ZONE.md) — trigger zone optional when center/radius are configured | ✅ |
| [FIX-ASSETS-NEWLINE](archive/FIX-ASSETS-NEWLINE.md) — ASSETS newline in Lua string ✅ | ✅ |
| [FIX-BATCH-MIZ-NAMING-CHECK](archive/FIX-BATCH-MIZ-NAMING-CHECK.md) — flag a built `.miz` whose name no longer matches mission.yaml | ✅ |
| [FIX-BRIEFING-MULTILINE](archive/FIX-BRIEFING-MULTILINE.md) — convert-v5 truncates multi-line Lua briefings | ✅ |
| [FIX-BUILD-BARE-NAME-PATH](archive/FIX-BUILD-BARE-NAME-PATH.md) — `build` with a bare mission name produces a relative output path | ✅ |
| [FIX-BUILD-COPY-DEFAULTS](archive/FIX-BUILD-COPY-DEFAULTS.md) — copy default mission.yaml before reading config | ✅ |
| [FIX-BUILD-PROFILES](archive/FIX-BUILD-PROFILES.md) — Two build-profile irritants, bundled (both touch profile resolution). | ✅ |
| [FIX-BUILD-VALIDATE-NONBLOCKING](archive/FIX-BUILD-VALIDATE-NONBLOCKING.md) — build references summary is non-blocking; operation zone_name not checked | ✅ |
| [FIX-BUNDLE](archive/FIX-BUNDLE.md) — VEAFCOMMANDS MISSING ✅ | ✅ |
| [FIX-CAP-MISSION-PREFIX](archive/FIX-CAP-MISSION-PREFIX.md) — cap_missions group validation must account for the OnDemand- prefix | ✅ |
| [FIX-CLEANUP-EXCLUDE-TOOLCHAIN](archive/FIX-CLEANUP-EXCLUDE-TOOLCHAIN.md) — The `convert-v5` leftover-file triage (CONVERT-V5-CLEANUP-FILES) listed | ✅ |
| [FIX-CLI-UTF8-ASK-STREAMING](archive/FIX-CLI-UTF8-ASK-STREAMING.md) — `veaf-tools ask` returned a **truncated** answer on Windows — cut off mid-sentence. | ✅ |
| [FIX-CONVERT-SPAWNABLES-FLAT-FORMAT](archive/FIX-CONVERT-SPAWNABLES-FLAT-FORMAT.md) — `convert-v5` generates an **empty** `spawnables.yaml` (and `dynamic-slot-templates.yaml`) | ✅ |
| [FIX-CONVERT-V5-COMMENTS](archive/FIX-CONVERT-V5-COMMENTS.md) — convert-v5 must ignore Lua comments | ✅ |
| [FIX-CONVERT-V5-DEFAULT-CWD](archive/FIX-CONVERT-V5-DEFAULT-CWD.md) — `convert-v5` uses current directory by default | ✅ |
| [FIX-CONVERT-V5-DEPS](archive/FIX-CONVERT-V5-DEPS.md) — Resolve module dependencies when generating mission.yaml | ✅ |
| [FIX-CONVERT-V5-INVALID-YAML](archive/FIX-CONVERT-V5-INVALID-YAML.md) — convert-v5 emits unparseable mission.yaml | ✅ |
| [FIX-CONVERT-V5-LOG-DEFAULT](archive/FIX-CONVERT-V5-LOG-DEFAULT.md) — convert-v5 defaults global_log_level to debug instead of info | ✅ |
| [FIX-CONVERT-V5-OPERATION-SUBZONES](archive/FIX-CONVERT-V5-OPERATION-SUBZONES.md) — convert-v5 loses a combat operation's sub-zones | ✅ |
| [FIX-CONVERT-V5-PRESETS](archive/FIX-CONVERT-V5-PRESETS.md) — Per-aircraft radio assignments in convert-v5 presets | ✅ |
| [FIX-CONVERT-WEATHER-I18N](archive/FIX-CONVERT-WEATHER-I18N.md) — Three `convert-v5` pipeline-conversion warnings in `v5_pipeline_converters.py` were | ✅ |
| [FIX-CONVERTER-YAML-I18N](archive/FIX-CONVERTER-YAML-I18N.md) — Syntax header + i18n comments in convert-v5 output | ✅ |
| [FIX-CONVERTV5-ICAO-MESSAGE](archive/FIX-CONVERTV5-ICAO-MESSAGE.md) — When `convert-v5` runs without `--icao` on a mission that uses realweather, it prints | ✅ |
| [FIX-CONVERTV5-PRESETS-OUTPUT](archive/FIX-CONVERTV5-PRESETS-OUTPUT.md) — cleaner convert-v5 presets.yaml (with David) | ✅ |
| [FIX-CTLD-NIL](archive/FIX-CTLD-NIL.md) — nil crash on ctld.builtFOBS / ctld.logisticUnits in scheduled fns | ✅ |
| [FIX-CTLD-REPACK-NIL-GROUP](archive/FIX-CTLD-REPACK-NIL-GROUP.md) — Reported by Tripack. A standalone technical analysis was produced as a deliverable for | ✅ |
| [FIX-DCS-MOCKS-COMPLETION](archive/FIX-DCS-MOCKS-COMPLETION.md) — fill the DCS-mock gaps surfaced by `audit-dcs-mocks` | ✅ |
| [FIX-DEFAULT-MODULES-ACTIVE](archive/FIX-DEFAULT-MODULES-ACTIVE.md) — default mission.yaml ships an active modules block | ✅ |
| [FIX-DEFAULTS-MODULES](archive/FIX-DEFAULTS-MODULES.md) — MiST mandatory, drop WEATHERMARK from default | ✅ |
| [FIX-DOCS-DEPLOY-CONCURRENCY](archive/FIX-DOCS-DEPLOY-CONCURRENCY.md) — two concurrent docs deployments knock each other out | ✅ |
| [FIX-DOCS-LATEST-ALIAS](archive/FIX-DOCS-LATEST-ALIAS.md) — released documentation was never published | ✅ |
| [FIX-DYNLOAD-PUBLISHED](archive/FIX-DYNLOAD-PUBLISHED.md) — make dynamic loading work in DEV and PROD | ✅ |
| [FIX-DYNSLOT-RADIO-UNITS](archive/FIX-DYNSLOT-RADIO-UNITS.md) — radio frequencies mis-scaled for kHz/ADF radios | ✅ |
| [FIX-DYNSLOT-TEMPLATE-CATEGORY](archive/FIX-DYNSLOT-TEMPLATE-CATEGORY.md) — airplane dynamic-slot templates miscategorized as helicopters | ✅ |
| [FIX-EMPTY-COALITION-COUNTRY](archive/FIX-EMPTY-COALITION-COUNTRY.md) — build crash on an empty coalition side | ✅ |
| [FIX-EVENTHANDLER-UNITCATEGORY](archive/FIX-EVENTHANDLER-UNITCATEGORY.md) — dynamic-slot airplane still treated as a helicopter by the QRA | ✅ |
| [FIX-EXTRACT-COMMUNITY-DICT](archive/FIX-EXTRACT-COMMUNITY-DICT.md) — `extract` crashes with KeyError on community script dicts | ✅ |
| [FIX-I18N-DEBT](archive/FIX-I18N-DEBT.md) — Clear remaining hardcoded-string debt | ✅ |
| [FIX-I18N-HARDCODED](archive/FIX-I18N-HARDCODED.md) — AST test + fix hardcoded strings in aircrafts_injector + lua_config_generator | ✅ |
| [FIX-LONG-FILENAMES-WINDOWS](archive/FIX-LONG-FILENAMES-WINDOWS.md) — long fixture filenames break the Windows marketplace clone | ✅ |
| [FIX-LUADATA-NIL](archive/FIX-LUADATA-NIL.md) — pure-Python luadata parser rejects `nil` values | ✅ |
| [FIX-MANDATORY-ENABLE](archive/FIX-MANDATORY-ENABLE.md) — block enable on mandatory modules | ✅ |
| [FIX-MANDATORY-YAML](archive/FIX-MANDATORY-YAML.md) — YAML generators: emit `{}` for mandatory modules instead of `enable: true` | ✅ |
| [FIX-MAPRESOURCE-KEY](archive/FIX-MAPRESOURCE-KEY.md) — embedded scripts never loaded (resource key in the wrong table) | ✅ |
| [FIX-MARKERS-INIT](archive/FIX-MARKERS-INIT.md) — add missing `veafMarkers.initialize()` | ✅ |
| [FIX-MCP-INTERPRETER-DOC](archive/FIX-MCP-INTERPRETER-DOC.md) — teach the skill the `#veafInterpreter` idiom | ✅ |
| [FIX-MCP-SCAFFOLD-THEATRE-HINT](archive/FIX-MCP-SCAFFOLD-THEATRE-HINT.md) — steer the LLM to pass `theatre` to scaffold_mission | ✅ |
| [FIX-MCP-STDOUT-POLLUTION](archive/FIX-MCP-STDOUT-POLLUTION.md) — the MCP server pollutes its stdio JSON-RPC stream | ✅ |
| [FIX-MCP-TEST-FEEDBACK](archive/FIX-MCP-TEST-FEEDBACK.md) — two real-usage fixes from the plugin test session | ✅ |
| [FIX-MIG15-PRIMARY-FREQ](archive/FIX-MIG15-PRIMARY-FREQ.md) — build wrongly rejects the MiG-15bis HF primary frequency | ✅ |
| [FIX-MISSILEGUARDIAN-INIT-CRASH](archive/FIX-MISSILEGUARDIAN-INIT-CRASH.md) — Reported by Tripack: with `MISSILEGUARDIAN: true` in `mission.yaml`, F10 marker | ✅ |
| [FIX-MISSING-INIT](archive/FIX-MISSING-INIT.md) — missing `initialize()` on 4 Lua modules | ✅ |
| [FIX-MISSIONCONFIG-BAK](archive/FIX-MISSIONCONFIG-BAK.md) — supprimer extension .bak inutile ✅ | ✅ |
| [FIX-MISSIONCONFIG-REFS](archive/FIX-MISSIONCONFIG-REFS.md) — references to `missionConfig.lua` in doc and code | ✅ |
| [FIX-MISSIONYAML-MISSION-SECTION](archive/FIX-MISSIONYAML-MISSION-SECTION.md) — `mission:` block mislabeled + migrated-field provenance | ✅ |
| [FIX-OLDSCRIPTS](archive/FIX-OLDSCRIPTS.md) — detect residual .lua files in src/scripts/ | ✅ |
| [FIX-PRESETS-RADIO-COMPAT](archive/FIX-PRESETS-RADIO-COMPAT.md) — skip presets incompatible with an aircraft's radio | ✅ |
| [FIX-PRIMARY-FREQ-HUMANRADIO](archive/FIX-PRIMARY-FREQ-HUMANRADIO.md) — a promoted preset frequency can fall outside the aircraft's tunable range | ✅ |
| [FIX-PYINSTALLER-RADIO-LAYOUT-DATA](archive/FIX-PYINSTALLER-RADIO-LAYOUT-DATA.md) — Running the packaged `veaf-tools.exe` (built via PyInstaller from `veaf-tools.spec`), | ✅ |
| [FIX-QRA-DYNSLOT-CATEGORY](archive/FIX-QRA-DYNSLOT-CATEGORY.md) — Fixes [#299](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/299) (reported by Tripack). | ✅ |
| [FIX-README-COPY](archive/FIX-README-COPY.md) — Stop copying presets.md into src/ ✅ | ✅ |
| [FIX-RELEASE-WORKFLOW-PRERELEASE](archive/FIX-RELEASE-WORKFLOW-PRERELEASE.md) — make pre-releases actually safe | ✅ |
| [FIX-REMOVE-CONVERT](archive/FIX-REMOVE-CONVERT.md) — remove the `convert` command | ✅ |
| [FIX-SECRET-SCANNING-GITLEAKS-CLI](archive/FIX-SECRET-SCANNING-GITLEAKS-CLI.md) — The `Secret Scanning` workflow (`.github/workflows/secret-scanning.yml`, added | ✅ |
| [FIX-SERVERHOOK-CHAT-SIM-LOGGER](archive/FIX-SERVERHOOK-CHAT-SIM-LOGGER.md) — logger `Sim` crash + dead server-hook chat callback | ✅ |
| [FIX-SERVERHOOK-UNKNOWN-PILOT-PARSE](archive/FIX-SERVERHOOK-UNKNOWN-PILOT-PARSE.md) — shared pilots list not loaded + crash on unlisted pilot | ✅ |
| [FIX-SORT](archive/FIX-SORT.md) — LUADATA FIX: Crash tri clés mixtes int/str ✅ | ✅ |
| [FIX-SPAWNABLES-CATEGORY](archive/FIX-SPAWNABLES-CATEGORY.md) — default spawnables mis-categorize planes as helicopters | ✅ |
| [FIX-SRS-WARN](archive/FIX-SRS-WARN.md) — false warning when SRS config file is absent | ✅ |
| [FIX-TEMPLATE-SLOTS-VISIBLE](archive/FIX-TEMPLATE-SLOTS-VISIBLE.md) — injected aircraft templates pollute the multiplayer slot list | ✅ |
| [FIX-TUI-MISSING-COMMANDS](archive/FIX-TUI-MISSING-COMMANDS.md) — every CLI command must appear in the interactive TUI | ✅ |
| [FIX-UPDATER-PAUSE-HANG](archive/FIX-UPDATER-PAUSE-HANG.md) — plugin bootstrap / scaffold hang on the updater's pause | ✅ |
| [FIX-V5-NUDGE-FALSE-POSITIVE](archive/FIX-V5-NUDGE-FALSE-POSITIVE.md) — After `convert-v5` promotes `src/mission/` to v6, the next `build` still emits the | ✅ |
| [FIX-VEAF-BUILD-RADIO-LAYOUT-DATA](archive/FIX-VEAF-BUILD-RADIO-LAYOUT-DATA.md) — FIX-PYINSTALLER-RADIO-LAYOUT-DATA (previous lot) added `dcs-radio-layouts.yaml` to the | ✅ |
| [FIX-VEAF-MODULE-GATING](archive/FIX-VEAF-MODULE-GATING.md) — VEAF integration must gate on enabled, not on global existence | ✅ |
| [FIX-VERSION-PY-EOL](archive/FIX-VERSION-PY-EOL.md) — generated `_version.py` always shows as modified | ✅ |
| [FIX-VERSIONS-YAML-ONLY](archive/FIX-VERSIONS-YAML-ONLY.md) — drop missions.yaml alias for weather pipeline | ✅ |
| [FIX-WAYPOINTS-ETA-LOCKED](archive/FIX-WAYPOINTS-ETA-LOCKED.md) — injected routes have no locked-ETA waypoint | ✅ |
| [FIX-WAYPOINTS-INJECT-PRESERVE-ROUTE](archive/FIX-WAYPOINTS-INJECT-PRESERVE-ROUTE.md) — waypoint injection wipes the takeoff | ✅ |
| [FIX-WEATHER-ALIAS](archive/FIX-WEATHER-ALIAS.md) — missions.yaml + versions.yaml coexistence ✅ | ✅ |
| [FIX-WORKFLOWS-MAIN-TO-MASTER](archive/FIX-WORKFLOWS-MAIN-TO-MASTER.md) — Every CI workflow triggers on the branch `main`, but the repository has **no `main` | ✅ |
| [FIX-YAML-SYNTAX](archive/FIX-YAML-SYNTAX.md) — unhandled YAML error in build and mission_builder_worker | ✅ |
| [FOOTHOLD-V6](archive/FOOTHOLD-V6.md) — adopt the third-party Foothold mission onto the v6 toolchain | ✅ |
| [I18N-COVERAGE](archive/I18N-COVERAGE.md) — i18n coverage tests + fix remaining hardcoded English strings | ✅ |
| [IMC-FEEDBACK-2](archive/IMC-FEEDBACK-2.md) — Second-round IMC-Day user feedback (6.4.0) | ✅ |
| [INVESTIGATE-REDFOR-ZONES](archive/INVESTIGATE-REDFOR-ZONES.md) — "red has no territory zones / no airfields" error | ✅ |
| [LOT-1-INFRA](archive/LOT-1-INFRA.md) — 1 — INFRA: Python quality gate + CI | ✅ |
| [LOT-10-YAML-CONFIG](archive/LOT-10-YAML-CONFIG.md) — 10 — YAML-CONFIG: mission.yaml source de vérité | ✅ |
| [LOT-11-I18N](archive/LOT-11-I18N.md) — 11 — I18N: Internationalisation (EN + FR) | ✅ |
| [LOT-12-QUALITY](archive/LOT-12-QUALITY.md) — 12 — QUALITY: Nettoyage, consolidation et qualité du code | ✅ |
| [LOT-13-DISCUSS](archive/LOT-13-DISCUSS.md) — 13 — DISCUSS: Standards industrie — à évaluer et décider | ✅ |
| [LOT-14-ARCH-COMMANDS](archive/LOT-14-ARCH-COMMANDS.md) — 14 — ARCH-COMMANDS: Refactoring de l'infrastructure commandes/marqueurs | ✅ |
| [LOT-15-DOC](archive/LOT-15-DOC.md) — 15 — DOC: Restructuration et mise à jour de la documentation | ✅ |
| [LOT-16-LUA-COVERAGE](archive/LOT-16-LUA-COVERAGE.md) — 16 — LUA-COVERAGE: Couverture de tests ≥ 50 % par module | ✅ |
| [LOT-17-USER-CONFIG](archive/LOT-17-USER-CONFIG.md) — 17 — USER-CONFIG: Configuration globale utilisateur + i18n complète | ✅ |
| [LOT-18-VERSIONING](archive/LOT-18-VERSIONING.md) — 18 — VERSIONING: Single source of truth pour la version ✅ | ✅ |
| [LOT-19-MIGRATOR](archive/LOT-19-MIGRATOR.md) — 19 — MIGRATOR: Audit et complétion de la conversion missionConfig.lua ✅ | ✅ |
| [LOT-2-CLI](archive/LOT-2-CLI.md) — 2 — CLI: veaf-tools improvements | ✅ |
| [LOT-20-DEEPENING](archive/LOT-20-DEEPENING.md) — 20 — DEEPENING: Architecture deepening Python + Lua ✅ | ✅ |
| [LOT-21-TYPING](archive/LOT-21-TYPING.md) — 21 — TYPING: Migrate `Optional[T]` to `X | Y` syntax ✅ | ✅ |
| [LOT-22-TEST-LAYOUT](archive/LOT-22-TEST-LAYOUT.md) — 22 — TEST-LAYOUT: Move Python tests to `test/python/` ✅ | ✅ |
| [LOT-23-DOC-YAML](archive/LOT-23-DOC-YAML.md) — 23 — DOC-YAML: Référence YAML complète ✅ | ✅ |
| [LOT-24-DOC-REVIEW-2](archive/LOT-24-DOC-REVIEW-2.md) — 24 — DOC-REVIEW: Klogg profile (REV-002) | ✅ |
| [LOT-24-DOC-REVIEW](archive/LOT-24-DOC-REVIEW.md) — 24 — DOC-REVIEW: Corrections issues du doc-review ✅ (REV-002 différé) | ✅ |
| [LOT-25-EXT-YAML](archive/LOT-25-EXT-YAML.md) — 25 — EXT-YAML: Support YAML pour les modules externes (CTLD/CSAR) ✅ | ✅ |
| [LOT-26-IMC-FEEDBACK](archive/LOT-26-IMC-FEEDBACK.md) — 26 — IMC-FEEDBACK: Retours utilisateur tests IMC-Day (v6.2.0) ✅ | ✅ |
| [LOT-27-DOC-FR-MERGE](archive/LOT-27-DOC-FR-MERGE.md) — 27 — DOC-FR-MERGE: French as default language + v5 content merge | ✅ |
| [LOT-3-TUI](archive/LOT-3-TUI.md) — 3 — TUI: InquirerPy interactive mode | ✅ |
| [LOT-4-LUA-CONFIG](archive/LOT-4-LUA-CONFIG.md) — 4 — LUA-CONFIG: Lua configuration system | ✅ |
| [LOT-6-BONUS](archive/LOT-6-BONUS.md) — 6 — BONUS: Logger filter + DCSUnits doc | ✅ |
| [LOT-7-LUA](archive/LOT-7-LUA.md) — 7 — LUA FIXES: High-priority bug fixes from issue triage | ✅ |
| [LOT-8-LUA-QUALITY](archive/LOT-8-LUA-QUALITY.md) — 8 — LUA-QUALITY: Code quality quick wins | ✅ |
| [LOT-9-LUA-REFACTOR](archive/LOT-9-LUA-REFACTOR.md) — 9 — LUA-REFACTOR: Refactoring structurel des modules majeurs | ✅ |
| [LUA-COVERAGE](archive/LUA-COVERAGE.md) — Lua test-coverage objective for runtime modules | ✅ |
| [LUA-I18N-CAS](archive/LUA-I18N-CAS.md) — localize `_cas` user-facing messages | ✅ |
| [LUA-I18N-SWEEP](archive/LUA-I18N-SWEEP.md) — localize all remaining VEAF on-screen messages | ✅ |
| [LUA-I18N-WEATHER](archive/LUA-I18N-WEATHER.md) — localize the `veafWeatherData` report | ✅ |
| [LUA-I18N](archive/LUA-I18N.md) — Localize in-game VEAF messages (Lua runtime; FR default + EN) | ✅ |
| [LUACHECK-CI](archive/LUACHECK-CI.md) — add luacheck to the CI Lua quality gate | ✅ |
| [PERF-LUADATA-PARSER](archive/PERF-LUADATA-PARSER.md) — speed up the pure-Python Lua parser on large missions | ✅ |
| [PHASE-0](archive/PHASE-0.md) — Phase 0 — Restart | ✅ |
| [PHASE-0B](archive/PHASE-0B.md) — Phase 0b — GitHub cleanup | ✅ |
| [PREREL-BUGS](archive/PREREL-BUGS.md) — Pre-release code review findings | ✅ |
| [QUALITY-GATE-FINISH](archive/QUALITY-GATE-FINISH.md) — erode the remaining mypy exclusions | ✅ |
| [QUALITY-GATE](archive/QUALITY-GATE.md) — Erode mypy exclusions and ratchet the coverage gate | ✅ |
| [RADIO-SPECS](archive/RADIO-SPECS.md) — DCS radio frequency validation in inject-presets | ✅ |
| [RC](archive/RC.md) — v6.1.0 RC bug fixes | ✅ |
| [REFACTOR-SERVER-HOOK-CANONICAL](archive/REFACTOR-SERVER-HOOK-CANONICAL.md) — hook serveur = source déployable unique | ✅ |
| [RELEASE](archive/RELEASE.md) — v6.10.0 | ✅ |
| [SCAFFOLD](archive/SCAFFOLD.md) — `veaf-tools new` (mission folder scaffolding) | ✅ |
| [SECREV](archive/SECREV.md) — Full-repo code review findings | ✅ |
| [SPAWN-REFACTOR](archive/SPAWN-REFACTOR.md) — Characterize then de-duplicate the spawn subsystem | ✅ |
| [TEST-PHASE-6-4-X](archive/TEST-PHASE-6-4-X.md) — TEST-PHASE-6.4.x — manual test-campaign fixes | ✅ |
| [TODO0609-AIRCRAFT-INJECT](archive/TODO0609-AIRCRAFT-INJECT.md) — Split aircraft-group injection (spawnable vs dynamic-slot template) | ✅ |
| [TODO0609-CONVERT-FIDELITY](archive/TODO0609-CONVERT-FIDELITY.md) — convert-v5 report & extraction fidelity | ✅ |
| [TODO0609-DEFAULTS-AUDIT](archive/TODO0609-DEFAULTS-AUDIT.md) — Audit the defaults mission-folder for dead files | ✅ |
| [TODO0609-DYNLOAD-CLARIFY](archive/TODO0609-DYNLOAD-CLARIFY.md) — Clarify dynamic script loading | ✅ |
| [TODO0609-ERA-AUTODETECT](archive/TODO0609-ERA-AUTODETECT.md) — Automatic mission era detection | ✅ |
| [TODO0609-MODULES-UNIFY](archive/TODO0609-MODULES-UNIFY.md) — Single `modules:` block as the source of truth | ✅ |
| [TODO0609-PRESETS-FIDELITY](archive/TODO0609-PRESETS-FIDELITY.md) — Iso-functional radio presets conversion | ✅ |
| [TODO0609-SPAWN-EXTERNALIZE](archive/TODO0609-SPAWN-EXTERNALIZE.md) — Externalize spawn group definitions to YAML | ✅ |
| [TODO0609-TRIGGERS-VERIFY](archive/TODO0609-TRIGGERS-VERIFY.md) — Verify trigger migration for custom scripts | ✅ |
| [TODO0609-TUI-FOLDER-HINT](archive/TODO0609-TUI-FOLDER-HINT.md) — Clarify the TUI mission-folder default | ✅ |
| [TOOLING-DCS-MOCK-COVERAGE](archive/TOOLING-DCS-MOCK-COVERAGE.md) — audit DCS-mock coverage against a vendored API schema | ✅ |
| [TUI-YAML-DEFAULTS](archive/TUI-YAML-DEFAULTS.md) — TUI defaults aware of an existing mission.yaml | ✅ |
| [TUM-AUTOINIT](archive/TUM-AUTOINIT.md) — auto-init TheUniversalMission when selected | ✅ |
| [TUM-INIT](archive/TUM-INIT.md) — initialize TheUniversalMission from config | ✅ |
| [UI-OUTPUT](archive/UI-OUTPUT.md) — Declutter CLI output (transient status line + chapter/technical tiers) | ✅ |
| [UPDATER-CROSSPLATFORM](archive/UPDATER-CROSSPLATFORM.md) — `veaf-tools-updater` is Windows-only. It extracts `published.zip` and moves | ✅ |
| [UPDATER-FIX](archive/UPDATER-FIX.md) — Séparation updater / prepare / workflow v5 | ✅ |
| [UX-AIRCRAFT-SKIPPED-REPORT](archive/UX-AIRCRAFT-SKIPPED-REPORT.md) — Two small `build` console-output issues, surfaced while diagnosing Tripack's mission: | ✅ |
| [UX-PIPELINE-OUTPUT-POLISH](archive/UX-PIPELINE-OUTPUT-POLISH.md) — The `build` "pipeline" output is hard to read: | ✅ |
| [UX-PLURAL-SWEEP](archive/UX-PLURAL-SWEEP.md) — Apply the `tn()` natural-plural mechanic (introduced in UX-PIPELINE-OUTPUT-POLISH) to the | ✅ |
| [UXPILOT-FEEDBACK](archive/UXPILOT-FEEDBACK.md) — Surface command errors to pilots | ✅ |
| [VALIDATE](archive/VALIDATE.md) — `veaf-tools validate` (pre-build linter) | ✅ |
| [VENDORED-DRIFT-WATCH](archive/VENDORED-DRIFT-WATCH.md) — scheduled drift-watch for all vendored artifacts | ✅ |
| [WEATHERMARK-REMOVE](archive/WEATHERMARK-REMOVE.md) — retire the WeatherMark community script | ✅ |
| [YAML-UX](archive/YAML-UX.md) — Simplification syntaxe mission.yaml | ✅ |
