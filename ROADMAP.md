# Roadmap — VEAF Mission Creation Tools v6

Execution order for the open lots in [.backlog/README.md](.backlog/README.md). Source of truth for
**sequencing**; `.backlog/` stays the source of truth for **scope and status**.

> Refreshed 2026-08-13 after the documentation audit (§2), which added three lots.
> Previously refreshed 2026-08-06 after the SECREV-2 security work. The original 2026-06-10 sequencing
> (CI-NODE24 → SECREV → MODULES-UNIFY → conversion cluster → spawn axis → RELEASE) is
> **fully delivered** and has been retired from this file; see `.backlog/archive/` for the
> closed lots.

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

Continuous dev releases are published from `develop` (`published-vx.y.z`). The last published
release is **6.13.0** (2026-08-01); `develop` is at **6.13.95**.

---

## 2. Open backlog — the order, and what is in the way

[.backlog/README.md](.backlog/README.md) is the full open list and the source of truth for scope
and status. This section is the **order**, plus what stands in the way of everything not in it.

### The 2026-08-11 order is delivered

The three lots David sequenced on 2026-08-11 — `CHORE-SMS-QUICK-WINS`,
`FEAT-CUSTOM-SCRIPT-LOAD-DELAY`, `FEAT-MCP-MUTATION-ACTIONS` — are **done down to what needs the
game or a person**: 2 shipped in full, and the MCP lot closed every ticket an agent can finish
alone (01-07 plus 08's tooling; 08's capture and 09 want a DCS session). What is left of them is in
the table below.

### The order, decided 2026-08-13

Twelve lots are open, plus one opened by the work below. **Four are new**, all born from the
five-pass documentation audit of 2026-08-13 (~150 defects found while `docs-check` stayed green
throughout, because everything that rotted is what the gate cannot see: content). They carry most of
the remaining agent-only work:

| Order | Lot | Weight | Why here |
|-------|-----|--------|----------|
| ✅ | [`FIX-DOCAUDIT-CODE`](.backlog/FIX-DOCAUDIT-CODE/PRD.md) | 6 tickets | **Closed 2026-08-13.** The only lot where the audit proved the **code** wrong, twice on the security surface: the dispatchers refused the tier names David decided (`ADMIN` failed the registration assert) and `_transport` called its check without the marker id, so a listed `SENIOR_PILOT` typed the password anyway. Its ticket 04 hardened four `docs-check` blind spots, which is the *before* half of the sequencing `DOC-AUDIT-FIXES` 04 needs. |
| **1** | [`DOC-AUDIT-FIXES`](.backlog/DOC-AUDIT-FIXES/PRD.md) 03-04 | 2 tickets | Closes the lot: the holes rather than the lies. The new security model has **no pilot-facing page**, and the CLI has no real reference — David wants full command documentation *in addition to* `--help`. Ticket 04 also carries a debt from the lot above: the hardened option rule is enabled for the updater only, because the mission-maker guide names 4 of the main CLI's 59 long options; the new reference page is what lets it cover the other 59, and enabling it is one tuple entry in `OPTION_RULES`. |
| **2** | [`DOC-MODULE-PAGES`](.backlog/DOC-MODULE-PAGES/PRD.md) | 3 tickets | Five registered modules have no page and no README row, two of them with player-facing surfaces: `veafGroundAI` (whose `-ai_set` alias is already documented, pointing at nothing) and `veafCombatMission` (the F10 `MISSIONS` menu). David's arbitration d: a lot of its own. |
| **3** | [`FIX-RADIO-SPECS-GENERATOR-LOCALE`](.backlog/FIX-RADIO-SPECS-GENERATOR-LOCALE/PRD.md) | 1 ticket | Opened by `FIX-DOCAUDIT-CODE` 06, which could not run the generator it was fixing: `update-dcs-data --radio` writes a whole English page over the **French** one and never touches the English page. Measured — 100 lines replaced by 84, `docs-check` green throughout. Small and bounded; last of the four because the manual workaround is documented and works. |

