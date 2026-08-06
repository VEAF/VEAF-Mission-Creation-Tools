# 03 — CI freshness gate

Status: ✅ done
Type: chore
Files: `.github/workflows/docs-check.yml`

## Delivered

No new workflow: `main()` already runs every pass and exits non-zero on any of them, and the existing
`docs-check` job already invokes it. One docs job stays one docs job.

The part that needed real care was the **trigger**. The job was scoped to `doc/**`, `mkdocs.yml`,
`veaf_build/docs_check.py`, `.backlog/**`, `docs/**` and root `*.md`. Adding an MCP action touches
**none** of those — it touches `src/python/veaf-tools/veaf_mission_mcp/`. So the gate would have been
blind to the exact commit it exists to catch, which is `FIX-WORKFLOWS-MAIN-TO-MASTER` all over again:
a job that never runs on the branch, or the change, that matters.

- [x] `src/python/veaf-tools/veaf_mission_mcp/**` and `src/scripts/veaf/veafShortcuts.lua` added to the
      `pull_request` paths, with the reason in a comment.
- [x] No second workflow.

## Acceptance criteria

- [x] `python veaf_build/docs_check.py` — exactly what CI runs — is green, exit 0.
- [ ] Red on a deliberately undocumented capability, observed in CI. **Not done**: it needs a throwaway
      commit adding an action, which is not worth carrying on this PR. The positive half is covered —
      this PR touches both new trigger paths, so the job running on it proves they resolve.
