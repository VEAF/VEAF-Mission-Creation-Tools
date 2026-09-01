---
Status: ✅ done — shipped 2026-09-01 (PR #879), and proven on a live pull request: #880 touches one root `.md` and showed 7 checks with no `python-quality` before the rebase, 10 with it after
---

# FIX-CI-PYTHON-GATE-NEVER-RUNS — the Python gate does not run for most of what its suite checks

Origin: found 2026-09-01 while taking the inventory of open lots. `develop` was red on this machine
and green on GitHub, which is what led to both defects below.

## 1. The trigger paths do not cover what the suite asserts on

`Python Quality` (`.github/workflows/python-quality.yml`) filters on `paths:`, listing
`src/python/**`, `test/python/**`, `veaf_build/**`, `pyproject.toml` and `poetry.lock`. Its suite
reads a good deal more than that:

| Path | Read by |
|------|---------|
| `.backlog/**` | `test_backlog_status_consistency`, `test_docs_check` |
| `src/scripts/**` | ~15 tests — bundle manifest, module scanner, mission defaults, CTLD config, publish-local, validator |
| `doc/**` | `test_documented_lua_defaults`, `test_v5_converter`, `test_docs_check` |
| `plugin/**` | `test_plugin_version` (the release version lockstep) |
| `CHANGELOG.md` | `test_changelog_process` |

So a change confined to any of those merges without pytest, ruff or mypy ever running, and reads
green off the Lua and docs checks. **Measured on the three most recent lots**: #877, #875 and #866
each show seven or eight green checks and no `python-quality` run at all.

It is not theoretical. #877 (backlog + `test/lua/` only) carried a scope table whose Status cell read
`✅ done` where the test requires a lone icon — so it left `develop` red on
`test_backlog_status_consistency`, the very test written to catch that, and the merge-when-green rule
had nothing to go on.

The file's own header comment already states the rule it breaks: *"The trigger paths must cover
everything the gate below checks, or widening the gate is a no-op."* `Docs Check` and
`DCS Mock Coverage` both do this correctly — they list the source files their gate reads, not only
their own directory.

## 2. Two conversion-report tests were green by coincidence

Found in the same pass, and the reason `develop` looked green in CI while failing here.

`test_convert_report_rendering.py` asserted `assertIn("3", markdown.split("\n---")[0])` on a report
whose header is a title and a timestamp — the counter it claims to check sits **after** that first
divider and was never in the string. What the assertion actually matched was the **clock**:
`Generated: … 10:32` contains a `3`. So the test passed at 10:32 and failed at 10:27, and the CI
happened to run on a lucky minute. Its comment claimed to pin the counter to the items; it pinned
nothing.

`test_convert_other_delay_sync.py` had the same shape: `assertIn("12", markdown)` over the whole
document, which also matches twelve minutes past any hour.

Both are from PR #857 (2026-08-31) — mine, two days old.

## Definition of done

- [x] The workflow's trigger paths cover every tree the suite asserts on, both for `push` and for
      `pull_request`, with the reason recorded next to the list
- [x] A test keeps the two lists identical and keeps the new paths present — the file duplicates
      them because GitHub Actions does not resolve YAML anchors
- [x] The two coincidence-green tests read the one line that carries the number, and a second case
      drives two different totals so a constant cannot pass for a count
- [x] Both are shown to fail when the thing they check is broken: a counter off by one, and a delay
      reported as zero
- [x] `develop` is green again on this machine — the stale scope table from #877 is fixed, and the
      whole suite passes in **both** locales (`VEAF_LANG=fr` and `=en`)

## Scope

| # | Ticket | Type | Status |
|---|--------|------|--------|
| 01 | [Trigger the gate on what it checks](tickets/01-trigger-paths-cover-the-suite.md) | fix | ✅ |
| 02 | [Two tests that read the clock instead of the number](tickets/02-tests-green-by-coincidence.md) | fix | ✅ |

## Out of scope

- Splitting the suite so a backlog-only change runs only the cheap tests. The job takes about
  3 min 30 s; running it on more PRs is the cost of the filter meaning something. Worth revisiting
  only if that becomes a real drag.
- The other workflows' filters. `Docs Check` and `DCS Mock Coverage` were checked in passing and
  both already list the sources they read.
