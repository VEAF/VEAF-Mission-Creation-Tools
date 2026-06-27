# Roadmap — VEAF Mission Creation Tools v6

Execution order for the open lots in [.backlog/README.md](.backlog/README.md). Source of truth for
**sequencing**; `.backlog/` stays the source of truth for **scope and status**.

> Refreshed 2026-06-27 after the **6.7.0** release. The original 2026-06-10 sequencing
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
shipped. Continuous dev releases are published from `develop-v6` (`published-vx.y.z`);
the current version is **6.7.0**.

---

## 2. Open backlog (everything left is human-gated)

| Lot | Status | Gate |
|-----|--------|------|
| `FIX-DYNSLOT-TEMPLATE-CATEGORY` | 🔄 | Code shipped in 6.7.0. Ticket 02 (QRA airplane intruder) needs 🧑 **David's in-game check**. |
| `ENRICH-DEFAULT-PRESETS` | ⬜ | Needs a 🧑 **collaboration session with Tripack** to broaden the default `presets.yaml`. |

There is **no Claude-actionable technical lot left** without external input (a David
in-game test, or Tripack data). `RELEASE` stays as a recurring chore template, not a
one-shot lot.

---

## 3. Next macro step — a complete v6 release to `master`

So far every v6 release has been a **dev release** (tag `published-vx.y.z` off
`develop-v6`); `master` still carries v5 (**v5.103.3**). The next milestone is cutting a
**complete, stable v6 release to `master`** — the official v6. **This gates the vision
work below: no §5 initiative starts until that release is out.**

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
| **TUM** | **TUM-EXPLOIT** | Exploit/integrate TUM more deeply and borrow techniques from its code — notably the **Disposition API** and `net.dostring_in` (things impossible in the vanilla DCS API). | 🔍 **Exploration started** (2026-06-27 spike). TUM already bundled. ⚠️ weigh against the SECREV "no arbitrary Lua execution" policy. |
| **Dependencies** | **DROP-MIST** | Remove the hard dependency on MiST entirely — VEAF scripts no longer require or inject MiST. | MiST is injected unconditionally today. Foundation for the campaign work below. |
| **Runtime** | **PERSISTENCE** | New module to persist mission state across runs: DCS units (position/route/mission) **and** VEAF state machines (casMission, combatZone, QRA, …). | Foundation for dynamic campaigns. |
| **Campaign** | **DYNAMIC-CAMPAIGN** | Foothold-*style* dynamic, persistent campaign generation built entirely on VEAF tools — no Moose, no MiST. | Builds on PERSISTENCE + DROP-MIST. |
| **Integration** | **DCS-BRIDGE-FINISH** | Finish integrating `veaf-dcs-bridge` (TCP socket DCS ↔ external server). | Base injection already shipped (`FEAT-DCS-BRIDGE`, archived); remaining scope TBD. |
| **AI** | **AI-GAMEMASTER** | An LLM (e.g. Claude) runs a dynamic campaign live, with `veaf-dcs-bridge` exposed as an **MCP server** giving the AI the keys to DCS while the player flies against its improvisation. | Depends on DCS-BRIDGE-FINISH; overlaps DYNAMIC-CAMPAIGN. |
| **AI** | **NL-MISSION-GEN** | Natural-language mission generator (**design-time**): describe a mission in FR/EN → produce the `mission.yaml` + spawns/zones. | **Decided (David):** built for mission makers to run with **their own AI tooling**, *not* on the doc-chatbot stack. First cut as a **Claude plugin**. Lower risk, shippable earlier than AI-GAMEMASTER. |
| **AI** | **AI-CONVERT-REVIEW** | AI review of `convert-v5` output: compare v5 intent vs v6 result and flag what was lost. | ⚠️ **David's doubt**: requires the mission maker to have AI access — not universal. Optional design-time aid. |
| **AI** | **BRIDGE-DASHBOARD** | Real-time web dashboard via `veaf-dcs-bridge`: live view of zones, spawns and VEAF state machines in a browser. | Shared building block across PERSISTENCE, DCS-BRIDGE-FINISH and AI-GAMEMASTER. |
| **Tooling** | **COMMUNITY-AUTOUPDATE** | Pin + drift-watch the bundled community scripts (CTLD/CSAR/TUM/MiST) like `update-dcs-data` does for DCS data. | ⚠️ **David's doubt — low priority**: most have a VEAF wrapper to adapt by hand on each bump, so manual update is probably better. Captured, not favoured. |
