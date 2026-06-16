# Roadmap — VEAF Mission Creation Tools v6

Execution order for the open lots in [backlog.md](backlog.md). Source of truth for
**sequencing**; `backlog.md` stays the source of truth for **scope and status**.

> Generated 2026-06-10 from a dependency + priority analysis. Update the wave a lot
> sits in whenever a dependency or priority changes.

---

## 1. Priority tiers

- **P0 — Deadline / release-blocking.** Do first, regardless of dependencies.
- **P1 — Foundation.** Unblocks several other lots; pay it early.
- **P2 — Features.** The bulk of the value; gated on P1 where noted.
- **P3 — Cleanup / spikes / verification.** Low coupling; good fillers, parallelizable.
- **RELEASE.** Always last.

| Tier | Lots |
|------|------|
| **P0** | CI-NODE24 · SECREV (001 RCE + 002 helo are the blockers) |
| **P1** | MODULES-UNIFY · QUALITY-GATE (policy kick-off) |
| **P2** | CONVERT-FIDELITY · ERA-AUTODETECT · PRESETS-FIDELITY · AIRCRAFT-INJECT · SPAWN-EXTERNALIZE · SPAWN-REFACTOR · UXPILOT-FEEDBACK |
| **P3** | Phase 0b · DYNLOAD-CLARIFY · TRIGGERS-VERIFY · TUI-FOLDER-HINT · DEFAULTS-AUDIT |
| **RELEASE** | Lot 5 (v6.1.0) |

---

## 2. Hard dependencies (X must precede Y)

```
MODULES-UNIFY ─────────────▶ CONVERT-FIDELITY      (explicit: target YAML shape)
MODULES-UNIFY ─────────────▶ MODULES-UNIFY-006     (validation rides the new schema)
SPAWN-REFACTOR-001 ────────▶ UXPILOT-003           (tests before unknown-param hints)
SPAWN-EXTERNALIZE-001 (spike) ▶ SPAWN-EXTERNALIZE-002
AIRCRAFT-INJECT open-questions decision ▶ AIRCRAFT-INJECT-001..006
SECREV-001 + SECREV-002 ───▶ RELEASE (Lot 5)       (release blockers)
REL-003 ───────────────────▶ REL-005               (doc URL flip after merge to master)
```

### Coordination hazards (same code touched by two lots — fix once)

- **Helicopter extraction bug** lives in BOTH `SECREV-002` and `AIRCRAFT-INJECT-003`
  (`aircrafts_injector_worker.py` ~L1070-1086). Whichever lot runs first fixes it; the
  other drops its copy. **Do not patch twice.**
- **Spawn files** (`veafSpawnParser/Aircraft/Ground/Core`) are reopened by
  `SPAWN-EXTERNALIZE`, `AIRCRAFT-INJECT`, `SPAWN-REFACTOR`, and `UXPILOT-003`.
  Land `SPAWN-REFACTOR-001` (characterization tests) **before** any of them dedupes or
  edits, and do the de-dup inside whichever lot reopens the file first
  (`SPAWN-REFACTOR` may be folded into `SPAWN-EXTERNALIZE`).
- **mypy exclusions**: every P1/P2 lot that substantially edits an excluded worker must
  drop that worker's `ignore_errors` entry as part of its Definition of Done
  (`QUALITY-GATE-002` policy). `QUALITY-GATE-001` only mops up the remainder.

---

## 3. Linear sequence (two-person team: David + Claude)

There is no parallel track — Claude implements one lot at a time, David decides and
does the manual DCS testing. So the only real scheduling concern is the **human gate**:
batch the steps that need David (a decision, or a manual mission test per `CLAUDE.md`
§8.8) so the implementation queue never stalls waiting on him.

**Legend:** 🧑 = needs David (decision or manual test) · 🐍 Python · 🌙 Lua · ⚙️ infra

