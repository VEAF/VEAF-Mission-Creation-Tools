# 01 — Cross-platform updater (Linux/macOS)

Status: ✅ done

## Tasks

- [ ] `veaf_libs/platform_assets.py`: platform → binary name / updater name / asset name.
- [ ] Replace `.exe`-hardcoded constants in `veaf-tools-updater.py` with the helper.
- [ ] Unix install path: download `veaf-tools-<os>-<arch>` + updater asset, `chmod +x`,
      self-update by direct replacement. Windows path unchanged.
- [ ] `--zip-file` on Unix: install common content, warn the binary is online-only.
- [ ] `veaf_build`: `build-standalone --with-updater` builds both binaries.
- [ ] CI: Unix/macOS jobs build + upload `veaf-tools-updater-<os>-<arch>`.
- [ ] Tests (TDD) for the mapping, the Unix install, and the unchanged Windows path.
- [ ] CHANGELOG `[Unreleased]`.

## Done when

- On Linux/macOS, running the updater installs/updates `veaf-tools` and self-updates.
- Windows behaviour is byte-for-byte unchanged.
- Quality gate + tests green.
