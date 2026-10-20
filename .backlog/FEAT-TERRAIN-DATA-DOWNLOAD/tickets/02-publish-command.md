# 02 — `veaf-build terrain-data`: publish the grids

Status: ✅ done

Files: `veaf_build/cli.py` (the subcommand), a small module for the manifest, tests, `doc/developer/` (a new page, fr + en, in the `nav`).

## Done when

- `veaf-build terrain-data <dir>` loads every `*.terrain` of the folder, refuses one whose header names another theatre, writes `terrain-data.json` and shows what it would upload with the sizes.
- With `--publish`, it creates the `terrain-data` release (not latest) when missing and uploads the grids and the manifest with `--clobber`.