[`FEAT-PORTABLE-PREFABS`](.backlog/FEAT-PORTABLE-PREFABS/PRD.md) is looked at once those are
merged — one ticket, and it is a design decision where **a rejection is an acceptable outcome**. It
adds nothing to the release by itself, which is why it is not in the ordered set.

### Blocked on a person, or on a DCS session

Not on a decision anyone can take at a keyboard here. The ones needing the game started are collected, in
running order and with the commands to paste, in [DCS-SESSION-TODO.md](DCS-SESSION-TODO.md).

| Lot | Status | Gate |
|-----|--------|------|
| [`FEAT-MCP-MUTATION-ACTIONS`](.backlog/FEAT-MCP-MUTATION-ACTIONS/PRD.md) | 🔄 | Everything an agent can finish alone is merged. **Ticket 08's capture needs a DCS session** — `capture-map --parking` over the existing dcs-bridge, five minutes per theatre — and ticket 09 (`add_air_group` on a ramp) is blocked on that data. The editor round trips for the six unmeasured drawing shapes are the same session. |
| [`CHORE-SMS-QUICK-WINS`](.backlog/CHORE-SMS-QUICK-WINS/PRD.md) | 🔄 | Ticket 02 is **delivered but unproven**: Gemini CLI is not installed here, so "tested rather than assumed" is unmet. One command validates it. |
| [`FEAT-CUSTOM-SCRIPT-LOAD-DELAY`](.backlog/FEAT-CUSTOM-SCRIPT-LOAD-DELAY/PRD.md) | ✅ | Delivered 2026-08-11 and verified against the real Foothold Caucasus 4.4.1 `.miz`. One in-game confirmation left, on David. |
| [`ENRICH-DEFAULT-PRESETS`](.backlog/ENRICH-DEFAULT-PRESETS/PRD.md) | ⬜ | A 🧑 **collaboration session with Tripack** to broaden the default `presets.yaml`. |
| [`FEAT-DCS-SMOKE-HARNESS`](.backlog/FEAT-DCS-SMOKE-HARNESS/PRD.md) | 🔄 | Its remaining slice — locate, launch, load, quit. `net.load_mission` and `Sim.exitProcess` are **measured present** and `isServer()` is true in single-player, so nothing technical blocks it; **starting DCS is David's to do on his own session.** |
| [`FEAT-ASSIST-FOLLOWUP`](.backlog/FEAT-ASSIST-FOLLOWUP/PRD.md) | 🔄 | Ticket 01 shipped 2026-08-11. **Kept for after the release on David's call** — 02 needs a second pilot, 03 needs cockpit time, and 04 is deferred on purpose. Ticket 01 still wants one flight to confirm it, since no unit test can see DCS's resource cache. |
| [`FEAT-ASSIST-AUTHORING`](.backlog/FEAT-ASSIST-AUTHORING/PRD.md) | ⏸ | Parked by David 2026-08-03 — checklists nobody reviews are not worth generating. Ticket 06 waits on a pilot's verdict on the F-14B(U) procedure. |
| [`FIX-SECREV2-EXPIRED-DEFERRALS`](.backlog/FIX-SECREV2-EXPIRED-DEFERRALS/PRD.md) | 🔄 | Ticket 01 shipped 2026-08-11 (VMR-088, a unit's life read twice). Ticket 02 — the fiddle-server port — needs a DCS session. |

**`FEAT-DCS-SMOKE-HARNESS` was the lever, and it paid.** Run on the DCS workstation on 2026-08-06, it
answered two pending in-game questions by machine rather than by a person: it closed
`FEAT-COMBATZONE-MENU-COALITION` (open since July) and turned `Disposition` from assumed into existing.
It also cost three of its own defects to get there — all the same mistake, *"it came back" is not "it
worked"* — every one invisible to `dcs_mocks.lua` by construction. Keep going there: the remaining
checks are data entries now, not investigations.

`RELEASE` stays as a recurring chore template, not a one-shot lot. It is starting to mature:
**6.13.0 was published 2026-08-01 and `develop` is 95 patch versions ahead.**

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

**Delivered since the last refresh:**

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
| **dcs-sms** | **DCS-SMS-EXPLOIT** | Borrow ideas from [nielsvaes/dcs-sms](https://github.com/nielsvaes/dcs-sms) (DCS scripting framework + Mission Editor mod + host CLI). Four tiers: **(🟢 quick wins)** write the DCS coordinate convention down, ship the authoring skill to Gemini, add a `dev_condition`-style test hatch to assistance steps; **(🟡 MCP mutation wave)** their 126 `me <noun> <verb>` verbs read as a coverage grid — see NL-MISSION-GEN below; **(🟡 real-DCS smoke harness)** assert through the bridge inside a running DCS, plus their documented test-mission contract; **(🔵 later)** autogenerated reference with a CI freshness gate, and portable prefabs with a shared manifest-driven library. | 🔍 **Explored, and now scoped into real lots** (2026-08-05) — see [`docs/exploration/DCS-SMS-EXPLOIT.md`](docs/exploration/DCS-SMS-EXPLOIT.md). ⚠️ **`tools/` is GPL v3** (the CLI, the ME mod, the hook): read and rewrite, never copy. Two items were already closed — the live-ME bridge is **rejected** ([ADR 0017](docs/adr/0017-no-live-mission-editor-bridge.md)) and their cockpit-highlight machinery **shipped** as `FEAT-ASSIST-CHECKLISTS`. The rest is now filed, in rough order of value: [`FEAT-MCP-MUTATION-ACTIONS`](.backlog/FEAT-MCP-MUTATION-ACTIONS/PRD.md) (§1 — the MCP edits nothing it did not create; triage by intent first, **not** a port of their 126 verbs), [`FEAT-DCS-SMOKE-HARNESS`](.backlog/FEAT-DCS-SMOKE-HARNESS/PRD.md) (§2 — four in-game checks are currently queued behind a human; never a CI gate, since runners have no DCS), [`TOOLING-DOC-AUTOGEN`](.backlog/archive/TOOLING-DOC-AUTOGEN.md) (§3 — only `ALIASES` and the MCP catalogue are derivable; the 118 KB `LUA_API_REFERENCE` is prose and stays hand-written), [`FEAT-PORTABLE-PREFABS`](.backlog/FEAT-PORTABLE-PREFABS/PRD.md) (§4 — a **design** lot: their implementation is GPL *and* editor-bound, so the selection front-end must be invented or the idea dropped) and [`CHORE-SMS-QUICK-WINS`](.backlog/CHORE-SMS-QUICK-WINS/PRD.md) (§5 — all three still absent). |
| **TUM** | **TUM-EXPLOIT** | Borrow techniques from TUM's code. Two distinct axes: **(🟢 native)** the undocumented **`Disposition`** DCS singleton for scenery-aware ground spawning — directly usable, no prereq; **(🔴 server)** `net.dostring_in` + `a_*` internals (live HP/briefing, JSON persistence) — powerful but server-only. | 🔍 **Explored** — see [`docs/exploration/TUM-EXPLOIT.md`](docs/exploration/TUM-EXPLOIT.md). **🟢 tier SHIPPED** as [`FEAT-SCENERY-AWARE-SPAWN`](.backlog/archive/FEAT-SCENERY-AWARE-SPAWN.md) (2026-08-05, [ADR 0018](docs/adr/0018-undocumented-dcs-api-dependency.md)): `veaf.findSpawnPoint` searches in three bounded tiers — `Disposition` first, validated random draws second, explicit failure third — wired into the four dynamic ground spawners plus the generic `doSpawnGroup`, the convoy excluded since its departure point is its route origin; typed zone-property accessors came with it. The in-game probe was **deferred**, so the avoidance is asserted rather than measured. 🔴 tier feeds PERSISTENCE/DYNAMIC-CAMPAIGN and needs an `autoexec.cfg` unsanitize + SECREV fencing. |
| **Dependencies** | **DROP-MIST** | Remove the hard dependency on MiST entirely — VEAF scripts no longer require or inject MiST. | MiST is injected unconditionally today. Foundation for the campaign work below. |
| **Runtime** | **PERSISTENCE** | New module to persist mission state across runs: DCS units (position/route/mission) **and** VEAF state machines (casMission, combatZone, QRA, …). | Foundation for dynamic campaigns. |
| **Campaign** | **DYNAMIC-CAMPAIGN** | Foothold-*style* dynamic, persistent campaign generation built entirely on VEAF tools — no Moose, no MiST. | Builds on PERSISTENCE + DROP-MIST. |
| **Integration** | **DCS-BRIDGE-FINISH** | Finish integrating `veaf-dcs-bridge` (TCP socket DCS ↔ external server). | Base injection already shipped (`FEAT-DCS-BRIDGE`, archived); remaining scope TBD. |
| **AI** | **AI-GAMEMASTER** | An LLM (e.g. Claude) runs a dynamic campaign live, with `veaf-dcs-bridge` exposed as an **MCP server** giving the AI the keys to DCS while the player flies against its improvisation. | Depends on DCS-BRIDGE-FINISH; overlaps DYNAMIC-CAMPAIGN. |
| **AI** | **NL-MISSION-GEN** | Natural-language mission generator (**design-time**): describe a mission in FR/EN → produce the `mission.yaml` + spawns/zones. | **Decided (David):** built for mission makers to run with **their own AI tooling**, *not* on the doc-chatbot stack. First cut as a **Claude plugin**. Lower risk, shippable earlier than AI-GAMEMASTER. **🔄 Started** (2026-07-12, ahead of the master-release gate — David: normal gitflow on `develop`, no need to wait): see [`FEAT-MCP-MISSION-EDITOR`](.backlog/archive/FEAT-MCP-MISSION-EDITOR.md) (waves 1-4 shipped: editor-parity + embedded-Lua + VMCT `mission.yaml` actions; waves 5-8 planned: domain-knowledge oracle → convention-aware group creation → composite one-pass builders for combat zones / QRA / CAP) and [ADR 0014](docs/adr/0014-mission-editor-mcp-editor-parity-layer.md). **Next wave identified (2026-08-04, from DCS-SMS-EXPLOIT):** the catalogue's 31 actions are strong on VEAF domain and on *creation*, and near-silent on **mutating what already exists** — no unit setter (loadout, skill, livery, position, callsign, parking…), no group setter (rename, move, hide, frequency, country, late activation…), no route/waypoint or waypoint-task editing, no arbitrary triggers, no F10 drawings. Not a port of their 126 verbs: triage by mission-maker intent. |
| **AI** | **AI-CONVERT-REVIEW** | AI review of `convert-v5` output: compare v5 intent vs v6 result and flag what was lost. | ⚠️ **David's doubt**: requires the mission maker to have AI access — not universal. Optional design-time aid. |
| **AI** | **BRIDGE-DASHBOARD** | Real-time web dashboard via `veaf-dcs-bridge`: live view of zones, spawns and VEAF state machines in a browser. | Shared building block across PERSISTENCE, DCS-BRIDGE-FINISH and AI-GAMEMASTER. |
| **Tooling** | **COMMUNITY-AUTOUPDATE** | Pin + drift-watch the bundled community scripts (CTLD/CSAR/TUM/MiST) like `update-dcs-data` does for DCS data. | ⚠️ **David's doubt — low priority**: most have a VEAF wrapper to adapt by hand on each bump, so manual update is probably better. Captured, not favoured. |
