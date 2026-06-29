# UPDATER-CROSSPLATFORM

Status: ✅ done

## Problem

`veaf-tools-updater` is Windows-only. It extracts `published.zip` and moves
`veaf-tools.exe` out of it, then self-updates via a generated `.cmd` batch script
(to dodge the Windows lock on the running exe). On Linux/macOS none of that works:
the binaries are not in `published.zip` (they ship as separate release assets, see
FEAT-CROSSPLATFORM-BINARIES), the names are `.exe`-hardcoded, there is no `chmod +x`,
and the `.cmd` self-update is meaningless.

## Decision (option 2 — separate assets)

On Unix the updater downloads the **platform-specific binary asset** from the release
(`veaf-tools-<os>-<arch>`, `veaf-tools-updater-<os>-<arch>`) in addition to
`published.zip` (still needed for the common content: Lua bundle, `defaults/`,
community scripts). It installs the binary as `veaf-tools` / `veaf-tools-updater`,
`chmod +x`, and self-updates by replacing the running binary directly (Unix does not
lock it). Windows behaviour is unchanged.

Asset/arch matrix matches FEAT-CROSSPLATFORM-BINARIES:
`linux-x86_64`, `macos-arm64`, `macos-x86_64`.

## Implementation

- `veaf_libs/platform_assets.py` (new, pure/testable): map the current platform to
  the binary file name (`veaf-tools` vs `veaf-tools.exe`), the updater file name, and
  the release asset name (`veaf-tools-linux-x86_64`, …; `None` on Windows). Single
  source of truth for the suffix; the CI matrix mirrors the same three names.
- `veaf-tools-updater.py`: replace the `.exe`-hardcoded constants with the helper;
  in `extract_and_install`, branch on platform — Windows keeps the move-from-zip +
  deferred `.cmd` path; Unix downloads the binary assets, installs them with `chmod +x`,
  and self-updates by direct replacement. `--zip-file` (offline) on Unix installs the
  common content and warns that the binary must be fetched online (not in the zip).
- CI (`release.yml`): the Unix/macOS standalone jobs also build the updater
  (`build-standalone --with-updater`) and upload `veaf-tools-updater-<os>-<arch>`.
- `veaf_build`: `run_standalone(with_updater=True)` builds both binaries (reuses
  `build_python_executables`, no package); CLI gains `--with-updater`.
- Tests (TDD): platform→asset mapping; Unix install downloads + chmods both binaries;
  Windows path unchanged; self-update replaces the running binary on Unix.

## Out of scope

- Code signing / notarization of the macOS binaries.
- A non-PyInstaller packaging (e.g. pip/pipx) of the tools.
