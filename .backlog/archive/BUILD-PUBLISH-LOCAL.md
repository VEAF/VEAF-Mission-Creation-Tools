# Lot BUILD-PUBLISH-LOCAL — local publish mode for `veaf-build`

Status: ✅ done

**Goal**: add a **local publish** mode to `veaf-build` that, instead of uploading the release to GitHub (rarely done now that the CI handles publishing), deploys the build output directly into a **user-provided target directory** — a VEAF mission source folder. The mode copies the contents of the `published/` folder plus the two compiled executables (`veaf-tools.exe`, `veaf-tools-updater.exe`) into that folder, so a mission maker gets the latest tooling + scripts locally without going through GitHub / the updater.

**Decisions (settled)**: dedicated subcommand `publish-local <dir>` (not a flag on the GitHub-specific `publish`); deploy from the canonical `published.zip`; the goal is to reproduce the **end state of the updater run in a mission folder** — extract `published.zip` into `<dir>/published/` and **move** both `.exe` to the folder root; overwrite in place (the `.exe` are overwritten); the `.exe` are carried by `published.zip` so no cross-platform special-casing.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| BUILD-PUBLISH-LOCAL-001 | `veaf-build publish-local <dir>` (+ `deploy_published_locally` worker): extract `published.zip` into `<dir>/published/`, move `veaf-tools.exe`/`veaf-tools-updater.exe` to root — reproduces the updater's end state, no GitHub. Tests, `TOOLS_REFERENCE` (FR/EN), CHANGELOG, version bump. | `veaf_build/cli.py`, `veaf_build/worker.py`, `test/python/veaf_build/`, `doc/`, `CHANGELOG.md` | feat | ✅ |
