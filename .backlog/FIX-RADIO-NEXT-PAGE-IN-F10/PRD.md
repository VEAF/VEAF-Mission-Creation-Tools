# FIX-RADIO-NEXT-PAGE-IN-F10 — "Next page" is always the last entry of a radio menu page

Status: ✅ done — merged in #1342 (2026-11-23), shipped in 6.39.1

Flight check: on the Campagne server, every radio menu page ends with "Next page" in F10 as in F9, after pilots join and after the shop is used (ticket 01's flight check).

Seen on the Campagne server on 2026-11-22 (David): several radio menus show "Page suivante" in F9 and another entry in F10. David, 2026-11-23: a defect of VEAF's radio menus, every mission concerned, not the campaign's; its own lot, split out of FIX-CAMPAIGN-SIXTH-SERVER-FLIGHT.

## Read (2026-11-23)

`veafRadio` paginates at render time: `MENU_PAGE_SIZE = 10`, a full page holding 9 entries plus "Next page" (`veafRadio.lua` lines 36, 971, 1036-1041). So something adds an entry after a page was laid out, or outside `veafRadio`. Which menus are concerned is not known.

## Decided

One ticket, one branch and one pull request into `develop`.

| # | Ticket |
|---|---|
| 01 | ["Next page" always in F10](tickets/01-next-page-in-f10.md) |
