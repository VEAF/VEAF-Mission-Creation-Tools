# FIX-BUILD-EXE-SMOKE — a build that produces a dead executable fails

Status: 🔄 in-progress

Origin: 2026-11-18, measured by another session while preparing 6.38.0.
Run outside Poetry, `python build-and-release.py build` exited 0, and the `veaf-tools.exe` it produced died on start with `ModuleNotFoundError: mission_builder.mission_builder_README`.
It blocks the 6.38.0 release.

## Cause

`veaf-tools` is built with `--collect-submodules mission_builder` (see `_LAZY_PACKAGES` in `veaf_build/worker.py`): the package resolves its exports lazily, so PyInstaller cannot follow them from `import` statements.
PyInstaller evaluates `collect_submodules()` in a child interpreter whose `sys.path` is the build interpreter's, plus `PYTHONPATH`.
`src/python/veaf-tools` is on that path only when the package is installed in the environment — Poetry's venv.
Elsewhere `collect_submodules("mission_builder")` finds nothing, PyInstaller logs a warning nobody reads, and exits 0.

The `exe-smoke` CI job does not see it: it builds through `poetry run`, where the package is installed.

## Change

1. **Cause**: the PyInstaller call gets `src/python/veaf-tools` on its `PYTHONPATH`, so `--collect-submodules` sees the same packages whatever interpreter runs the build.
2. **Guard**: every executable the build produces is started once (`--help`) before the build hands back; a non-zero exit, a timeout or a missing file fails the build with the executable's output in the message.
   It catches the whole family — this defect, 6.15.0's lazy `mission_builder`, any import PyInstaller misses — not only the one measured here.

## Tickets

- [01 — collect-submodules sees the source tree, and every built executable is started once](tickets/01-build-exe-smoke.md)
