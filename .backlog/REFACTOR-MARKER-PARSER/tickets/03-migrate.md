# 03 — Migrate the ten modules, one per commit

Status: ⬜ ready
Type: refactor

## Order

Smallest first, so the machinery is exercised before it meets the hard cases:
`veafRemote` (11 lines), `veafNamedPoints` (19), `veafShortcuts` (20), `veafSecurity` (28),
`veafRadio` (64), `veafTransportMission` (76), `veafSpawnParser` (86), `veafGroundAI` (97),
`veafMove` (115), `veafCasMission` (125).

## Tasks

- [ ] One module per commit, each keeping ticket 01's tests for that module green **unchanged**.
      A characterisation test that has to be edited to pass is a behaviour change: stop and say so
      rather than editing it.
- [ ] Delete the replaced parser in the same commit. A migration that leaves the old code behind
      has not reduced anything.
- [ ] `veafSecurity` last among the small ones or handled with care: `REVIEW-SECURITY-LAYER`
      touches its `markTextAnalysis` too (the `elevate` verb), so check for a collision first.

## Acceptance criteria

- [ ] All ten migrated, all old parsers deleted, `test-lua` green across 36 suites.
- [ ] The line count actually went down; record the before and after.
