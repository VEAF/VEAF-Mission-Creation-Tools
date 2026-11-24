# FEAT-SPAWN-OWNERSHIP-DESPAWN — Each pilot can remove what he spawned, from the F10 menu

Status: ✅ done · archived 2026-11-24

David, 2026-11-10, while correcting the Open Training conduct sheet (FEAT-OPEN-TRAINING-KNEEBOARD): "it would be good to remember, per pilot, the things he spawned (except combat zones, which handle that very well) so that he can despawn them from the radio menu".

## The need

On an Open Training, a pilot drops markers (`-sa6`, `-armor`, `-cas`, `-convoy`, `-farp`…) and leaves; what he spawned stays for the whole server.
The only way to remove it today is `-destroy`, which takes a trusted-member level and works within 100 m of a marker — most pilots cannot use it, and nobody knows where everything is.
The conduct sheet now asks pilots to clean *their* combat zones by deactivating them; spawned groups need the same.

## What the lot delivers

- The runtime remembers, for each pilot, the groups his marker commands spawned — the marker's author is what identifies him, as the security layer already does.
- An F10 entry lets him remove them: all of them at once, and each one by name.
- Combat zones are **out of scope**: they already spawn and clean their own groups.

## Questions to settle before coding (reco for each)

| # | Question | Reco |
|---|---|---|
| Q1 | What is recorded | Every group created from a marker command (alias or raw `_spawn`, `_cas`, convoy, FARP/FOB…), not those a script or a combat zone / combat mission spawns |
| Q2 | Who is "the pilot" | The marker's author (player name), not his slot: he keeps his list across slot changes |
| Q3 | Where the menu lives | Under the group's F10 menu, listing the owner's items; one entry "remove all", one per item (named by what he typed, e.g. `-sa6`, and its time) |
| Q4 | Multi-seat aircraft | The F10 menu cannot tell which occupant clicked (`security` doc): show the items of every occupant of the group, each under his name |
| Q5 | When the pilot leaves | Keep the items (someone else may be using the target) — the pilot cleans before leaving, as the conduct sheet says; no automatic removal in this lot |
| Q6 | Who else may remove them | Nobody through this menu; `-destroy` stays for trusted members |
| Q7 | Security tier of the removal | Open: a pilot may always remove what he made himself |
| Q8 | Units already destroyed | Drop a group from the list when it no longer exists; a partly destroyed group is removed whole |

## Tickets

| # | Ticket | Status |
|---|---|---|
| 01 | [Record each marker-spawned group with its author](FEAT-SPAWN-OWNERSHIP-DESPAWN.md) | ✅ |
| 02 | [F10 menu: list and remove one's own items](FEAT-SPAWN-OWNERSHIP-DESPAWN.md) | ✅ |
| 03 | [Pilot guide, OT commands/conduct sheets, CHANGELOG, demo mission step](FEAT-SPAWN-OWNERSHIP-DESPAWN.md) | ✅ |

Lua runtime (`src/scripts/veaf/`), luaunit tests with the DCS mocks; read `docs/agents/dcs-runtime-traps.md` and the F10 menu id recycling trap before rebuilding a menu.
One branch, one PR.

## Tickets, in full

## 01 — Record each marker-spawned group with its author

Status: ✅ done

### Done when

- A group created from a marker command is recorded under the marker's author (PRD Q1, Q2); a group spawned by a script, a combat zone or a combat mission is not (tests).
- A group that no longer exists drops out of its owner's list (Q8, test).

## 02 — F10 menu: list and remove one's own items

Status: ✅ done

### Done when

- The group's F10 menu shows its occupants' items, each under its owner's name, with "remove all" and one entry per item (PRD Q3, Q4).
- Removing is open to the owner and to nobody else through this menu (Q6, Q7); a partly destroyed group is removed whole (Q8).
- The menu changes only what changed: DCS recycles menu ids (tests with the mocks).

## 03 — Pilot guide, OT sheets, CHANGELOG, demo step

Status: ✅ done

### Done when

- The pilot guide (FR/EN) explains the menu; the Open Training conduct and commands sheets (OT prompt) mention it; `docs-check` passes.
- `CHANGELOG.md` has its entry; the demo mission gets its step (CLAUDE.md §9 item 9).
