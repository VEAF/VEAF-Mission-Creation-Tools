# 03 — Bring `test/python/` under the ruff gate

Status: ✅ done
Type: chore

## Why

`.github/workflows/python-quality.yml` runs

```yaml
- run: poetry run ruff check src/python/veaf-tools
- run: poetry run ruff format --check src/python/veaf-tools
```

so the **164 files of `test/python/` are linted by nothing**. `CLAUDE.md` documents the gate as
`ruff check src/python/` too, so the omission is consistent — and invisible.

The drift is real but small, measured today:

| Check | Result on `test/python/` |
|---|---|
| `ruff check` | **9 errors, all `I001`** (import block un-sorted), all auto-fixable, across 9 `veaf_mission_mcp` test files |
| `ruff format --check` | **2 files** would be reformatted |

Nothing alarming — which is the point: it is cheap to fix now and only gets more expensive.
The practical annoyance is that `ruff check test/python/ --fix` run in passing silently rewrites
files unrelated to the current work (it happened during `FEAT-FOOTHOLD-RELEASE-INTAKE` and the
changes had to be reverted).

## Tasks

- [x] Fixed — **12** findings, not the 9 measured when the ticket was written: the drift grew
      while the gate was open, which is the ticket's own argument made concrete. All `I001`, all
      auto-fixed, plus the 2 formatting diffs. No logic touched.
- [x] CI gate widened to `src/python/ test/python/ veaf_build/` for both `ruff check` and
      `ruff format --check`.
- [x] **The trigger paths were widened too** — and this is the part that would have made the rest
      a no-op: `python-quality.yml` only fired on `src/python/**` and `pyproject.toml`, so a change
      confined to `test/python/` would never have run the job that now lints it.
- [x] `CLAUDE.md` updated in both places (§7 and the step-6 checklist), with the mypy/ruff scope
      difference spelled out: ruff covers the whole tree, mypy only the shipped package.
- [x] `veaf_build/` **does** deserve it, and it was free: `ruff check` and `ruff format --check`
      both already passed on its 20 files. Included so it cannot drift.
- [x] CHANGELOG.

## Verify

The commit that widens the gate must be **green on its own**: fix the findings first (or in the
same commit), never widen a gate onto a red tree.

## Notes

Scope is the ruff gate only. Extending **mypy** to the test tree is a much larger question
(tests use loose typing on purpose, `monkeypatch`, `# type: ignore[no-untyped-def]` helpers) and
is deliberately out of scope here — raise it separately if wanted.
