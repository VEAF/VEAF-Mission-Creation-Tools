# 02 — A usage class for unattached commands, and the per-role policy

Status: 🚫 wontfix

Cancelled with the lot on 2026-08-20 — the policy it would have decided has nowhere to live: a secured command cannot identify a game master on the F10 channel, and an unsecured one would hand the mission to whoever takes the slot. See the
[PRD](../PRD.md) for the two walls, and
[`docs/exploration/DCS-UNATTACHED-PLAYER-ROLES.md`](../../../docs/exploration/DCS-UNATTACHED-PLAYER-ROLES.md)
for the measurements behind them.
Type: feat (design + declaration)
Files: `src/scripts/veaf/veafRadio.lua`, every module declaring commands, the mission-maker docs
(both languages), tests

Depends on [01](01-measure-what-a-game-master-is.md).

## The decision this ticket makes

Today a command declares one of three usages: `USAGE_ForAll` (rendered once, globally),
`USAGE_ForGroup` (rendered per human group, handler gets a `unitName`), `USAGE_ForUnit` (per unit).
The split conflates two independent things:

- **who may see it**, and
- **whether it needs a caller's unit to do its work**.

`ForAll` happens to mean both "everyone sees it" and "no unit needed"; `ForGroup` means both "pilots
only" and "needs a unit". A game master needs the combination the vocabulary cannot express: *seen by
someone with no unit, and able to run without one*.

Rather than a fourth flag bolted on, prefer making the two dimensions explicit — an **audience** and
a **needs-a-caller** property — with the three existing constants kept as the shorthands they are, so
no existing declaration changes meaning. Whatever shape is chosen, write the reasoning down: this
vocabulary is what every module and every mission maker uses.

## Classifying the existing commands

The rule has to be applied, not just defined. Sweep every `addCommandToSubmenu` /
`addCommandToMenu` call in `src/scripts/veaf/` and classify each — enumerate them from the code, do
not sample: a family of commands hand-picked from memory is how a sweep misses the third of its
cases. First read, to be checked:

- **Runs unattached** (global effect): combat-zone activate/deactivate, QRA start/stop, carrier
  operations, IADS status, weather, named points, most of `veafRemote`
- **Needs a caller**: anything answering "your group"/"your aircraft" — guided checklists, rearm and
  refuel, unit info, CTLD's transport actions, anything reading the caller's position

The uncertain middle — a command that *can* work unattached but whose message is written as if to a
pilot — is the interesting part, and the count of those belongs in this ticket's result.

## Security

`veafSecurity` gates on the caller. An unattached command has no caller to gate on, and a game master
is simultaneously the most privileged and the least identified participant. Decide explicitly whether
the unattached path is trusted, gated by role, or refused for secured commands — and record it. A
security decision made by omission is the failure mode this project has already paid for once
(SECREV-2, `veaf.SecurityDisabled`).

## Done when

- The usage vocabulary is extended (or restated) with the reasoning written in this ticket
- Every existing command is classified, from an enumeration of the call sites, and the counts recorded
- The security stance for unattached commands is explicit, with a test
- Existing pilot-facing behaviour is byte-for-byte unchanged, asserted by test
