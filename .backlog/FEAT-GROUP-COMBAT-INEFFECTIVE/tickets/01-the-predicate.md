# 01 — The predicate, table-driven with a DCS-attribute default

Status: ✅ done
Type: feat

`veaf.isGroupCombatEffective(groupOrName)` — is this group still a problem?

## The table, from the issue body

```lua
[".*s300.*"] = {
  minimumLife = 80,
  importantSets = {
    TR = { "S-300PS 40B6M tr" },
    SR = { "S-300PS 40B6MD sr", "S-300PS 64H6E sr" },
    CP = { "S-300PS 54K6 cp" },
  },
}
```

A group whose name matches the pattern is effective only while **every declared set** still has a
living member above `minimumLife`. One empty set finishes the group: an S-300 with no tracking radar
has launchers and crew and cannot engage.

`minimumLife` is a **percentage**, compared through the existing `veaf.getUnitLifeRelative` (which
returns a 0..1 ratio). Reading it as absolute hit points would mean a different threshold per unit
type, which no mission maker can reason about.

## The default, and the honest limit

Attributes come from `dcsUnits.DcsUnitsDatabase[type].attribute` — the repository's own generated
database, keyed by type — not from `Unit.getDesc()`. Same data, no DCS call, and testable.

Default rule: a group carrying a living `SAM LL` or `SAM SR` unit **is** a SAM site, and is finished
once no living unit carries `SAM TR`. Anything else is effective while anything of it lives.

**The limit, stated rather than hidden:** dead units vanish from `Group:getUnits()`, so the predicate
cannot know a group *had* a radar it has since lost. The pattern table carries that knowledge — a
pattern asserts the group owns those sets. The default cannot, so a SAM site stripped of *both* its
radars and its launchers reads as an ordinary group; by then nothing dangerous is left of it anyway.

## Definition of done

- [x] The predicate exists, table-driven, with the attribute default
- [x] Lua tests on a partially destroyed S-300: no TR, no SR, TR below minimumLife, all present
- [x] Tests on the default: a SAM site losing its TR, a Tunguska (its launcher *is* the TR), a convoy
- [x] An empty or unknown group answers false rather than raising
