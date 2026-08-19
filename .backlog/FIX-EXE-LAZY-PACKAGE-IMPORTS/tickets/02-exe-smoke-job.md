# 02 — Answer the question: does anything check that the executable starts?

Status: ✅ done — 2026-08-19. `exe-smoke` job added to `python-quality.yml`.
Type: chore
Files: `.github/workflows/python-quality.yml`

## The question this answers

The PRD asks it: three defects of the same family have now shipped — *works from source, broken in
the exe* — and each was fixed by adding one entry to the build plus one test asserting that entry.
A test per incident, no test for the family. Ticket 01's guards are of that shape too: they know
about lazy packages because a lazy package broke us.

## The answer: no, and one job fixes it

Nothing in the suite can answer it. Every test runs from the checkout, where an import PyInstaller
cannot see resolves perfectly — the packaged import graph is not observable from a checkout at all.
The only test that can is running the built binary.

`exe-smoke` in `python-quality.yml`: build the standalone binary, then

- `veaf-tools --help`, which walks the whole command tree and therefore imports every command
  module — exactly what 6.15.0 broke;
- `veaf-tools generate-config --output .`, which runs real code and writes a real file.

It is a separate job because it needs the `build` dependency group (pyinstaller) that the quality
gate deliberately excludes, and it runs on the same paths, so a change to `veaf_build/` or to any
package is covered.

**What it costs and what it does not cover**, said plainly rather than implied:

- Roughly 2–4 minutes of runner time per Python-touching PR, in parallel with the existing job.
- It runs on Linux. PyInstaller cannot cross-compile, so this proves the *import graph and the
  bundled data* are right, not that the Windows binary is — a Windows-only packaging defect would
  still get through. Adding a Windows runner is the obvious extension; not taken now because the
  three defects it would have caught were all platform-independent.
- Two commands are not 25. `--help` covers every command's imports; only `generate-config` covers
  execution. A missing data file used by one command only (the conversion profiles were exactly
  that) still gets through unless that command is smoked.

So the honest claim is narrow: **this would have caught all three defects to date**, and it makes
the fourth cheap to cover — one line, in a job that already exists.

## Done when

- [x] The CI builds the executable and runs it on every Python-touching PR
- [x] The smoke covers the import graph (`--help`) and one real execution
- [x] What it does not cover is written down, not left to be discovered
