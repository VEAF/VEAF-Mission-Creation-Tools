# FIX-SECURED-FORALL-AND-UPDATER-BAT — two defects from the GermanyCW Open Training of 2026-09-29

Status: ✅ done (PR #1028, merged 2026-09-29)

Found on the private1 server session of 2026-09-29 (`VEAF_OpenTraining_GermanyCW_ICAO_ETAR_20260928.miz`,
security enabled) and grouped in one PR.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [secured "for all" radio commands refuse every click](tickets/01-secured-forall-commands-refused.md) | ✅ |
| 02 | [the updater writes its batch file in the wrong encoding](tickets/02-updater-batch-encoding.md) | ✅ |

## Definition of done

- 01: Lua tests showing a secured ForAll command is posted per group, keeps its parameters, runs for
  an authorised group and is refused below the level; unchanged when security is disabled.
- 02: the generated script is ASCII and enters an accented mission folder (run on Windows); the
  encoding guard also covers `Path.read_text()` / `Path.write_text()`.
- `CHANGELOG.md` entry; `veafSecurity` page updated in FR and EN.
