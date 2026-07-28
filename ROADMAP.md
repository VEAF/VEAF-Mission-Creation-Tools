# Roadmap — VEAF Mission Creation Tools v6

Execution order for the open lots in [.backlog/README.md](.backlog/README.md). Source of truth for
**sequencing**; `.backlog/` stays the source of truth for **scope and status**.

> Refreshed 2026-07-04 after **6.7.8**. The original 2026-06-10 sequencing
> (CI-NODE24 → SECREV → MODULES-UNIFY → conversion cluster → spawn axis → RELEASE) is
> **fully delivered** and has been retired from this file; see `.backlog/archive/` for the
> closed lots.

---

## 1. Where we are

The v6 development cycle is **essentially complete**. Everything that was scoped as a
backlog lot — infra (CI, quality gates), the unified `modules:` schema, the conversion
cluster (`convert-v5`/`convert-other`, fidelity, presets), the spawn/aircraft-injection
axis, the mission-maker tooling (`validate`, `prepare --template`, CLI↔TUI bridge,
build-time reference validation), Foothold-on-v6, and the safe Lua-free `export` — has
shipped. Continuous dev releases are published from `develop` (`published-vx.y.z`);
the current version is **6.7.8**.

---

## 2. Open backlog (everything left is human-gated)

| Lot | Status | Gate |
|-----|--------|------|
| `FEAT-FOOTHOLD-RELEASE-INTAKE` | ⬜ | None for 01-03 (Claude-actionable). Ticket 04 (`foothold-ww2` profile) is gated on 🧑 **David deciding whether VEAF runs a Normandy Foothold**. |
| `ENRICH-DEFAULT-PRESETS` | ⬜ | Needs a 🧑 **collaboration session with Tripack** to broaden the default `presets.yaml`. |

`RELEASE` stays as a recurring chore template, not a one-shot lot.

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
> **Ordering constraint (David, 2026-06-27):** vision lots are tackled **only after a
> complete v6 release has been cut to `master`** (see §3). Order below is thematic, not a
> commitment.

| Theme | Initiative | One-line intent | Notes / dependencies |
|-------|------------|-----------------|----------------------|
| **Missions** | **PORT-MISSIONS-V6** | Port all VEAF missions (the *open trainings*) to v6. | 🔄 **In progress on David's side** (manual port). Also a large-scale real-world validation of the v6 tooling. |
| **TUM** | **TUM-EXPLOIT** | Borrow techniques from TUM's code. Two distinct axes: **(🟢 native)** the undocumented **`Disposition`** DCS singleton for scenery-aware ground spawning — directly usable, no prereq; **(🔴 server)** `net.dostring_in` + `a_*` internals (live HP/briefing, JSON persistence) — powerful but server-only. | 🔍 **Explored** — see [`docs/exploration/TUM-EXPLOIT.md`](docs/exploration/TUM-EXPLOIT.md). 🟢 tier could ship as a small standalone lot; 🔴 tier feeds PERSISTENCE/DYNAMIC-CAMPAIGN and needs an `autoexec.cfg` unsanitize + SECREV fencing. |
| **Dependencies** | **DROP-MIST** | Remove the hard dependency on MiST entirely — VEAF scripts no longer require or inject MiST. | MiST is injected unconditionally today. Foundation for the campaign work below. |
| **Runtime** | **PERSISTENCE** | New module to persist mission state across runs: DCS units (position/route/mission) **and** VEAF state machines (casMission, combatZone, QRA, …). | Foundation for dynamic campaigns. |
| **Campaign** | **DYNAMIC-CAMPAIGN** | Foothold-*style* dynamic, persistent campaign generation built entirely on VEAF tools — no Moose, no MiST. | Builds on PERSISTENCE + DROP-MIST. |
| **Integration** | **DCS-BRIDGE-FINISH** | Finish integrating `veaf-dcs-bridge` (TCP socket DCS ↔ external server). | Base injection already shipped (`FEAT-DCS-BRIDGE`, archived); remaining scope TBD. |
| **AI** | **AI-GAMEMASTER** | An LLM (e.g. Claude) runs a dynamic campaign live, with `veaf-dcs-bridge` exposed as an **MCP server** giving the AI the keys to DCS while the player flies against its improvisation. | Depends on DCS-BRIDGE-FINISH; overlaps DYNAMIC-CAMPAIGN. |
| **AI** | **NL-MISSION-GEN** | Natural-language mission generator (**design-time**): describe a mission in FR/EN → produce the `mission.yaml` + spawns/zones. | **Decided (David):** built for mission makers to run with **their own AI tooling**, *not* on the doc-chatbot stack. First cut as a **Claude plugin**. Lower risk, shippable earlier than AI-GAMEMASTER. **🔄 Started** (2026-07-12, ahead of the master-release gate — David: normal gitflow on `develop`, no need to wait): see [`FEAT-MCP-MISSION-EDITOR`](.backlog/FEAT-MCP-MISSION-EDITOR/PRD.md) (waves 1-4 shipped: editor-parity + embedded-Lua + VMCT `mission.yaml` actions; waves 5-8 planned: domain-knowledge oracle → convention-aware group creation → composite one-pass builders for combat zones / QRA / CAP) and [ADR 0014](docs/adr/0014-mission-editor-mcp-editor-parity-layer.md). |
| **AI** | **AI-CONVERT-REVIEW** | AI review of `convert-v5` output: compare v5 intent vs v6 result and flag what was lost. | ⚠️ **David's doubt**: requires the mission maker to have AI access — not universal. Optional design-time aid. |
| **AI** | **BRIDGE-DASHBOARD** | Real-time web dashboard via `veaf-dcs-bridge`: live view of zones, spawns and VEAF state machines in a browser. | Shared building block across PERSISTENCE, DCS-BRIDGE-FINISH and AI-GAMEMASTER. |
| **Tooling** | **COMMUNITY-AUTOUPDATE** | Pin + drift-watch the bundled community scripts (CTLD/CSAR/TUM/MiST) like `update-dcs-data` does for DCS data. | ⚠️ **David's doubt — low priority**: most have a VEAF wrapper to adapt by hand on each bump, so manual update is probably better. Captured, not favoured. |
