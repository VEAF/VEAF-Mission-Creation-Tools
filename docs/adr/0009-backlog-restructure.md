---
status: accepted
---

# Backlog restructure to `.backlog/` per-lot directories

The backlog lived in a single ~200 KB `backlog.md` (+ ~135 KB `backlog-archive.md`).
With one branch/PR per lot (CLAUDE.md §8), the monolith was a recurring
merge-conflict surface, and loading it cost significant agent context. We also
wanted to drive the backlog with the Matt Pocock engineering skills, which are
issue-tracker-agnostic and configured per repo (no fork required).

## Decision

Adopt a per-lot `.backlog/` structure:

- **Active lots** are directories — `.backlog/<LOT-ID>/PRD.md` plus one
  `tickets/<NN>-<slug>.md` per ticket.
- **Completed lots** are compact `.backlog/archive/<LOT-ID>.md` files (ticket table
  preserved, not split).
- A single `Status:` vocabulary (⬜ ready · 🔄 in-progress · 🧑 waiting-human ·
  ✅ done · 🚫 wontfix) maps onto Matt's triage roles.
- The Matt Pocock skills stay globally installed and unmodified; per-repo config
  under `docs/agents/*` plus an `## Agent skills` block in `CLAUDE.md` adapts them
  to this backlog.
- The lot index `.backlog/README.md` is maintained by hand (no generator script).
- ROADMAP remains the **sequencing** source of truth; `.backlog/` is the **scope +
  status** source of truth.

## Consequences

- No more backlog merge conflicts; agents load only the relevant lot.
- `to-prd` / `to-issues` work against the local backlog with no upstream fork.
- One-time migration cost; archived shipped lots are kept compact, not split.
- See the design spec: `docs/superpowers/specs/2026-06-24-backlog-restructure-design.md`.
