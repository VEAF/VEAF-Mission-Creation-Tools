# FIX-CARRIER-MENU-COALITION — red runs blue's carrier operations

Status: ✅ done

Verified in game on 2026-08-22: check 12 of `verify-mission-c`, from the red A-10 at Palmyra — the slot the defect was measured from on 2026-08-18. The carrier menu is there.

Written, unit-tested and shipped in 6.15.10. Waiting on check 12 of `verify-mission-c` (the red A-10 at
Palmyra), which needs DCS started — see [DCS-SESSION-TODO.md](../../DCS-SESSION-TODO.md).

Origin: `CHORE-ISSUE-VERIFY-SESSION` check 12, confirmed in DCS by David on 2026-08-18 from a red
A-10 at Palmyra. Closes [#87](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/87).

## Measured, and half the issue is already fixed

#87 reported two things. The session settles both:

- **"red can start/stop blue's operations"** — **confirmed**. A red player opens *Carrier operations*
  and drives the blue carrier.
- **"red cannot run its own"** — **already fixed**. `rootPathRed` exists, the menu is built per side
  (`veafCarrierOperations.lua:822`), and RexAttaque had already tested it on the issue.

## The cause is one missing argument

`veafRadio.addSubMenu(title, parent, coalitionSide)` scopes a menu to a coalition, and the renderer
filters on it — `onThisSide` at `veafRadio.lua:435`, `addSubMenuForCoalition` at `:500`. The two
carrier submenus are created **without** it:

```lua
veafCarrierOperations.rootPathBlue = veafRadio.addSubMenu(veaf.t(...RadioMenuNameBlue), rootPath)
veafCarrierOperations.rootPathRed  = veafRadio.addSubMenu(veaf.t(...RadioMenuNameRed),  rootPath)
```

(`veafCarrierOperations.lua:922`). With no side, no filtering — every player sees both.

RexAttaque's own suggestion on the issue is close to this: he asked for a `USAGE_ForCoa` and a
per-menu coalition marker. The mechanism he wanted already exists; it is simply not used here.

## Scope

Small on purpose: pass the side when creating each submenu, and check the sweep — **enumerate** every
`addSubMenu` call in `src/scripts/veaf/` and ask which ones show one coalition's business to the
other. A menu built per side and rendered to everyone is a defect shape, not a one-off, and hand-
picking the ones that look wrong is how a sweep misses cases.

Related but distinct: [`FEAT-ROLE-AWARE-RADIO-MENU`](../FEAT-ROLE-AWARE-RADIO-MENU/PRD.md) is about
*who* sees a menu by role (a game master sees none of these commands at all). This lot is about
*which side* sees it. Landing this one first is fine; landing it in a way that fights the other is
not — the coalition dimension is what that lot will build on.

## Definition of done

- [x] A red player sees only the red carrier submenu, and vice versa
- [x] Every `addSubMenu` call reviewed from an enumeration, with the count of side-scoped menus recorded — **43 sites, 40 business, 1 previously scoped**; see [ticket 01](tickets/01-scope-the-carrier-submenus.md)
- [x] Lua test asserting a coalition-scoped submenu is not rendered for the other side
- [ ] Re-run check 12 of `verify-mission-c` from the red A-10 at Palmyra
- [ ] #87 closed, saying explicitly that the second half was already fixed
