# 02 — DCS crash archives (`.zip`) in the Go core

Status: 🔄 in-progress

Milestone J1, toolkit-free.
`tailer.py` opens a log inside a `.zip` (inventory O2); the Go core has no archive support.

## Done when

- `ArchiveMembers` lists the log members (`.log`, `.txt`, folders excluded) in the Python order: `.log` before `.txt`, then `dcs.` / `dcs-` first, stable otherwise.
- A member opens into an in-memory buffer, the first member by default; an archive with no log is an error; an archive is not followable and never rotates; its display name is `<archive> : <member basename>`.
- Tests on archives built by the test itself, the ranking compared with the Python `archive_members` on the same names.
