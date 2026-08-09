# 04 — Bring `test/lua/` under the StyLua gate

Status: ✅ done — 2026-08-09

## Why

The pendant of ticket 03, which did the same for ruff on `test/python/`. The CI ran
`stylua --check src/scripts/veaf/` only, so the 36 files of `test/lua/` were formatted by
nothing.

## How it actually came about, because that matters

Not as planned work. During the `SECREV-2` ticket 07 sweep, a `stylua src/scripts/ test/lua/`
run — meant for the two files being changed — reformatted **all 36 test files**, and it went
into `develop` with PR #678: 77 000 lines of diff around two real fixes.

That is precisely the trap this repository already documents (*"never run a formatter over a
whole file outside your scope"*), and it had already cost two clean-ups before this one.

The repair chosen was **not** a revert. Reverting means a second massive commit, so twice the
noise for nothing, and it would restore files to an unformatted state that nothing maintains.
The formatting was wanted — it was the *timing* that was wrong. Gating it makes it enforced and
durable instead of accidental and temporary.

## Tasks

- [x] Widen the CI job to `--check src/scripts/veaf/ test/lua/`.
- [x] Verify the widened scope passes on the tree as it stands, with the **same StyLua version
      the CI pins** (2.4.0) — a gate that does not pass is worse than no gate.
- [x] Update `CLAUDE.md` in both places so the documented command and the CI command agree.
- [x] Leave `src/scripts/other/` **out**, deliberately: those files come from elsewhere (DCSSB,
      the fiddle server) and reformatting them would fight their upstream.

## Acceptance criteria

- [x] `test/lua/` cannot drift back: the gate fails on an unformatted test file.
- [x] The documented command and the CI command are the same string.
