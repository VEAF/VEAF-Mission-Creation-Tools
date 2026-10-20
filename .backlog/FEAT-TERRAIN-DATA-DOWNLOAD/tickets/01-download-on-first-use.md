# 01 — download a missing grid on first use

Status: ✅ done

Files: `veaf_libs/github_download.py` (new: trusted-host check and redirect walk, out of `veaf-tools-updater.py`), `veaf-tools-updater.py` (imports them), `veaf_libs/terrain_elevation.py`, `veaf_mission_mcp/terrain.py` and `surface.py` (the "no grid" message), tests.

## Done when

- A theatre with no local grid is fetched from the `terrain-data` release, checked (size, SHA-256, loads as that theatre) and written atomically to `~/.veaf/terrain`; the next call reads the local file.
- A local grid is never downloaded over.
- Offline, an unknown theatre, a bad checksum, an untrusted redirect or an oversized answer: `None`, the file system untouched, one attempt per process.
- The updater's tests pass unchanged against the moved helpers.
