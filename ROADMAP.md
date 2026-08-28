# Roadmap — VEAF Mission Creation Tools v6

Execution order for the open lots in [.backlog/README.md](.backlog/README.md). Source of truth for
**sequencing**; `.backlog/` stays the source of truth for **scope and status**.

> Refreshed 2026-08-19 after the GitHub issue triage and the three in-game verification sessions,
> which between them replaced a twelve-lot open list with a thirty-lot one — almost all of it now
> carrying a **measured cause** rather than a report.
> Previously refreshed 2026-08-13 (documentation audit) and 2026-08-06 (SECREV-2). The original
> 2026-06-10 sequencing (CI-NODE24 → SECREV → MODULES-UNIFY → conversion cluster → spawn axis →
> RELEASE) is **fully delivered** and has been retired from this file; see `.backlog/archive/` for
> the closed lots.

---

## 1. Where we are

The v6 development cycle that this file originally sequenced is **complete**: infra (CI,
quality gates), the unified `modules:` schema, the conversion cluster
(`convert-v5`/`convert-other`, fidelity, presets), the spawn/aircraft-injection axis, the
mission-maker tooling (`validate`, `prepare --template`, CLI↔TUI bridge, build-time
reference validation), Foothold-on-v6, and the safe Lua-free `export` all shipped. **A
complete, stable v6 was then cut to `master` as v6.10.0** (see §3).

What shipped **since** that cut is different in nature — no longer closing the v6 scope, but
extending it:

