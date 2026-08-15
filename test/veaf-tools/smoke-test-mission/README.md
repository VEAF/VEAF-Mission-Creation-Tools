# Smoke-harness test mission (Syria)

The committed test mission for `FEAT-DCS-SMOKE-HARNESS` (ticket 01). A **source folder**, built by the
normal pipeline — the `.miz` is a reproducible build artefact and is gitignored, not committed.

## Why this theatre and anchor

Theatre **Syria**, everything anchored at **`(-32220, 405386)`** — the `dcs-sms` anchor documented as
"empty desert, far from anything, but DCS does process events there". **Verified in game 2026-08-15**:
a unit spawned at that anchor and blown up produced a death event (the harness caught it), on a `land`
surface at ~242 m. The counter-example that makes the anchor worth pinning — over open water DCS
silently drops death events — is credited to `dcs-sms` and recorded in
[`doc/developer/smoke-harness.md`](../../../doc/developer/smoke-harness.md).

## What it contains

Minimal but not empty, so it behaves like a real mission rather than an empty one:

- a **client aircraft slot** (`SmokePlayer`, A-10C_2, air start) — a mission with no client slot
  behaves differently, so the harness has one;
- a **ground group** at the anchor (`SmokeZone-SmokeArmor`, two M-1 Abrams);
- a **trigger zone** (`SmokeZone`), wired as a VEAF combat zone in `mission.yaml`;
- the VEAF scripts, injected the normal way at build.

## Build it

```
veaf-tools mission build SmokeTest . --dev-mode --scripts-path <repo root>
```

`dev_mode` is deliberately **not** persisted in `mission.yaml` (it is machine-specific), so pass the
flags at build time. `veaf-tools mission validate .` is clean (a real player slot, coalitions set).
