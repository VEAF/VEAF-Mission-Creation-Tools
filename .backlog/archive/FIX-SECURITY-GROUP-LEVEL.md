# FIX-SECURITY-GROUP-LEVEL — every secured `+` radio command is refused to everybody, because `Group.getByID` does not exist

Status: ✅ done — merged in #1120; seen in game on `private1` on 2026-10-10, closed by David · archived 2026-11-24

## Verified

2026-10-10, `private1`: *Kolkhida* mission 2 rebuilt with `6.28.1-kolkhida9+2eaf7925` and loaded at 12:48 UTC; David (level 99) clicked *+Escort me (fox3)* and the escort came.
The refusal of an unlisted pilot and the answer to `/secu elevate` were not run; David closed the lot on that check.

## Found

David and Claude, 2026-10-10, on `private1` (dcs.veaf.org), *Kolkhida* mission 2 built from `develop` (`6.28.1-kolkhida8+d6ae1ea1`), security on (no `security: disabled`).
David, listed at level 99 in `veaf-pilots.txt`, clicked *F10 → VEAF → SPAWN → +Escort me (fox3)* from a blue dynamic slot at Batumi, then from `Stennis Hornet-1` (a placed slot): both times *"Cette commande « + » demande le niveau 1 ; votre groupe agit au niveau 0 (le plus bas de ses pilotes)"*.

Measured in the running mission through the hook's `/code` (each line read back in the server's `dcs.log`):

| Probe | Result |
|---|---|
| `coalition.getPlayers(2)` unit names | `Stennis Hornet-1` |
| keys of `veafRemote.remoteUnitsPilots` | `Stennis Hornet-1` |
| `veafRemote.remoteUsers['ninja 1-1 \| zip'].unitName` | `Stennis Hornet-1` |
| `veafRemote.remoteUnitsPilots['Stennis Hornet-1'].level` | `99` |
| `Group.getByID` | **`nil`** |

The hook (`VEAF-Server-hook.lua`, identical on all six servers to `develop`) and `veafRemote` do their job: the mission knows the pilot, his unit and his level.

## Cause

`veafSecurity.getGroupOccupantUnitNames` resolves the group with `Group.getByID and Group.getByID(groupId)`.
`Group.getByID` is **not** part of the DCS scripting API (only `Group.getByName`; vendored `CTLD.lua` says as much at line 6982).
The guard turns the missing function into an empty occupant list, `getGroupLevel` returns 0 for an empty group, and `veafRadio._proxyMethod` refuses.
So since 6.14.0 (#676, 2026-08-09) **every secured `+` radio command is refused to every pilot on every server whose mission runs with security on** — Open Training, Foothold and the campaign alike — whatever `veaf-pilots.txt` says.

Nothing caught it: `test_veafSecurity.lua` replaces `getGroupOccupantUnitNames` with a stub, so the function that calls the missing API never runs in a test.
*Kolkhida* mission 1 flew with `security: disabled`, and R38 (`DCS-SESSION-TODO.md`, lot `FIX-SECU-VERB-AND-LOG-NOISE`) was never run on a server.

Next to it: `/secu elevate`, which the refusal message tells the pilot to type, answered *unknown command* — the mission's `mission.yaml` (a campaign template scaffolded with `mission_template.py`) has `# SECURITY: true` commented out, so `veafSecurity.initialize` never registers the `secu` remote module, while the per-group check in `veafRadio` applies anyway.

## Tickets

| # | Ticket | Status |
|---|---|---|
| [01](FIX-SECURITY-GROUP-LEVEL.md) | Find a group's human occupants without `Group.getByID` | ✅ |
| [02](FIX-SECURITY-GROUP-LEVEL.md) | `/secu elevate` exists whenever the refusal tells a pilot to type it | ✅ |

## Definition of done

- Lua tests: the occupant lookup runs against a DCS mock **without** `Group.getByID`, and fails on today's code.
- `known-limitations.yaml`: `Group.getByID` does not exist (`kind: dcs`, measured 2026-10-10) and the defect itself (`kind: tool`, `fixed_in` the coming release); `dcs-runtime-traps.md` regenerated.
- `veafSecurity` doc page (FR + EN) still true; `CHANGELOG.md` entry.
- In game, on a server: a listed pilot clicks a `+` command from a dynamic slot and from a placed slot and it runs; an unlisted one is refused; `/secu elevate` answers. That closes R38 too.
- *Kolkhida* mission 2 rebuilt with the fix before 2026-10-15; otherwise rebuilt with `security: disabled` as mission 1 was.

## Tickets, in full

## 01 — Find a group's human occupants without `Group.getByID`

Status: ✅ done

- `veafSecurity.getGroupOccupantUnitNames(groupId)` scans the players instead: `coalition.getPlayers(side)` for each coalition, keeping the units whose `getGroup():getID()` is `groupId`.
  These are exactly the "slots with a human in them" the function means, so the AI-wingman rule in its comment still holds by construction.
- Search the Lua tree for any other call to an API DCS does not have in the same guarded shape (`X.getByID and X.getByID(...)`): a guard on a function that never exists is a permanent `nil`.
- Tests in `test_veafSecurity.lua`, against the mocks, with **no** `Group.getByID` defined:
  - a level-99 pilot alone in a group → the group is level 99, and a `+` command through `veafRadio._proxyMethod` runs;
  - a level-99 and an unlisted pilot in the same group → the lowest wins;
  - a pilot in **another** group with the same unit count → not counted;
  - no human in the group → 0, refused.
  The first case fails on today's code: that is the regression test.

## 02 — `/secu elevate` exists whenever the refusal tells a pilot to type it

Status: ✅ done

The per-group check in `veafRadio._proxyMethod` applies whenever `veaf.SecurityDisabled` is false, whether or not `SECURITY` is listed in `mission.yaml`; the `/secu` verbs exist only when it is.
`mission_template.py` writes `# SECURITY: true` commented out ("uncomment + add password_hashes … to require a password"), the shipped default `src/defaults/mission-folder/mission.yaml` has it on — so a mission scaffolded from the template refuses with a message pointing to a command it does not have.

Recommended (Claude, 2026-10-10): register the `secu` remote module and the marker handler regardless of the `SECURITY` entry — the check they belong to is not optional, so their verbs should not be — and reword the template's comment, which describes passwords rather than the module.
The alternative, wording the refusal differently when `SECURITY` is off, keeps two behaviours for one check; it is the fallback if making the module mandatory breaks a mission that relies on turning it off.

- Lua test: with `SECURITY` absent from the config, `/secu elevate` from the remote path reaches `veafSecurity.executeCommandFromRemote`.
- Defaults lockstep (`CLAUDE.md` §9.7): `mission_template.py` and `src/defaults/mission-folder/mission.yaml` say the same thing.
