# 07 — document it for instructors

Status: ✅ done.

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

- [x] An instructor gets from a blank file to a working checklist by reading one section
      (*Sans connaître les noms techniques*), which now comes **before** anything technical.
- [x] The technical fields moved under a *Référence du format* heading, introduced as something you
      do not need in order to write a checklist.
- [x] A section on choosing the validation mode, leading with the multiplayer rule: `argument` for
      solo and local training, `param` and `confirm` for a mission meant for the server. The caveat
      used to be repeated in two places and now lives in one.
- [x] *Trouver l'élément à encadrer* leads with the resolver and keeps the manual route for an
      aircraft nobody has indexed — plus the command to index it.
- [x] Corrected while restructuring: the page claimed a position's value is read from
      `clickable_defs.lua`'s `arg_lim`. That gives the *window*, not which position is which value;
      the input bindings give that, and the page now says so.
- [x] The exploration note takes sections 8 to 10: the bindings as the source of a position's value,
      the four `clickabledata.lua` dialects with what each costs if unhandled, and the unit catalogue
      lagging behind the store.
- [x] `CHANGELOG.md` entry, patch bump with `plugin.json` in sync.
