# 02 — Say what a group with no tag does, and look at it in game

Status: 🧑 waiting-human
Type: fix

Depends on [01](01-decide-the-default-from-the-tag.md).

## Documentation

Both `veafCombatZone.md` pages describe `#spawnradius=N` and say nothing about its absence — which was
harmless while the default was dead and is not any more. They need:

- what a group with no tag gets (`DefaultSpawnRadiusForUnits`), and what a static gets (0);
- that `#spawnradius=0` is how you ask for no dispersion;
- that a `#command` object is never scattered;
- a note that this **changes where existing missions' zone groups appear**, since three years of
  missions were built against no dispersion at all.

## In game

The one thing a unit test cannot answer: 50 m of dispersion can drop a unit into scenery — a building,
a treeline, a slope. `verify-mission-a` holds two multi-unit groups at a documented empty-desert anchor,
which is the cheapest place to look.

## Definition of done

- [x] Both language pages state the default, the `0` escape hatch and the `#command` exception
- [x] `poetry run docs-check` passes
- [x] `DCS-SESSION-TODO.md` carries the in-game item
- [ ] Looked at in game: a zone's groups are scattered and nothing lands inside scenery
