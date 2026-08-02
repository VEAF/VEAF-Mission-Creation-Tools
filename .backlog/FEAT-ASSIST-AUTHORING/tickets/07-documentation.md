# 07 — document it for instructors

**Status:** ⬜ ready — depends on 05, 06.

[`veafAssist.md`](../../../doc/mission-maker/scripts/veafAssist.md) documents the technical format.
This lot exists so an instructor never has to read that section — the page has to reflect that, not
bolt the easy way onto the end of the hard way.

## Restructure the page

**Write a checklist** becomes the instructor path: `label` + `control`, run the resolver, done. The
technical fields move to a **Reference** section, for whoever reads a resolved file or writes a step
the resolver refuses.

Say plainly:

- what a good `control` text looks like — name the control as the cockpit labels it, then the
  position: `throttle sur idle`, not `mettre les gaz`;
- that the resolver refuses rather than guesses, and that a refusal is information, not a failure;
- that re-running is safe and only touches what changed;
- **the multiplayer rule**: `argument` for solo and local training, `param` and `confirm` for a
  mission meant for the server.

Both languages, `docs-check` clean.

## Also

- The developer guide gets the index generator (ticket 01).
- The exploration note takes whatever the F-14B(U) and the other aircraft teach about cockpit data —
  it is already the home for that.

## Definition of done

- An instructor gets from a blank file to a working checklist by reading one section.
- `CHANGELOG.md` entry, patch bump with `plugin.json` in sync.
