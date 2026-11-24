# FIX-RADIO-MENU-ID-RECYCLING — a VEAF menu left open fires the command the player sees

Status: ✅ done · archived 2026-11-24

Reported by Fulgas on 2026-10-09: now and then, a CTLD or VEAF F10 command fires something other than what the player clicked.
CTLD had already "fixed" it (VEAF/CTLD ADR 0015: wipe the menu now, rebuild it 4 s later), and it still happens.

## What DCS does — measured 2026-10-09

Measured with David in single player, raw `missionCommands`, mission restarted before each test, clicks with the mouse, the change applied from the fiddle hook while the player held `TEST MENU > Liste` (A, B, C, D) open.
Recorded as `f10-menu-entry-id-is-recycled` in `known-limitations.yaml`, reported as VEAF/CTLD#257.

| Change applied while the list is on screen | Clicked | Fired |
|---|---|---|
| remove A, B, C, D, then add them again, identical | B | **C** |
| remove A, then add E | A | **E** |
| remove A, then add E | B | B |
| remove A, then add X and Y elsewhere; menu reopened fresh | X, Y | X, Y |
| group menu: remove A, then add E | A | **E** |
| remove A, add a command for a group that does not exist, then add E (global and group menus) | A | that command |

DCS tracks an entry by an internal id, gives a removed entry's id to the next entry created, and does not refresh a screen that stays open.
The ids are one pool for the whole server, so a stale click can even fire another group's command, a secured one with that group's identity.

## Cause in VMCT

`RadioMenuBuilder:rebuild()` removes the VEAF root and recreates the whole tree, for every group, on every `refreshRadioMenu()` — every human join, every combat zone, CAS, transport or asset change.
Every entry gets a recycled id at once: the first row of the table, on the whole menu.

## What the lot delivers

1. **Incremental rendering** (ticket 01): a refresh compares the tree it renders with the one already in DCS and touches only the difference; an entry whose place, label, callback and parameters are unchanged is never removed.
   A human join adds only that group's commands.
2. **Freed ids parked** (ticket 02): right after each removal, an inert command for a group id no player can hold takes the freed id, so a stale click on a removed entry lands on nothing.
3. **Docs and changelog** (ticket 03).

## Decided (David, 2026-10-09)

- **a)** An entry added after the first render goes to the end of its menu: putting it in alphabetical place would mean recreating the ones after it. Lists are sorted on first render only.
- **b)** Ticket 02 after the in-game measurement — done, the parked command takes the id in global and group menus.
- **c)** The vendored CTLD is not patched here; its fix belongs to VEAF/CTLD (#257).
- **d)** Stable pages, decided after the in-game check showed an addition shifting entries across pages and landing after page 1's "Next page": an entry already shown keeps its page, a new one goes to the last page.

## Out of scope

- `veafRadio.createUserMenu`, which builds a group's custom menu straight through `missionCommands` once.

## Tickets, in full

## 01 — Render the radio menu incrementally

Status: ✅ done

`RadioMenuBuilder:rebuild()` stops removing the VEAF root.
Every `missionCommands` call of a render goes through the builder, which keys each entry by its audience (all, a coalition, a group), its parent and its label, and keeps what it rendered last time.

### Done when

- An entry rendered again with the same key, callback and parameters reuses the DCS entry: no remove, no add.
- An entry whose callback or parameters changed is removed and added again.
- An entry no longer rendered is removed, children before their parent.
- A second human group joining adds only that group's commands.
- In a paginated menu, an entry already shown keeps its page and a new one goes to the last page.
- Lua tests on the mocks prove each of these.

## 02 — Park each freed id on an inert command

Status: ✅ done

Measured 2026-10-09: right after `removeItem`, a command added for a group that does not exist takes the freed id, and a stale click on the removed entry fires it.

### Done when

- Each removal is followed by one inert command for `veafRadio.PARKING_GROUP_ID`, a group id no player can hold, with a unique label.
- The inert command does nothing but log at debug level.
- A Lua test proves the order: remove, then park, before any add of the same render.

## 03 — Docs and changelog

Status: ✅ done

### Done when

- `CHANGELOG.md` `[Unreleased]` says what a player saw and what changes (new entries at the end of their menu).
- The developer page describing `veafRadio` menu building says the render is incremental and why.
- `known-limitations.yaml` holds the measurement (`f10-menu-entry-id-is-recycled`), page regenerated.
