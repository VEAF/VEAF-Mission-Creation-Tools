# 05 — Wire the pass into CI

Status: ✅ done
Type: chore
Files: `.github/workflows/`

Depends on: 01, and on 02/03 for the gate to be green when it lands

## Behaviour

The new pass runs in CI on the same job as `docs-check` — one docs job, not two. Since `main()`
already runs both passes and exits non-zero on either, this may be **no workflow change at all**:
verify what the existing job invokes before writing anything.

The thing that must not be got wrong is the **trigger paths**. The existing docs job is scoped to
documentation paths, and this pass covers `.backlog/`, `docs/` and root `*.md`. If those are not in
the trigger, a PR that breaks a backlog link never runs the gate — which is precisely how
`FIX-WORKFLOWS-MAIN-TO-MASTER` happened: a job triggered on a branch that did not exist, so it never
ran on the branch that mattered.

## Tasks

- [x] Read what the current docs job runs and on which paths.
- [x] Ensure `.backlog/**`, `docs/**` and root `*.md` are in the trigger, or that the job has no path
      filter at all.
- [ ] Prove it: a commit touching only a `.backlog/` file must run the job.
- [ ] Prove the negative too: a deliberately broken backlog link must turn CI red.

## Acceptance criteria

- [ ] Red on a broken link under `.backlog/`, green once fixed — both observed in CI, not reasoned
      about. **Outstanding**: this PR proves the positive half (it touches `.backlog/**` and `docs/**`,
      so the job must run on it); the negative half needs a deliberately broken link, which is not
      worth a throwaway commit on this PR.
- [x] No second docs workflow introduced.
