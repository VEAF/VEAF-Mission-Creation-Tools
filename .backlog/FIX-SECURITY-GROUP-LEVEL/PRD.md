# FIX-SECURITY-GROUP-LEVEL — every secured `+` radio command is refused to everybody, because `Group.getByID` does not exist

Status: ⬜ ready

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
| [01](tickets/01-group-occupants-without-getbyid.md) | Find a group's human occupants without `Group.getByID` | ⬜ |
| [02](tickets/02-secu-verbs-exist-when-security-applies.md) | `/secu elevate` exists whenever the refusal tells a pilot to type it | ⬜ |

## Definition of done

- Lua tests: the occupant lookup runs against a DCS mock **without** `Group.getByID`, and fails on today's code.
- `known-limitations.yaml`: `Group.getByID` does not exist (`kind: dcs`, measured 2026-10-10) and the defect itself (`kind: tool`, `fixed_in` the coming release); `dcs-runtime-traps.md` regenerated.
- `veafSecurity` doc page (FR + EN) still true; `CHANGELOG.md` entry.
- In game, on a server: a listed pilot clicks a `+` command from a dynamic slot and from a placed slot and it runs; an unlisted one is refused; `/secu elevate` answers. That closes R38 too.
- *Kolkhida* mission 2 rebuilt with the fix before 2026-10-15; otherwise rebuilt with `security: disabled` as mission 1 was.
