# 01 — License and content audit of what the executables bundle

Status: ✅ done

Findings and verdict: [audit.md](../audit.md).

Read-only: nothing is changed in the repository by this ticket.

## Done when

- Every component inside `veaf-tools.exe`, `veaf-tools-updater.exe` and `veaf-logs.exe` is listed — Python packages frozen by PyInstaller (the `release` dependency set, read from the build, not guessed), data files added with `--add-data`, vendored Lua scripts, DCS-derived data (catalogues, terrain, airdromes), anything downloaded at build time — with its license and where the license was read.
- Each one is classed against SignPath's terms: OSI-approved and compatible / not OSI or unclear / proprietary or derived from DCS files.
- The executables' behaviour on the network is listed (what each one contacts and when), for the privacy statement.
- The findings, with a recommendation per blocker, are written into this lot (PRD Outcome or an `audit.md` beside it).
