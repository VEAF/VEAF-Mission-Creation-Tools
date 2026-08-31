# 01 — State the prefix rule, and unflag the tutorial

Status: ⬜ ready

Type: docs · Files: `doc/mission-maker/scripts/veafCombatZone.md` + `.en.md`,
`doc/mission-maker/concepts/` and `TUTORIAL.md` (both languages)

## What to write

The rule, plainly, where someone meets combat zones for the first time: **a group is part of a zone
only if its name starts with the zone's name** (case-insensitive). Being inside the trigger zone is
not enough.

Make it concrete — a zone named `CZ-Alpha`, groups `CZ-Alpha-ARMOR`, `CZ-Alpha-AAA`, and a
counter-example named `ARMOR-1` that is silently ignored. The counter-example is the useful half:
it is the mistake a newcomer makes, and it produces no error anywhere.

Then check every existing example on those pages: each must either name its zone or be written so
its prefix is visibly the zone name. `SPAWN-SA11` under the `#command` heading is the one most
likely to mislead.

## Unflag the tutorial

`DOC-TUTORIAL` wrote "target behaviour" call-outs for `#spawnchance` and dynamic-slot stock while
those lots were in flight. Both have landed — #859 (the probability is honoured; the forced draw
survives only under an explicit `#spawncount`) and #860 (stock is filtered to what the terrain can
park). Turn the call-outs into plain present-tense statements and drop the flags.

## Definition of done

- [ ] The rule appears on both combat-zone pages, both languages, with the counter-example
- [ ] The tutorial and the concept card for combat zones state it too, since that is where a
      beginner lands
- [ ] Every example on those pages is consistent with the rule
- [ ] No "target behaviour" flag remains for the two landed lots
- [ ] `poetry run docs-check` passes
