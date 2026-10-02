# FIX-USER-REPORTS-985-989 — two user reports with no lot behind them

Status: 🧑 waiting-human — both fixed 2026-10-02; ticket 02 waits for its in-game reading (`DCS-SESSION-TODO.md` R22)

Opened 2026-10-02 from a sweep of the backlog against the open issues: three reports from mission makers
had no lot — [#985](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/985),
[#989](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/989) and
[#953](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/953). David, 2026-10-02: one PR for
the first two, a reply drafted for the third, and the six lots closed for more than three days archived
in the same move.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [the shipped spawnables sit under the CJTF countries](tickets/01-spawnables-under-cjtf.md) | ✅ |
| 02 | [a dynamic-slot helicopter gets its CSAR menu](tickets/02-csar-menu-for-dynamic-slots.md) | 🧑 |
| 03 | [#953: what Tripack's 09-19 test settles](tickets/03-hidden-statics-953.md) | ✅ |

## Definition of done

- [x] No template of `src/defaults/mission-folder/src/spawnables.yaml` under a real country, pinned by a test that fails on the old file.
- [x] `csar.getGroupId` reads the live group, with a test that fails on the old code; `vendored.yaml` names the adaptation.
- [x] #953's static half recorded as a DCS behaviour in `known-limitations.yaml`, R15 updated, a reply drafted for David to post.
- [ ] R22 read in game.
