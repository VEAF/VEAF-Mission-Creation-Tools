# 01 — Scope the two carrier submenus, and sweep the family from an enumeration

Status: ✅ done
Type: fix

Closes [#87](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/87). Confirmed in DCS by David
on 2026-08-18 from a red A-10 at Palmyra.

## The fix

`veafRadio.addSubMenu(title, parent, coalitionSide)` scopes a menu to a coalition and the renderer
filters on it. The two per-side carrier menus were created **without** the third argument, so there was
nothing to filter on and every player saw both. One argument each
([`veafCarrierOperations.lua:922-923`](../../../src/scripts/veaf/veafCarrierOperations.lua:922)).

Each carrier's own submenu hangs under one of those two
([`:836`](../../../src/scripts/veaf/veafCarrierOperations.lua:836)) and a scoped node scopes everything
below it, so that is the only place the side has to be stated. The shared **CARRIER OPS** root stays
global on purpose: it carries the help command, and scoping it would hide both sides from everybody.

## The sweep, enumerated

The PRD asked for an enumeration rather than a hand-picked list, and for the count to be recorded.
**43 `addSubMenu` call sites** in `src/scripts/veaf/`; 3 are `missionCommands.addSubMenu` inside
`veafRadio` itself (the DCS projection, not a caller), leaving **40 business call sites**. Exactly
**one** already passed a coalition before this lot:
[`veafCombatZone.lua:1439`](../../../src/scripts/veaf/veafCombatZone.lua:1439) (`FEAT-COMBATZONE-MENU-COALITION`).

The question asked of each: *is this menu built per side while being rendered to everyone?*

| Module | Sites | Verdict |
|---|---|---|
| `veafCarrierOperations` | 921, 922, 923, 836 | **the defect.** 922/923 are built per side — fixed. 921 is the shared root, global on purpose. 836 inherits. |
| `veafCombatZone` | 1439 | already scoped |
| `veafCombatZone` | 2203, 2207, 2248 | global **on purpose** — the "COMBAT ZONES" / "OPERATIONS" roots and the radio-group groupings hold zones of both sides, each scoped individually at 1439 |
| `veafCombatZone` | 1933 | combat *operation* menu; no per-side construction |
| `veafAssets`, `veafCombatMission`, `veafMissileGuardian`, `veafTransportMission` | 6 sites | not concerned — **zero** occurrences of `coalition` / `.side` in the whole module, so nothing is built per side |
| `veafCasMission` | 1057, 1234 | not concerned — its 26 coalition references are mission logic, not menu construction |
| `veafMove` | 1018, 1034, 1038 | not built per side — see the finding below |
| `veafSpawnCore`, `veafWeather`, `veafNamedPoints`, `veafAssist` | 11 sites | global actions, no per-side construction |

## Two things checked that turned out fine — recorded so nobody re-checks them

**Scope inheritance is transitive.** `_buildSubtree` reads `parentNode.coalition`, which looks like it
would only descend one generation. It does not: the recursion passes the **effective** side down through
a synthetic parent node ([`veafRadio.lua:558`](../../../src/scripts/veaf/veafRadio.lua:558)). Verified by
reading, then pinned with a three-generation test, since this fix depends on it and
`FEAT-ROLE-AWARE-RADIO-MENU` will build on the same dimension.

**Pagination already scopes its overflow pages**
([`veafRadio.lua:541-545`](../../../src/scripts/veaf/veafRadio.lua:541)). A scoped menu that spills past
`MENU_PAGE_SIZE` does not leak its extra pages to the world.

`veafRadio.refreshRadioSubmenu` **would** lose the scope, since it takes a caller-supplied parent whose
declared `coalition` may be nil. It has **no callers anywhere** — dead code. Left alone rather than
fixed, and named here so the next reader knows it was looked at.

## One finding outside this lot, stated rather than quietly dropped

`veafMove` lists the mission's tankers in a single global menu (`1034`/`1038`), so a red pilot can move a
blue tanker. That is a *different* shape from #87 — a global menu exposing one side's objects, not a
per-side menu rendered to all — it was never reported or measured, and fixing it needs a coalition on
assets first: `veafAssets` has **no** notion of coalition at all (zero occurrences). So it is a lot of
its own, not a line in this one.

## Definition of done

- [x] A red player sees only the red carrier submenu, and vice versa
- [x] Every `addSubMenu` call reviewed from an enumeration, with the count recorded (43 sites, 40
      business, 1 previously scoped)
- [x] Lua test asserting a coalition-scoped submenu is not rendered for the other side — plus the
      three-generation inheritance test the fix relies on. Mutation-checked: removing the two
      coalition arguments fails two tests.
- [ ] Re-run check 12 of `verify-mission-c` from the red A-10 at Palmyra
- [ ] #87 closed, saying explicitly that the second half was already fixed
