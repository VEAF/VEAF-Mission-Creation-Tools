# 03 — Bring `test/python/` under the ruff gate

Status: ⬜ ready
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

- [ ] Fix the 9 `I001` findings (`ruff check test/python/ --fix`) and the 2 formatting
      diffs (`ruff format test/python/`) — mechanical, no logic touched.
- [ ] Extend the CI gate to the test tree: `ruff check src/python/ test/python/` and
      `ruff format --check src/python/ test/python/` in `python-quality.yml`.
- [ ] Note the same in `CLAUDE.md` §7 (Python quality validation) so the documented command and
      the CI command agree.
- [ ] Check whether `veaf_build/` deserves the same treatment — it is application code outside
      `src/python/veaf-tools`, and it is what ticket 02 touches. State the answer either way.
- [ ] CHANGELOG (developer-facing).

## Verify

The commit that widens the gate must be **green on its own**: fix the findings first (or in the
same commit), never widen a gate onto a red tree.

## Notes

Scope is the ruff gate only. Extending **mypy** to the test tree is a much larger question
(tests use loose typing on purpose, `monkeypatch`, `# type: ignore[no-untyped-def]` helpers) and
is deliberately out of scope here — raise it separately if wanted.