- **AI design-time tooling** — `FEAT-MCP-MISSION-EDITOR` waves 1-4 (PR #575): an MCP server
  giving an assistant editor-parity writes on a `.miz`, VMCT `mission.yaml` actions, a
  domain-knowledge oracle, and one-pass composites for combat zones / QRA / CAP
  ([ADR 0014](docs/adr/0014-mission-editor-mcp-editor-parity-layer.md)). This is the first
  concrete piece of the **NL-MISSION-GEN** vision below.
- **Third-party integrations** — CTLD 2 as a normal VEAF module with its own config sidecar
  (6.13.0, [ADR 0016](docs/adr/0016-ctld2-sidecar-configuration.md)); Foothold v5 parity,
  release-archive intake and a WWII profile.
- **In-flight assistance** — `FEAT-ASSIST-CHECKLISTS`: guided checklists from YAML, flown and
  validated 2026-08-01. New ground, and the one thing the dcs-sms study (§4) produced.
- **Documentation as a gated artifact** — a full audit (`DOC-AUDIT-PASS`) then a CI gate
  (`DOC-QUALITY-GATE`, 6.12.0) refusing broken links, dead anchors, untranslated pages and nav
  orphans, plus version stamping at deploy.
- **Combat zones playable from either side** — red-side zones and coalition-scoped F10 menus.
- **A built mission is playable end to end again** (6.14.2) — nine defects found by pulling on one
  report (*"no CTLD menu on a 6.14 mission"*): CTLD was started in no generated mission at all, the
  airfield table a `.miz` needs was empty so no parked slot could be taken, every helicopter the MCP
  created was filed as a plane, CTLD ignored the mission's language, and the debug hook wiped out
  the framework mid-mission. None of them raised an error — `validate` was clean and the build was
  silent throughout, which is why a whole release shipped with CTLD switched off.

- **The open issues were read against v6, then answered in game** (2026-08-17/18) — `CHORE-GITHUB-ISSUE-TRIAGE`
  re-read the **63 open GitHub issues** and closed 17 of them, most as v5-era or already fixed;
  `CHORE-ISSUE-VERIFY-SESSION` then took the twelve that needed the game and returned **twelve
  verdicts** in three sessions. Nine were confirmed with the cause located, one was not reproduced
  and closed, one turned up unplanned while testing another (#128), and one (#245) moved to the
  smoke harness where it never needed a pilot. That is where most of the open list below comes from,
  and why it is unusually well-instructed: a lot opened from a measurement is a lot that can be
  written without re-investigating.
- **A v5 mission converted to v6 no longer loses settings silently** (6.15.0) — Sharko's #722/#723/#725:
  a multi-line `setBriefing` truncated the setter chain (302 briefings of 1864), six `combat_zones`
  setters had no schema key at all, and 14 of 28 scalar keys vanished. `convert-v5` now carries them
  and, where it cannot, **says so**.
- **A convoy placed in a combat zone finally drives its route** (6.15.5) — [#290](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/290),
  open since April 2025 and the oldest confirmed defect on the list. `activate()` put every group it
  spawned on RED alert, and a DCS ground group on red alert holds position: right for a SAM battery,
  wrong for a convoy. Zones now spawn on AUTO, and `#alarm=N` overrides it per group. Verified in game
  on 2026-08-19. Two neighbouring defects were **split out rather than folded in**, at David's request:
  `FIX-COMBATZONE-SPAWN-ROUTE-OFFSET` and `FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY`.

A release is cut on a `release/x.y.z` branch off `develop`, merged into `master` with a **merge
commit**, and tagged twice from there — `published-vx.y.z` for the binaries, `vx.y.z` for the
versioned documentation. The last published release is **6.16.0** (2026-08-24), which consolidates the
forty-seven patch versions from 6.15.5 to 6.15.52 — a minor bump rather than a patch, because it carries
new features as well as fixes: the artillery fire-adjustment loop, the welcome brief, the coordinate
formats DCS actually displays, CTLD radio beacons, and convoy itineraries.

Its predecessor, **6.15.4** (2026-08-19), carried four patches: 6.15.1 to 6.15.4 were closed in the
changelog but never published, so 6.15.0 stood as the shipped version while its executable could not
start.

---

## 2. Open backlog — the order, and what is in the way

[.backlog/README.md](.backlog/README.md) is the full open list and the source of truth for scope
and status. This section is the **order**, plus what stands in the way of everything not in it.

### The 2026-08-13 order is delivered

All four lots David sequenced on 2026-08-13 are **closed and archived**: `FIX-DOCAUDIT-CODE`,
`DOC-AUDIT-FIXES`, `DOC-MODULE-PAGES` and `FIX-RADIO-SPECS-GENERATOR-LOCALE`. So is the 2026-08-11
order before it. Nothing from either remains open — the whole of this section is new ground.

### Where the open list comes from

**28 lots are open and ready**, plus 4 waiting on a person or another lot, 2 in progress and 2
deliberately parked (and 7 closed in the last three days, which archive as they pass the 3-day
rule — five did on 2026-08-20). Roughly
two thirds were opened in the last three days, by two chores rather than by a plan: the re-read of
the 63 GitHub issues, and the three verification sessions that answered the twelve issues needing the
game. Their PRDs therefore start from a **measurement**, not a report — the cause is located, the
wrong tracks are recorded so nobody re-walks them, and several carry David's arbitration already.

Two families run through them, and they decide the order:

1. **The tooling destroys work it did not mean to touch.** Three defects of this exact shape surfaced
   on 2026-08-17 alone — the warehouses table (shipped in 6.15.0), a group container, and the build
   truncating `mission.yaml` at its own marker. All silent, all found by accident, two of the three
   catchable by one read/write/compare round trip.
2. **A runtime behaviour is right for one caller and wrong for another**, applied globally: one alarm
   state for a SAM and a convoy, one `DynamicSpawn` boolean for every IADS network, one carrier menu
   for both coalitions, one escort task that survives a teleport but not a respawn.

### The order, decided 2026-08-19

Validated by David the day it was proposed. **Orders 1 to 3 are delivered** — 1 and 2 on 2026-08-19, 3 written the same evening and merged on 2026-08-20 (PR #762, version 6.15.5, **not published yet**). The next lot starts at order 4. **Nothing in orders 1 to 5 needs DCS started** — that is deliberate, since the game is not available on the workstation this order was decided on. Everything gated on a running DCS is in the table below and in [DCS-SESSION-TODO.md](DCS-SESSION-TODO.md).

| Order | Lot | Weight | Why here |
|-------|-----|--------|----------|
| ✅ **1** | [`FIX-MCP-AUTHORING-GAPS`](.backlog/FIX-MCP-AUTHORING-GAPS/PRD.md) | 1 lot | **It is what the next verification mission stands on.** Three holes made an agent hand-edit the mission file, and *every* serious defect of the `verify-mission-c` build came from those hand edits. Fixing it first makes each following lot cheaper to verify; leaving it means paying that tax on every one of them. |
| ✅ **2** | [`FIX-BUILD-YAML-TRUNCATION`](.backlog/FIX-BUILD-YAML-TRUNCATION/PRD.md) + [`FIX-GROUP-CONTAINER-SHAPE`](.backlog/FIX-GROUP-CONTAINER-SHAPE/PRD.md) | 2 lots | Family 1, and they belong together: both PRDs independently ask for the **same** missing guard — a writer that checks it preserved what it did not mean to change. One shared test helper is worth more than either fix alone. The truncation fires on the documented `--dev-mode` workflow and ate a `security:` block three times before the cause was found. |
| ✅ **3** | [`FIX-COMBATZONE-CONVOY-ALARM`](.backlog/FIX-COMBATZONE-CONVOY-ALARM/PRD.md) | 1 lot | #290, **open since April 2025**, cause proven in game 2026-08-17: the zone puts everything it spawns on red alert, and a ground group on red alert holds position. The oldest confirmed defect on the list and the most player-visible. Its open question — who chooses the alarm state, since a convoy and a SAM want opposite ones — is a design call, so it wants a decision before code. |
| ✅ **4** | The verification harvest, in issue order | 6 lots | **Delivered 2026-08-20** — PRs #767, #768, #769, #770, #771, plus #766 for the escort. Five of the six carry an in-game confirmation still owed, collected in [DCS-SESSION-TODO.md](DCS-SESSION-TODO.md); `FIX-MOVE-ORBIT-SEARCH` closed outright, being route-data logic the mocks cover. Each lot found **more than its issue described**: a fourth Skynet defect (the birth handler ignored the per-spawn `skynet` option), three deferring paths instead of one for #66, a `FARP_T` measured as a non-FARP for a year, and a `Circle`-orbit trap #248 never mentioned.  The six, in issue order: [`FIX-SKYNET-DYNAMICSPAWN-SCOPE`](.backlog/FIX-SKYNET-DYNAMICSPAWN-SCOPE/PRD.md) (#151+#261), [`FIX-COMBATZONE-DELAYED-COMMAND`](.backlog/FIX-COMBATZONE-DELAYED-COMMAND/PRD.md) (#66), [`FIX-CARRIER-MENU-COALITION`](.backlog/FIX-CARRIER-MENU-COALITION/PRD.md) (#87), [`FIX-ESCORT-RESPAWN-TASK`](.backlog/FIX-ESCORT-RESPAWN-TASK/PRD.md) (#107 — and it **unblocks** `FEAT-AWACS-ESCORT-COMMANDS`), [`FIX-FARP-ESCORT-PLACEMENT`](.backlog/FIX-FARP-ESCORT-PLACEMENT/PRD.md) (#232), [`FIX-MOVE-ORBIT-SEARCH`](.backlog/FIX-MOVE-ORBIT-SEARCH/PRD.md) (#248). Each closes a GitHub issue whose cause is already located: writing work, not investigation. |
| 🚫 **5** | [`FEAT-ROLE-AWARE-RADIO-MENU`](.backlog/FEAT-ROLE-AWARE-RADIO-MENU/PRD.md) | — | **Cancelled 2026-08-20**, by David, on the measurements of its own first ticket: *"DCS ne nous permet pas de faire ce qu'on veut"*. Two walls, both DCS's: the F10 channel never says who clicked, so a secured command cannot identify a game master — and every command worth giving him is secured; and leaving them unsecured would hand the mission to whoever takes an unprotected game-master slot. The measurements are kept in [`docs/exploration/DCS-UNATTACHED-PLAYER-ROLES.md`](docs/exploration/DCS-UNATTACHED-PLAYER-ROLES.md) so the question is not reopened without them. **Order 6 is now next.** |
| **6** | The rest of the ⬜ list | ~18 lots | No ordering constraint between them yet: the combat-zone options (`RENAME-OPTION`, `ZONE-TYPE-SILENT`), the spawn and radio features (`SMOKE-CSAR-WATER`, `SLOT-WELCOME-BRIEF`, `WAYPOINT-BULLSEYE`, `RADIO-BEACONS`, `BRIEFING-METAR`, `ARTILLERY-CONTROL`, `CONVOY-WAYPOINTS`, `AIRWAVES-QRA-MERGE`, `QRA-AIRBASE-LINK`, `CTLD-SLINGLOAD-TOGGLE`, `GROUP-COMBAT-INEFFECTIVE`, `INTERPRETER-PARITY`, `SPAWN-OPTION-VALIDATION`, `PLATOON-UNITS`) and [`FEAT-PORTABLE-PREFABS`](.backlog/FEAT-PORTABLE-PREFABS/PRD.md), still a design lot where **a rejection is an acceptable outcome**. Three lots joined it after the order was decided: [`FIX-COMBATZONE-SPAWN-ROUTE-OFFSET`](.backlog/FIX-COMBATZONE-SPAWN-ROUTE-OFFSET/PRD.md) and [`FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY`](.backlog/FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY/PRD.md), both split out of order 3 rather than folded into it, and [`FIX-WRITE-MIZ-REPLACE-FLAKE`](.backlog/FIX-WRITE-MIZ-REPLACE-FLAKE/PRD.md), which wants an arbitration before code. |

### New since that order — DROP-MIST and FIX-PLACEMENT-IGNORES-SCENERY (2026-08-27)

[`FIX-PLACEMENT-IGNORES-SCENERY`](.backlog/FIX-PLACEMENT-IGNORES-SCENERY/PRD.md) came out of `DROP-MIST`'s
own measurement rather than a report, and it goes **before** the campaign: it fixes two ground-placement
paths `FEAT-SCENERY-AWARE-SPAWN` missed — a *"Full Combat Group"* of real ground units, and every combat
zone element with a non-zero spawn radius — plus a FARP escort that searches for clear ground without
ever looking at the scenery. Five tickets, none needing DCS to write, one (04) reversing a tuned decision
on David's call and therefore owing the same in-game non-regression 6.15.33 proved.

It is listed first because it is small, player-visible and independent, where the campaign below is
neither of the first two.


[`DROP-MIST`](.backlog/DROP-MIST/PRD.md) does not slot into the table above, because it is a **campaign
of nine tickets** rather than a lot. It came off the vision list in §4 the day its own entry gate was
executed: *count the call sites, that number decides lot or campaign*. The count — **455 call sites, 64
distinct MiST symbols, 32 of the ~50 VEAF Lua files** — answered campaign.

It sequences itself: ticket 00 is a spike that gates the two risky tickets (the mission index and the
spawn/route core), and ticket 08 is the only one with a player-visible effect, by construction. **The
spike closed on 2026-08-28** and both gates lifted: no VEAF caller reads a mission record for a unit an
AI or a third-party script spawned, so the index sheds its birth-event path and keeps three bricks — an
editor snapshot, a registry of the names we take and release, and a player roster that must cover DCS
dynamic slots. It also re-counted its own slice at 26 sites against the 51 first attributed to it, so
the 455 below is a sizing figure rather than a migration checklist. It runs
alongside the list above rather than ahead of it, and it carries an explicit caveat David accepted when
he opened it: **no intermediate ticket delivers a visible gain**, since MiST stays injected until the
last call site is gone.

> ⚠️ **The counts in this section predate 6.16.0 and 6.17.0.** "28 lots are open and ready" and order 6's
> "~18 lots" were true on 2026-08-19; as of 2026-08-27 the ⬜ list holds **five** lots — `ENRICH-DEFAULT-PRESETS`,
> `FEAT-AIRWAVES-QRA-MERGE`, `FEAT-PORTABLE-PREFABS` and the two opened that day — most of order 6 having
> shipped. The order itself is delivered through 5. Refreshing §2 is a pending chore — a stale sequencing
> file is read as work remaining, which this file says about itself two sections up.

### Blocked on a person, or on a DCS session

Not on a decision anyone can take at a keyboard here. The ones needing the game started are collected, in
running order and with the commands to paste, in [DCS-SESSION-TODO.md](DCS-SESSION-TODO.md).

| Lot | Status | Gate |
|-----|--------|------|
| [`FIX-WAREHOUSES-LIST-FORM`](.backlog/FIX-WAREHOUSES-LIST-FORM/PRD.md) | 🧑 | Fixed, tested and **shipped in 6.15.0**. Waiting on Tripack rebuilding his mission on it and confirming the airfields come back. |
| [`FIX-WAREHOUSES-INCREMENTAL`](.backlog/FIX-WAREHOUSES-INCREMENTAL/PRD.md) | 🧑 | Implemented 2026-08-16; one in-game confirmation that a mission with a single assigned airfield still ships all the others. |
| [`FIX-CONVERT-V5-SILENT-LOSSES`](.backlog/FIX-CONVERT-V5-SILENT-LOSSES/PRD.md) | 🧑 | All five tickets shipped 2026-08-17 and released. Waiting on Sharko's two harnesses, which are the acceptance test we agreed to. |
| [`FEAT-AWACS-ESCORT-COMMANDS`](.backlog/FEAT-AWACS-ESCORT-COMMANDS/PRD.md) | 🧑 | Blocked **on a lot rather than a person since 2026-08-18**: `FIX-ESCORT-RESPAWN-TASK` located the escort bug, so shipping `-escortme` on top of it would hand a pilot a decorative escort. Unblocks itself at order 4 above; the AWACS half never depended on it and can ship first. |
| [`CHORE-SMS-QUICK-WINS`](.backlog/CHORE-SMS-QUICK-WINS/PRD.md) | 🔄 | Ticket 02 is **delivered but unproven**: Gemini CLI is not installed here, so "tested rather than assumed" is unmet. One command validates it. |
| [`FEAT-ASSIST-FOLLOWUP`](.backlog/FEAT-ASSIST-FOLLOWUP/PRD.md) | 🔄 | Ticket 01 shipped 2026-08-11 and still wants one flight — no unit test can see DCS's resource cache. 02 needs a second pilot, 03 needs cockpit time, 04 deferred on purpose. |
| [`ENRICH-DEFAULT-PRESETS`](.backlog/ENRICH-DEFAULT-PRESETS/PRD.md) | ⬜ | A 🧑 **collaboration session with Tripack** to broaden the default `presets.yaml`. |
| [`FEAT-ASSIST-AUTHORING`](.backlog/FEAT-ASSIST-AUTHORING/PRD.md) | ⏸ | Parked by David 2026-08-03 — checklists nobody reviews are not worth generating. Ticket 06 waits on a pilot's verdict on the F-14B(U) procedure. |
| [`REFACTOR-SPAWN-AIR-TEMPLATES`](.backlog/REFACTOR-SPAWN-AIR-TEMPLATES/PRD.md) | ⏸ | Parked on purpose: no player-visible symptom. Do it when someone is already in that code. |

**`FEAT-DCS-SMOKE-HARNESS` closed 2026-08-15**, and it paid twice over. Run on the DCS workstation on
2026-08-06 it answered two pending in-game questions by machine rather than by a person — closing
`FEAT-COMBATZONE-MENU-COALITION` (open since July) and turning `Disposition` from assumed into
existing. Its last slice, an unattended single-player load, was **dropped rather than built**: DCS
does not document it. `FEAT-SMOKE-CSAR-WATER` is the first lot written *for* the harness instead of
for a pilot — #245 asks whether CSAR spawns on water, which is a `land.getSurfaceType` call, not a
flight.

`RELEASE` stays as a recurring chore template, not a one-shot lot. **6.15.4 was published
2026-08-19**, carrying 6.15.1 to 6.15.4 — the four patches had been closed in the changelog without
ever being tagged, which is how a broken executable stayed the shipped version for two days.
Publishing every closed patch is now part of the template, not a judgement call.

### Security work closed 2026-08-11

`SECREV-2` acted on the 2026-07-01 review — 140 findings that sat untracked at the repository root for
a month — and **closed with every one decided**: 95 fixed, 9 already fixed, 21 deferred with their
reasons, 8 confirmed-open and delegated to `REVIEW-SECURITY-LAYER`, 5 not reproducing, 2 wontfix. The
review now lives beside its own triage and archive at
[`.backlog/archive/SECREV-2-review.md`](.backlog/archive/SECREV-2-review.md), kept rather than deleted
because those 21 deferred findings still need the reviewer's reasoning when a lot next edits their file.

**Both criticals are closed in production.** David deployed the server hook on 2026-08-11, which was
the outstanding action this section used to name — until then the fix existed only in the repository
and the criticals were live on the VEAF servers.

`REVIEW-SECURITY-LAYER` closed the same day, and it carries a change to announce: **`/login` no longer
unlocks the mission for everybody.** A pilot listed in `veaf-pilots.txt` notices nothing; a pilot who is
not listed must give the password on every command. See the top of the changelog.

**Delivered in the 2026-08-06 → 08-13 window** (what came after is in §1):

- `FEAT-CTLD2-INTEGRATION` — the bundled CTLD becomes [VEAF/CTLD](https://github.com/VEAF/CTLD) 2 and
  moves its configuration to a `ctld-config.yaml` sidecar
  ([ADR 0016](docs/adr/0016-ctld2-sidecar-configuration.md), PR #646). The four gaps it found in
  CTLD 2 shipped there first (CTLD PRs #79, #80, #86).
- `FEAT-ASSIST-CHECKLISTS` — guided checklists from YAML, reached from an `Assistance` radio submenu,
  with F-16C engine start as first client; **flown and validated 2026-08-01** (PRs #649, #651).
  Came out of the dcs-sms study (§4), and needs no editor bridge: the cockpit-highlight actions are
  native functions callable from the mission scripting environment. `FEAT-ASSIST-AUTHORING` follows,
  ⏸ paused.
- [ADR 0017](docs/adr/0017-no-live-mission-editor-bridge.md) — a **live Mission Editor bridge is
  rejected**, on measurements rather than taste. Closes the question so it is not reopened by the next
  tool that advertises it.
- `REFACTOR-MARKER-PARSER` and the crash-fix lot before it — one declarative marker-text parser
  (`veaf.parseMarkerText`) replaces ten hand-written loops, and **13 crashes of one family** were fixed
  on the way. The lot's premise ("a fix reaches the copy it was written against") proved itself four
  times *during* the work, three of those in code already believed fixed. The sweep that found the last
  three enumerates its cases from the rule tables instead of picking them by hand.
- `FEAT-ASSIST-FOLLOWUP` ticket 01 and `FIX-SECREV2-EXPIRED-DEFERRALS` ticket 01 (2026-08-11) — a
  checklist picture is named after a digest of its own bytes, so DCS cannot serve a stale bitmap under a
  name it already cached; and a unit's life is read once instead of twice, so a hit landing between the
  two reads can no longer be scored as a kill.

**Two lots left the open list by being archived**, not by being reopened elsewhere:
`CHORE-TOOLING-GATES` and `FIX-RADIO-LAYOUT-GAPS`. This section listed them as open until
2026-08-11 — worth naming, because a stale sequencing file is read as work remaining.

---

## 3. Macro step DONE — v6.10.0 cut to `master`

✅ **2026-07-18** — the first **complete, stable v6 release** was cut to `master`
(**v6.10.0**), replacing the v5 line it carried (v5.103.3). `master` now tracks v6:
`develop` was merged in (v5 history superseded via `merge -s ours` then ff, tree pure
v6), tagged `published-v6.10.0` (binaries + GitHub Release + `published-latest`) and
`v6.10.0` (docs `latest`). **The vision work below is now unblocked.**

---

## 4. Forward-looking vision (NOT backlog yet)

> These are **prospective** initiatives — captured so they are not lost, but **not yet
> scoped backlog**. None has a branch, tickets, or a committed plan. Each becomes a real
> `.backlog/` lot only the day we decide to start it.
>
> **Two exceptions as of 2026-08-05**, both now partly or wholly scoped: `TUM-EXPLOIT`'s 🟢 tier
> shipped as `FEAT-SCENERY-AWARE-SPAWN`, and `DCS-SMS-EXPLOIT` was broken into five real lots. Their
> rows say which. The rest of this table is still vision.
>
> **Ordering constraint (David, 2026-06-27):** vision lots are tackled **only after a
> complete v6 release has been cut to `master`** (see §3). Order below is thematic, not a
> commitment.

| Theme | Initiative | One-line intent | Notes / dependencies |
|-------|------------|-----------------|----------------------|
| **Missions** | **PORT-MISSIONS-V6** | Port all VEAF missions (the *open trainings*) to v6. | 🔄 **In progress on David's side** (manual port). Also a large-scale real-world validation of the v6 tooling. |
| **dcs-sms** | **DCS-SMS-EXPLOIT** | Borrow ideas from [nielsvaes/dcs-sms](https://github.com/nielsvaes/dcs-sms) (DCS scripting framework + Mission Editor mod + host CLI). Four tiers: **(🟢 quick wins)** write the DCS coordinate convention down, ship the authoring skill to Gemini, add a `dev_condition`-style test hatch to assistance steps; **(🟡 MCP mutation wave)** their 126 `me <noun> <verb>` verbs read as a coverage grid — see NL-MISSION-GEN below; **(🟡 real-DCS smoke harness)** assert through the bridge inside a running DCS, plus their documented test-mission contract; **(🔵 later)** autogenerated reference with a CI freshness gate, and portable prefabs with a shared manifest-driven library. | 🔍 **Explored, and now scoped into real lots** (2026-08-05) — see [`docs/exploration/DCS-SMS-EXPLOIT.md`](docs/exploration/DCS-SMS-EXPLOIT.md). ⚠️ **`tools/` is GPL v3** (the CLI, the ME mod, the hook): read and rewrite, never copy. Two items were already closed — the live-ME bridge is **rejected** ([ADR 0017](docs/adr/0017-no-live-mission-editor-bridge.md)) and their cockpit-highlight machinery **shipped** as `FEAT-ASSIST-CHECKLISTS`. The rest is now filed, in rough order of value: [`FEAT-MCP-MUTATION-ACTIONS`](.backlog/archive/FEAT-MCP-MUTATION-ACTIONS.md) (§1 — the MCP edits nothing it did not create; triage by intent first, **not** a port of their 126 verbs), [`FEAT-DCS-SMOKE-HARNESS`](.backlog/archive/FEAT-DCS-SMOKE-HARNESS.md) (§2 — four in-game checks are currently queued behind a human; never a CI gate, since runners have no DCS), [`TOOLING-DOC-AUTOGEN`](.backlog/archive/TOOLING-DOC-AUTOGEN.md) (§3 — only `ALIASES` and the MCP catalogue are derivable; the 118 KB `LUA_API_REFERENCE` is prose and stays hand-written), [`FEAT-PORTABLE-PREFABS`](.backlog/FEAT-PORTABLE-PREFABS/PRD.md) (§4 — a **design** lot: their implementation is GPL *and* editor-bound, so the selection front-end must be invented or the idea dropped) and [`CHORE-SMS-QUICK-WINS`](.backlog/CHORE-SMS-QUICK-WINS/PRD.md) (§5 — all three still absent). |
| **TUM** | **TUM-EXPLOIT** | Borrow techniques from TUM's code. Two distinct axes: **(🟢 native)** the undocumented **`Disposition`** DCS singleton for scenery-aware ground spawning — directly usable, no prereq; **(🔴 server)** `net.dostring_in` + `a_*` internals (live HP/briefing, JSON persistence) — powerful but server-only. | 🔍 **Explored** — see [`docs/exploration/TUM-EXPLOIT.md`](docs/exploration/TUM-EXPLOIT.md). **🟢 tier SHIPPED** as [`FEAT-SCENERY-AWARE-SPAWN`](.backlog/archive/FEAT-SCENERY-AWARE-SPAWN.md) (2026-08-05, [ADR 0018](docs/adr/0018-undocumented-dcs-api-dependency.md)): `veaf.findSpawnPoint` searches in three bounded tiers — `Disposition` first, validated random draws second, explicit failure third — wired into the four dynamic ground spawners plus the generic `doSpawnGroup`, the convoy excluded since its departure point is its route origin; typed zone-property accessors came with it. The in-game probe was **deferred**, so the avoidance is asserted rather than measured. 🔴 tier feeds PERSISTENCE/DYNAMIC-CAMPAIGN and needs an `autoexec.cfg` unsanitize + SECREV fencing. |
| **Runtime** | **SPAWN-FIRES** | Spawn fires, not just smoke. `veafSpawn.spawnSmoke` exists (`veafSpawnEffects.lua:282`); nothing spawns a fire — grepped, no `spawnFire`, no `effectPresets`, no `bigSmokeAndFire` anywhere in the runtime. | 🔍 **From closing [#67 sibling #39](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/39)** (2026-08-17), a 2021 exploration whose smoke half was answered and whose fire half was never attempted. **David's lead: reuse the explosions of `_bomb`** — `veafSpawn.spawnBomb` already schedules `trigger.action.explosion` (`veafSpawnEffects.lua:248-276`), so the plumbing for repeated timed effects at a marker exists. To instruct before building: whether DCS's own big-smoke presets already include fire (which would make this a parameter rather than a feature), and whether an explosion leaves anything persistent or only a flash — an explosion is an event, a fire is a state, and the issue asked for the second. |
| **Multiplayer** | **MP-PVP-REWORK** | Make the scripts usable in an MP/PVP mission, as a basis for a wargame: a global setting to stop coalition inversion on spawn, per-coalition restrictions on what can be spawned (with warehousing in mind), and **infantry/MANPAD deployment** around vehicles that stop — the Low Level Hell behaviour, on `disperseOnAttack` or at a designated point. | 🔍 **From closing [#129](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/129) and [#132](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/132)** (RexAttaque, 2022) on 2026-08-17. Both carried `help wanted` for **four years** with no taker, including their author — not for lack of value, but because #129 is a design chantier rather than a ticket: it touches spawning, coalitions and warehousing at once. Kept here so the ideas survive the closure, since a four-year-old open issue is not closer to being done than a roadmap line. |
| **Dependencies** | **DROP-MIST** | Remove the hard dependency on MiST entirely — VEAF scripts no longer require or inject MiST. | ✅ **Scoped into a real lot on 2026-08-27** — [`DROP-MIST`](.backlog/DROP-MIST/PRD.md). This row's own gate ("count the call sites, that number decides lot or campaign") was executed and answered **campaign**: 455 call sites, 64 distinct MiST symbols, 32 of the ~50 VEAF Lua files; only 17 % of `mist.lua` is ever reached, and of the 31 tables under `mist.DBs` we read 8. David's doctrine, same day, in three rules: prefer the native DCS call, rewrite what is complex and useful, prune what is complex and only partly used. The scheduler intuition checked out — `timer.scheduleFunction` is native — but not as a 1:1 swap: MiST's own comment calls its scheduler *"superior to timer.scheduleFunction"*, and the native call knows nothing of `rep`, `st` or the `pcall`, so it needs ~40 lines of adapter. `mist.teleportToPoint` remains **measured correct** by the #290 investigation, so the port reproduces behaviour rather than fixing it. Still a foundation for PERSISTENCE / DYNAMIC-CAMPAIGN below, and still carries the honest caveat that **no intermediate ticket delivers a player-visible gain** — MiST stays injected until the last call site is gone. |
| **Runtime** | **PERSISTENCE** | New module to persist mission state across runs: DCS units (position/route/mission) **and** VEAF state machines (casMission, combatZone, QRA, …). | Foundation for dynamic campaigns. |
| **Campaign** | **DYNAMIC-CAMPAIGN** | Foothold-*style* dynamic, persistent campaign generation built entirely on VEAF tools — no Moose, no MiST. | Builds on PERSISTENCE + DROP-MIST. |
| **Integration** | **DCS-BRIDGE-FINISH** | Finish integrating `veaf-dcs-bridge` (TCP socket DCS ↔ external server). | Base injection already shipped (`FEAT-DCS-BRIDGE`, archived); remaining scope TBD. |
| **AI** | **AI-GAMEMASTER** | An LLM (e.g. Claude) runs a dynamic campaign live, with `veaf-dcs-bridge` exposed as an **MCP server** giving the AI the keys to DCS while the player flies against its improvisation. | Depends on DCS-BRIDGE-FINISH; overlaps DYNAMIC-CAMPAIGN. |
| **AI** | **NL-MISSION-GEN** | Natural-language mission generator (**design-time**): describe a mission in FR/EN → produce the `mission.yaml` + spawns/zones. | **Decided (David):** built for mission makers to run with **their own AI tooling**, *not* on the doc-chatbot stack. First cut as a **Claude plugin**. Lower risk, shippable earlier than AI-GAMEMASTER. **🔄 Started** (2026-07-12, ahead of the master-release gate — David: normal gitflow on `develop`, no need to wait): see [`FEAT-MCP-MISSION-EDITOR`](.backlog/archive/FEAT-MCP-MISSION-EDITOR.md) (waves 1-4 shipped: editor-parity + embedded-Lua + VMCT `mission.yaml` actions; waves 5-8 planned: domain-knowledge oracle → convention-aware group creation → composite one-pass builders for combat zones / QRA / CAP) and [ADR 0014](docs/adr/0014-mission-editor-mcp-editor-parity-layer.md). **Next wave identified (2026-08-04, from DCS-SMS-EXPLOIT):** the catalogue's 31 actions are strong on VEAF domain and on *creation*, and near-silent on **mutating what already exists** — no unit setter (loadout, skill, livery, position, callsign, parking…), no group setter (rename, move, hide, frequency, country, late activation…), no route/waypoint or waypoint-task editing, no arbitrary triggers, no F10 drawings. Not a port of their 126 verbs: triage by mission-maker intent. |
| **AI** | **AI-CONVERT-REVIEW** | AI review of `convert-v5` output: compare v5 intent vs v6 result and flag what was lost. | ⚠️ **David's doubt**: requires the mission maker to have AI access — not universal. Optional design-time aid. |
| **AI** | **BRIDGE-DASHBOARD** | Real-time web dashboard via `veaf-dcs-bridge`: live view of zones, spawns and VEAF state machines in a browser. | Shared building block across PERSISTENCE, DCS-BRIDGE-FINISH and AI-GAMEMASTER. |
| **Tooling** | **COMMUNITY-AUTOUPDATE** | Pin + drift-watch the bundled community scripts (CTLD/CSAR/TUM/MiST) like `update-dcs-data` does for DCS data. | ⚠️ **David's doubt — low priority**: most have a VEAF wrapper to adapt by hand on each bump, so manual update is probably better. Captured, not favoured. |
