# Publish the terrain data

The ground elevation grids that `veaf-tools dcs terrain-sweep` sweeps in DCS feed the AI assistant (`terrain_elevation`, `describe_terrain`) and the placement checks, **with no DCS**.
A PC with no DCS open — a demo sandbox, another mission maker's workstation — has none: so the ones VEAF swept are published, and veaf-tools downloads them.

## How veaf-tools uses them {#download}

- The grids are the assets of the GitHub release [`terrain-data`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases/tag/terrain-data), one per theatre (`<Theatre>.terrain`), with a manifest `terrain-data.json` giving each one's size and SHA-256.
- That release is **separate** from the tools' releases: some 26 MB is not re-published with every version, and it is created **not latest**, so the releases page keeps showing the tools first.
- When a theatre has no grid in `<VEAF home>/terrain/`, veaf-tools downloads its own on first use, checks its size, its SHA-256 and that it loads as that theatre's grid, then writes it next to the swept grids.
- A grid already there — swept on the workstation or downloaded before — is used as is, never replaced. To get a re-published grid, delete the file.
- Offline, or when a check fails, the answer stays what it was: "sweep it in DCS". One attempt per process, so a placement does not wait for a timeout each time; the reason is written to veaf-tools' log.
- The download goes through the updater's checks (`veaf_libs/github_download.py`): https on a GitHub host only, every redirect checked, size capped.

## Publish {#publish}

1. Sweep the theatre in DCS: [`veaf-tools dcs terrain-sweep`](../CLI_REFERENCE.en.md#terrain-sweep).
2. Check what would go out, from the repository root:

   ```powershell
   poetry run veaf-build terrain-data
   ```

   The command loads each `*.terrain` of `<VEAF home>/terrain/` (or of the folder given as argument), refuses a file holding another theatre's grid, writes `dist/terrain-data.json` and lists the files with their sizes. Nothing is uploaded.
3. Publish:

   ```powershell
   poetry run veaf-build terrain-data --publish
   ```

   It needs `gh` signed in with write access to the repository.
   The release is created when missing, then the grids are uploaded (`--clobber`), and the manifest last, so it never names a grid not there yet.

The manifest is replaced at each publication: publish from a folder holding every published grid, not only the new one.
The command refuses otherwise, naming the theatres it would withdraw.
