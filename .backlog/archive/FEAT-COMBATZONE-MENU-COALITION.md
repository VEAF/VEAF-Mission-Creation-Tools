# Lot FEAT-COMBATZONE-MENU-COALITION — a combat zone's F10 menu is shown to its own side only

Status: ✅ done — **the in-game gate came back positive 2026-08-06**, answered by the smoke harness
rather than by a person.

**Branch**: `feature/FEAT-COMBATZONE-MENU-COALITION` → [#641](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/641) → `develop`

| # | Ticket | Status |
|---|--------|--------|
| 01 | Coalition-scoped menu | ✅ |

## Problem

Every combat zone's F10 submenu was global: both coalitions saw every zone. That menu is not
read-only — it is how a zone gets **activated**, its smoke popped, its info requested. So with
red-side zones possible (`FEAT-COMBATZONE-RED-SIDE`), a blue player could see and trigger the red
side's zones, and vice versa.

## Solution

DCS supports this natively (`missionCommands.addSubMenuForCoalition` / `addCommandForCoalition` /
`removeItemForCoalition`), so no per-group duplication is needed. The gap was that `veafRadio`'s menu
builder only ever called the global and per-group variants.

**1. `veafRadio` gained coalition-scoped nodes.** `addSubMenu(title, parent, coalitionSide)` records
the side on the logical node and `RadioMenuBuilder` renders that subtree with the `ForCoalition` API.
The side is **inherited** by everything below — child submenus, commands, and the render-time
pagination pages (ADR 0013) — otherwise a global child would sit under a coalition-scoped parent,
which DCS has no coherent meaning for.

A `USAGE_ForGroup` / `USAGE_ForUnit` command inside a restricted subtree is emitted only for human
groups of that coalition; without this, DCS would be asked to attach a per-group command under a path
that group cannot see. This required `veafRadio.humanGroups` to record each group's coalition, which it
did not.

`rebuild()` also had to remove the scoped nodes explicitly: it only ever called the global `removeItem`
on the root, and the menu is rebuilt on every birth event — so anything the global removal did not
reach would accumulate **a duplicate menu per player join**.

**2. Each zone defaults to its own side**, `getFriendlyCoalition()` — the opposite of
`enemy_coalition`. `radio_menu_coalition: RED | BLUE | ALL` overrides it, with `ALL` restoring the
global menu (for an umpire in a red slot who must trigger a blue zone).

This **changes the behaviour of existing missions**: a zone with no `enemy_coalition` now shows its
menu to blue only. Chosen deliberately by David over the two alternatives — on a mission where both
sides are played, deducing it is what is wanted, and requiring the key on every zone would be noise.
Missions whose player slots are all blue see no difference.

## The gate, and what answering it cost

Open since July on one question: **does DCS accept a coalition-scoped submenu under a global parent?**
`veafRadio` inherits the side down a subtree, so if DCS refused the nesting the whole feature was built
on sand — and no unit test could tell, because the mocks pin *which API is called*, not DCS's reaction.

`FEAT-DCS-SMOKE-HARNESS` asked it inside a running mission:

```
coalition-scoped-submenu-accepted: returned 'created'
```

**DCS accepts it.** The prepared fallback — scoping the `COMBAT ZONES` parent per coalition too —
is not needed and stays on the shelf. The parent stays global on purpose: a `radio_group_name` submenu
may hold zones of both sides, so a side can see the `COMBAT ZONES` entry without the other's zones
under it.

**Two honesty notes on the scope of that answer**, both worth keeping:

- It establishes **acceptance** — DCS neither raised nor handed back nil — and *not* that the menu is
  displayed to blue alone. That half is `veafRadio`'s own logic, which the unit tests cover.
- Getting the answer took **two repairs to the check itself**. It first returned a constant whenever
  `pcall` did not raise, so a nil would have read as a pass and unblocked this lot **in the wrong
  direction**; then it returned a boolean, which that transport destroys, leaving it silent on the very
  question it existed to settle. The verdict is a word now.

## Testing decisions

- `veafRadio`: a node with a side renders through `addSubMenuForCoalition`; children and pagination
  pages inherit it; a `ForGroup` command reaches only that coalition's groups; a node without a side
  still uses the global API (regression guard); `rebuild` removes scoped nodes.
- `veafCombatZone`: the menu side defaults to the friendly coalition, follows `enemy_coalition`, and
  `ALL` makes it global again.
- Python: `radio_menu_coalition` emits the setter, is case-insensitive, rejects an unknown value, and
  emits nothing when absent.
- DCS mocks gained the three `ForCoalition` entries (the `dcs-mock-coverage` CI job).

## Out of scope

- Scoping the `COMBAT ZONES` root or the `radio_group_name` submenu (see above).
- Other modules' menus (QRA, AirWaves…): they already have a per-group restriction and nobody asked
  for a coalition one.
