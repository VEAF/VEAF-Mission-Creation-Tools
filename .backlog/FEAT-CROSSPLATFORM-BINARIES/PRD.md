# FEAT-CROSSPLATFORM-BINARIES

Status: ✅ done

## Problem

The release only ships Windows executables (`veaf-tools.exe`, `veaf-tools-updater.exe`)
built by PyInstaller on a `windows-latest` runner. Users on Linux and macOS have no
ready-to-run binary. PyInstaller cannot cross-compile, so each target OS must build on
its own runner.

## Decision

Ship a standalone `veaf-tools` binary for Linux and macOS as **additional** release
assets, built by per-OS CI jobs. The Windows flow (exe + updater + `published.zip`) is
unchanged. Only the main `veaf-tools` CLI is shipped cross-platform — the updater is
Windows-centric (handles `.exe` / `published.zip`) and out of scope.

Targets (per David):

- Linux: `ubuntu-22.04` (lower glibc → broad distro compatibility) → `veaf-tools-linux-x86_64`
- macOS arm64: `macos-latest` → `veaf-tools-macos-arm64`
- macOS Intel: `macos-13` → `veaf-tools-macos-x86_64`

## Implementation

- `veaf_build/worker.py`: refactor `build_python_executables` into small helpers
  (`_prepare_dist`, `_scan_lua_modules`, `_veaf_tools_extra_data`, `_build_veaf_tools_exe`,
  `_build_updater_exe`) — behaviour unchanged. Add `build_veaf_tools_standalone()` (builds
  only `veaf-tools`, no updater, no package) and `run_standalone()`.
- `veaf_build/cli.py`: new `build-standalone` command producing `dist/veaf-tools`
  (`.exe` on Windows) with no updater and no `published.zip`.
- `.github/workflows/release.yml`: three new jobs (`release-linux`, `release-macos-arm64`,
  `release-macos-x86_64`), `needs: release`, each builds the standalone binary, renames it
  per OS/arch and uploads it to the existing GitHub Release via `gh release upload`.
- `veaf_build/github.py`: also upload `veaf-tools.exe` (Windows) as a **direct** release
  asset (versioned + latest), not only inside `published.zip` — symmetric with the
  Linux/macOS binaries so every platform's `veaf-tools` is a one-click download.
- Tests: standalone builds only `veaf-tools`; full build still builds both; extra-data
  bundles locales.
- Docs/CHANGELOG: `[Unreleased]` entry; mention Linux/macOS binaries in release notes.

## Out of scope

- The updater on Linux/macOS (Windows-only update mechanism).
- Code signing / notarization of the macOS binaries.
- Auto-update of the cross-platform binaries.
