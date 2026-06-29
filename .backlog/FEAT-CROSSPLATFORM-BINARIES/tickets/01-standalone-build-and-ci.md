# 01 — Standalone veaf-tools build + cross-platform CI jobs

Status: ✅ done

## Goal

Produce a standalone `veaf-tools` binary for Linux and macOS as extra release assets,
without disturbing the Windows release flow.

## Tasks

- [ ] Refactor `build_python_executables` into reusable helpers (no behaviour change).
- [ ] Add `BuildAndReleaseWorker.build_veaf_tools_standalone()` and `run_standalone()`.
- [ ] Add `veaf-build build-standalone` CLI command.
- [ ] Add CI jobs `release-linux` (ubuntu-22.04), `release-macos-arm64` (macos-latest),
      `release-macos-x86_64` (macos-13) that upload per-OS binaries to the release.
- [ ] Tests: standalone builds only `veaf-tools`; full build builds both; extra-data
      bundles locales.
- [ ] CHANGELOG `[Unreleased]` + PATCH bump in `pyproject.toml`.

## Done when

- `veaf-build build-standalone --version X` yields `dist/veaf-tools` locally.
- The release workflow attaches the three new binaries to the GitHub Release.
- `poetry run pytest`, `ruff check`, `ruff format --check`, `mypy src/python/veaf-tools` pass.
