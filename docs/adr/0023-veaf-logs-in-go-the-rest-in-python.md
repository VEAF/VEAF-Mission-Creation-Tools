---
status: accepted
---

# `veaf-logs` ships in Go; the rest of the tools stay in Python

Lot: [FEAT-GO-VEAF-LOGS-ISOFUNCTIONAL](../../.backlog/FEAT-GO-VEAF-LOGS-ISOFUNCTIONAL/PRD.md), decision 6.
Decided by David on 2026-10-25.

## Context

The Go rewrite of `veaf-logs` reached the Python viewer's surface in five milestones (J1–J5): same filters, profiles, session files, remote journals, *Explain* and `/bug` report, proven identical on the reference corpora.
Measured against the Python executable: 7.5 MB instead of 47.2 MB, the window in 0.04 s instead of 2.1 s, a 130 MB journal indexed in 2.4 s instead of 13.3 s ([ADR 0022](0022-ui-toolkit-for-the-go-veaf-logs.md), the lot's J2 section).
The question left open was whether the Go viewer replaces the Python one, and whether the port goes further.

## Decision

- The Go `veaf-logs` replaces the Python viewer as the shipped `veaf-logs.exe`.
- Nothing else is converted: `veaf-tools`, the MCP server, the build tooling and the support bot stay in Python.
  Converting them would cost far more than it brings — David: "trop lourd de convertir".

## Consequences

- Shipping the Go viewer is a lot of its own, [FEAT-GO-VEAF-LOGS-SHIP](../../.backlog/FEAT-GO-VEAF-LOGS-SHIP/PRD.md): the release pipeline builds it, the PySide6 viewer leaves.
- The Python `veaf_logs` package does not disappear with its window: the support bot imports its core (`rules`, `store`, `buffer`, `profiles`, `excerpt`, `catalogue`), and the Go parity tests compare against goldens generated from it.
  Which parts stay, and which side becomes the reference, is that lot's first question.
- A future Go rewrite of another tool is not ruled out, but needs a decision of its own; this one does not open the door.