| # | Lot | Tier | Gate / note |
|---|-----|------|-------------|
| 1 | **CI-NODE24** ⚙️ | P0 | Deadline: Node 20→24 forced **2026-06-16**, removed **2026-09-16**. Trivial, do first. |
| 2 | **Phase 0b** — close issues ⚙️ | P3 | 🧑 David confirms each issue before closing. No code; a quick warm-up. |
| 3 | **QUALITY-GATE-002** — ratchet policy 🐍 | P1 | Write the convention in `CLAUDE.md` before touching any worker. |
| 4 | **SECREV** 🐍🌙 | P0 | Release blockers. Do the Python batch (001 RCE, 002 helo, 003 eval, 004/005 zip, 006 weather) then the Lua batch (007–010). **Fix the helo bug here** → AIRCRAFT-INJECT-003 later just drops its copy. 🧑 manual test after the RCE rerouting. |
| 5 | **MODULES-UNIFY** (001–006) 🐍 | P1 | Keystone schema. Includes semantic validation (006). Hard break. Drop the touched worker's mypy exclusion. 🧑 schema sign-off + manual build test. |
| 6 | **CONVERT-FIDELITY** (001–004) 🐍 | P2 | Needs #5's YAML shape. 🧑 eyeball a real `convert-v5-report.md`. |
| 7 | **ERA-AUTODETECT** 🐍 | P2 | Conversion-adjacent; batch with #6 to stay in the converter. |
| 8 | **PRESETS-FIDELITY** (13a fix, 13b spike) 🐍 | P2 | Closes the Python-conversion cluster. 🧑 verify radio channels in-game. |
| 9 | **AIRCRAFT-INJECT decision** 🧑 | — | Settle handoff §7 (file/step names, hard-break, extraction shape) before any code. |
| 10 | **SPAWN-REFACTOR-001** — characterization tests 🌙 | P2 | Must land before any spawn-file edit/dedup (#11, #12). Pure safety net. |
| 11 | **AIRCRAFT-INJECT** (001–006) 🐍 | P2 | After #9. Helo bug already fixed in #4. 🧑 manual spawn test. |
| 12 | **SPAWN-EXTERNALIZE-001 (spike) → 002** 🌙🐍 | P2 | Fold **SPAWN-REFACTOR-002** (spawn dedup) in here — same files. 🧑 spike review before impl. |
| 13 | **UXPILOT-FEEDBACK** (001, 002, then 003) 🌙 | P2 | 003 needs #10's tests. 🧑 feel the feedback in a real mission. |
| 14 | **DYNLOAD-CLARIFY** (spike) 🌙🐍 | P3 | 🧑 spike review. |
| 15 | **TRIGGERS-VERIFY** 🐍 | P3 | 🧑 needs Flogas's missions — slot whenever they're available, else defer. |
| 16 | **TUI-FOLDER-HINT** 🐍 | P3 | Small UX; good low-energy filler. |
| 17 | **DEFAULTS-AUDIT** 🐍 | P3 | After #11 settles the aircraft YAML ownership. |
| 18 | **Lot 5 — RELEASE v6.1.0** 🧑 | RELEASE | All SECREV blockers + feature set merged. REL-005 after REL-003 (merge to master). |

**QUALITY-GATE-001** is not a scheduled row: it's continuous — each Python lot above
drops its touched worker's mypy exclusion and nudges `--cov-fail-under` up. The leftover
workers get mopped up whenever there's slack.

### David's queue (the human-gated steps, in order)
Close Phase 0b issues (#2) → MODULES-UNIFY schema sign-off (#5) → AIRCRAFT-INJECT
decision (#9) → spike reviews (#12, #14) → manual DCS tests after #4, #5, #8, #11, #13 →
release approval (#18). Everything else, Claude runs without blocking on you.

---

## 4. One-line answer

> **CI-NODE24 → SECREV blockers (fix the helo bug here) → MODULES-UNIFY → conversion
> cluster (CONVERT-FIDELITY, ERA, PRESETS) → AIRCRAFT-INJECT decision → spawn axis
> (tests first, then aircraft-inject, externalize+dedup, pilot UX) → spikes/cleanup →
> RELEASE.** QUALITY-GATE rides along; David is only needed at the 🧑 gates.

---

## 5. Forward-looking vision (NOT backlog yet)

> These are **prospective** initiatives — captured so they are not lost, but **not yet
> scoped backlog**. None has a branch, tickets, or a committed plan. Each becomes a real
> `backlog.md` lot (with a Summary row and detailed tickets) only the day we decide to
> start it. Order below is thematic, not a commitment.

| Theme | Initiative | One-line intent | Notes / dependencies |
|-------|------------|-----------------|----------------------|
| **Dependencies** | **DROP-MIST** | Remove the hard dependency on MiST entirely — VEAF scripts no longer require or inject MiST. | MiST is injected unconditionally today (`FIX-DEFAULTS-MODULES`). Foundation for the campaign work below. |
| **Runtime** | **PERSISTENCE** | New module to persist mission state across runs: DCS units (position/route/mission) **and** VEAF state machines (casMission, combatZone, QRA, …). | Foundation for dynamic campaigns. |
| **Campaign** | **DYNAMIC-CAMPAIGN** | Foothold-*style* dynamic, persistent campaign generation built entirely on VEAF tools — no Moose, no MiST. | Builds on PERSISTENCE + DROP-MIST. |
| **Campaign** | **FOOTHOLD-V6** | Rework the **existing** Foothold process and bring it onto the v6 toolchain. | Port of the current setup — distinct from the from-scratch DYNAMIC-CAMPAIGN engine. |
| **Integration** | **DCS-BRIDGE-FINISH** | Finish integrating `veaf-dcs-bridge` (TCP socket DCS ↔ external server). | Base injection already shipped (`FEAT-DCS-BRIDGE`, archived); remaining scope TBD. |
| **AI** | **AI-GAMEMASTER** | An LLM (e.g. Claude) runs a dynamic campaign live, with `veaf-dcs-bridge` exposed as an **MCP server** giving the AI the keys to DCS while the player flies against its improvisation. | Depends on DCS-BRIDGE-FINISH; overlaps DYNAMIC-CAMPAIGN. |
| **TUM** | **TUM-EXPLOIT** | Exploit/integrate TUM more deeply and borrow techniques from its code — notably the **Disposition API** and `net.dostring_in` (things impossible in the vanilla DCS API). | TUM already bundled. |
| **Missions** | **PORT-MISSIONS-V6** | Port all VEAF missions (the *open trainings*) to v6. | Also a large-scale real-world validation of the v6 tooling. |
| **Tooling** | **COMMUNITY-AUTOUPDATE** | Pin + drift-watch the bundled community scripts (CTLD/CSAR/TUM/MiST) like `update-dcs-data` does for DCS data. | ⚠️ **David's doubt — low priority**: most of these have a VEAF wrapper/helper that must be adapted by hand on each bump, so manual update is probably better. Captured, not favoured. |
| **AI** | **NL-MISSION-GEN** | Natural-language mission generator (**design-time**): describe a mission in FR/EN → the AI produces the `mission.yaml` + spawns/zones. | Build-time counterpart of AI-GAMEMASTER; lower risk, shippable earlier. Reuses the doc chatbot stack. |
| **AI** | **AI-CONVERT-REVIEW** | AI review of `convert-v5` output: compare v5 intent vs v6 result and flag what was lost. | ⚠️ **David's doubt**: requires the mission maker to have AI access — not universal. Could ship as an optional design-time aid. |
| **AI** | **BRIDGE-DASHBOARD** | Real-time web dashboard via `veaf-dcs-bridge`: live view of zones, spawns and VEAF state machines in a browser. | Shared building block across PERSISTENCE, DCS-BRIDGE-FINISH and AI-GAMEMASTER. |
