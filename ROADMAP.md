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

## 3. Recommended sequence (waves)

Two tracks can progress in parallel: **Python** (mission-maker tooling) and **Lua**
(pilot runtime). Within a wave, lots are parallelizable unless a dependency above says
otherwise.

### Wave 0 — Unblock & protect  *(start now)*
| Lot | Track | Why now |
|-----|-------|---------|
| **CI-NODE24** | infra | GitHub forces Node 20→24 on **2026-06-16**, removes Node 20 on **2026-09-16**. Independent, cheap, time-boxed. |
| **SECREV** (001 RCE, 002 helo, 007–010 Lua) | both | Release blockers + cheap Lua nil-deref fixes. Note the helo-bug coordination above. |
| **QUALITY-GATE-002** (policy) | meta | Write the ratchet policy **first** so every later lot inherits it. |
| **Phase 0b** (close issues) | infra | No code, no risk — clear it whenever convenient. |

### Wave 1 — Foundation schema
| Lot | Track | Notes |
|-----|-------|-------|
| **MODULES-UNIFY** (001–006) | Python | The keystone. Unblocks CONVERT-FIDELITY and houses the semantic-validation work (006). Hard break — no compat shim. Drop touched-worker mypy exclusion. |

### Wave 2 — Conversion fidelity & detection
| Lot | Track | Gate |
|-----|-------|------|
| **CONVERT-FIDELITY** (001–004) | Python | Needs MODULES-UNIFY shape. |
| **ERA-AUTODETECT** | Python | Independent of schema; can run alongside CONVERT-FIDELITY. |
| **PRESETS-FIDELITY** (13a fix, 13b spike) | Python | Independent; 13a can start anytime, 13b is a spike. |

### Wave 3 — Spawn / aircraft axis  *(decisions first)*
| Lot | Track | Gate |
|-----|-------|------|
| **AIRCRAFT-INJECT** open-questions decision (with David) | — | Settle handoff §7 (file names, step names, hard-break, extraction shape) before coding. |
| **SPAWN-REFACTOR-001** (characterization tests) | Lua | Must precede any spawn edit/dedup. |
| **AIRCRAFT-INJECT** (001–006) | Python | After the decision; fixes helo bug if SECREV-002 didn't. |
| **SPAWN-EXTERNALIZE-001** (spike) → 002 | Lua+Python | Spike emits concrete tickets; fold SPAWN-REFACTOR-002 dedup here. |
| **UXPILOT-FEEDBACK** (001, 002 anytime; 003 after SPAWN-REFACTOR-001) | Lua | Pilot-facing UX; 001/002 have no upstream gate. |

### Wave 4 — Spikes, verification, small UX  *(fillers, low coupling)*
| Lot | Track |
|-----|-------|
| **DYNLOAD-CLARIFY** (spike) | Lua+Python |
| **TRIGGERS-VERIFY** (external dep: Flogas) | Python |
| **TUI-FOLDER-HINT** | Python |
| **DEFAULTS-AUDIT** (after AIRCRAFT-INJECT settles the aircraft YAML) | Python |

### Wave 5 — Release
| Lot | Gate |
|-----|------|
| **Lot 5 — RELEASE v6.1.0** | All SECREV blockers merged + intended feature set done. REL-005 after REL-003 (merge to master). |

---

## 4. One-line answer

> **CI-NODE24 + SECREV blockers → MODULES-UNIFY → everything that depends on the new
> schema (CONVERT-FIDELITY, validation) → the spawn/aircraft axis (tests first, then
> dedup, coordinating the shared helo bug) → spikes/cleanup → RELEASE.**
> QUALITY-GATE rides along the whole way, never as a separate big-bang.
