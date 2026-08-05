# 03 — CI freshness gate

Status: ⬜ ready
Type: chore
Files: `.github/workflows/`, developer guide

Depends on: 01, 02

## Behaviour

A CI job that regenerates both files and fails when the result differs from what is committed — the
`cli-docs-fresh` pattern from `dcs-sms`. Without it the generators are optional, and the docs rot
again, just more slowly.

- Runs on the same triggers as the existing docs job.
- The failure message says **which** file is stale and **which command** to run. A gate that only says
  "diff found" makes people guess.
- Fast: regeneration reads two data sources and renders. If it needs a heavy import chain, fix that in
  ticket 02 rather than accepting a slow gate.

## Tasks

- [ ] Job added; fails on a deliberately stale file, passes once regenerated.
- [ ] Failure output names the file and the command.
- [ ] Wired into the same workflow as `docs-check` rather than a new one, unless the triggers genuinely
      differ — one docs job is easier to reason about than two.
- [ ] Developer guide mentions the gate and the command.

## Acceptance criteria

- [ ] Proven both ways in CI: red on a stale commit, green after regenerating.
- [ ] **No path filter that lets a change to `veaf-units.yaml` or to the MCP catalogue skip the job** —
      that is the exact case the gate exists for, and `FIX-WORKFLOWS-MAIN-TO-MASTER` is what a
      never-triggering job costs.
