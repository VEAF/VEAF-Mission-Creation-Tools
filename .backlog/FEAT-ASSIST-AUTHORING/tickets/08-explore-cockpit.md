# 08 — explore a cockpit, both ways, in a loop

Status: ✅ done — used in a live F-14B(U) on 2026-08-03, and it found a bug worth the whole ticket.

The thing that turned out to be useful during ticket 04's session was not the verification. It was
**the box**: David could not find the hydraulic transfer pump, boxing it answered instantly. That is
the tool a checklist author actually needs, and it is currently buried inside `verify-checklist`.

Two directions, and the second is the valuable one.

| Direction | The author does | The tool answers |
|---|---|---|
| **name → box** | types `pompe de transfert` | resolves it, boxes it in the cockpit, prints element, argument, and each position with its value |
| **move → name** | throws a switch in the cockpit | prints which control that was: element, argument, and the value of the position it just reached |

`move → name` is what unblocks the aircraft the resolver cannot help with. On the A-10C and the
AH-64D, hints name almost no positions and bindings cover almost nothing (7 controls of 478 on the
Apache) — so today an author has no way to write those steps short of reading Lua. Throwing the
switch and being told what it was replaces all of it, and it produces the *measured* value, not an
inferred one.

## Shape

**A loop, not a one-shot.** `Ctrl-C` to leave — an author works through a whole panel in one sitting,
and re-invoking a command per control would make the tool unusable. Each iteration: read, report,
wait for the next thing to happen.

Both directions in one loop if it reads well; a prompt that accepts either a control name or an empty
line ("just move something and I'll tell you") is probably the right shape, but try it before
committing to it.

`move → name` needs every argument of the aircraft's index read at once and compared between polls.
That is one Lua call looping over the arguments in the export environment and returning a table, not
N round trips — the F-16C has 284 controls and the AH-64D 478.

**Never move anything.** Same rule as ticket 04: boxing is all the tool does to a live aircraft.

## The two commands belong together in the TUI

David's point, and it applies beyond this ticket: `resolve-checklist`, `verify-checklist` and this
one form one workflow, and the wizard lists commands flat. `CommandSpec` needs a **group**, and the
selector needs to show its commands under it — an *Assistance* heading holding the three.

Check what the other commands would want as groups while doing it; a single group in a flat list of
twenty is worse than none. Whatever grouping lands, `test_tui.py`'s existing guarantee — every CLI
command has a `CommandSpec` — must keep holding.

## Definition of done

- [x] Both directions in one loop, leaving on `Ctrl-C` without a traceback and taking the box out of
      the cockpit on the way.
- [x] `move → name` reports the **measured** value, so it works on a control whose position nothing
      in the files names — which is the AH-64D's whole cockpit.
- [x] The reading is printed as a step an author can paste.
- [x] `CommandSpec` carries a group, the wizard shows four headings, and the three assistance
      commands sit together. Two tests guard it: an unassigned command would vanish from the menu
      now that the selector iterates groups.
- [x] Documented on the instructor page, next to verification.
- [x] **One real cockpit run**, and it paid for itself immediately. David threw the DFCS stability
      augmentation yaw switch; nothing came back. The control was not in the index at all — the
      element pattern was anchored at column zero and Heatblur declares whole panels inside `if`
      blocks, so **219 of the F-14's 579 controls were missing**. No unit test could have found that:
      they feed the parser lines already flush left. Re-run after the fix, the same switch came back
      named, with argument 2108, a measured value of 1.0, and its position named from the aircraft's
      own bindings.

**Not yet seen by anyone**, and worth one minute next time a cockpit is open:

- the in-game message for an identified control, added after that run at David's request — the loop
  timed out before anything moved;
- the `--control` direction of this command specifically (the boxing itself is proven, ticket 04
  leant on it throughout).
