# CHORE-SMALL-POLISH — four small things David noted on 2026-09-29

Status: ✅ done (PR #1026, merged 2026-09-29)

Noted by David while testing, grouped so they ship together rather than as four lots. None of them
blocks anything; each is small on its own.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [radio kneeboards mangle non-ASCII names](tickets/01-kneeboard-utf8.md) | ✅ |
| 02 | [an icon on `veaf-logs.exe`](tickets/02-veaf-logs-icon.md) | ✅ |
| 03 | [every first-level radio menu in capitals](tickets/03-radio-menus-uppercase.md) | ✅ |
| 04 | [`veaf-logs`: a button to show or hide the filter panel](tickets/04-veaf-logs-toggle-filters.md) | ✅ |

## Definition of done

- Each ticket closed with what was measured, not only what was changed.
- Tests for 01, 03 and 04; 02 checked on a built `veaf-logs.exe`.
- `CHANGELOG.md` entry; `doc/` updated where a menu name or a screenshot changes.
