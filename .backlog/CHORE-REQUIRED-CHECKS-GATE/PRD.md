# CHORE-REQUIRED-CHECKS-GATE — path-filtered workflows that a required check can wait for

Status: 🔄 in-progress

Origin: David, 2026-10-03 — *"pourquoi je ne peux jamais activer l'automerge ?"*

## The problem

`develop` was not protected, so GitHub never had anything to wait for: auto-merge was greyed out
("ready to merge now — nothing to wait for") and `gh pr merge --auto` merged at once. Protecting
`develop` with required status checks fixes that, but only for checks that run on **every** pull
request. A required check whose workflow does not start — `on.pull_request.paths` excluded the PR —
stays *Expected* for ever and blocks the merge. Measured on 2026-10-03:

| check | every PR? |
|---|---|
| `Lua Unit Tests`, `Luacheck`, `StyLua Formatting`, `Lua Coverage`, `Gitleaks` | yes |
| `python-quality`, `exe-smoke`, `veaf-logs-exe-smoke` | no — path-filtered |
| `Links, anchors, translations, nav…` (Docs Check) | no — path-filtered |
| `quality`, `container` (Support Bot) | no — path-filtered |

Requiring only the first row would let a Python PR with a red `python-quality` auto-merge.

## The change

The three workflows trigger on every pull request. A first job, `changes`, diffs the PR against its
base and matches the files against the workflow's path list (`veaf_build/ci_path_gate.py`, stdlib
only, GitHub's glob semantics); every other job `needs` it and runs only on `run == 'true'`. A job
skipped that way reports **Skipped**, which a required check accepts. Pushes keep their
`on.push.paths` filter.

`test_ci_trigger_paths.py` now checks the `changes` job's list instead of a duplicated
`pull_request.paths`: it covers what each suite reads, equals `on.push.paths`, no PR is filtered at
the trigger, and every job waits for the gate. All eleven assertions fail on the previous workflows.

## After merge (David)

In *Settings → Branches → develop*, add to the required checks: `python-quality`, `exe-smoke`,
`veaf-logs-exe-smoke`, `Links, anchors, translations, nav (+ repo-wide links)`, `quality`,
`container`.

## Definition of done

- [x] Gate script with its tests; trigger-path test rewritten and proven to fail on the old files.
- [x] Developer guide (FR/EN) and CHANGELOG.
- [ ] This PR's own run shows both outcomes: `Python Quality` and `Docs Check` run (it touches
  `veaf_build/**`, `doc/**`, `*.md`), `Support Bot`'s `quality` and `container` report Skipped (it
  touches nothing of theirs but their own workflow file — which *is* in their list, so they run too;
  the skip is proven by the next PR that touches no bot path).
- [ ] The required checks added on `develop`.

## Fail closed

Found reviewing the first push: a job skipped because its `needs` **failed** also reports Skipped, so
a crashed `changes` job (a failed `git fetch`, say) would have turned every gated check green with
nothing run. The dependents therefore read `!cancelled() && needs.changes.outputs.run != 'false'`:
only an explicit `run=false` skips them, and a failed gate runs the checks. Asserted by
`test_a_failing_gate_runs_the_checks_rather_than_skipping_them`.
