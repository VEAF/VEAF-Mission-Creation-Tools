# 04 — Document that the shipped dynamic-slot templates are bare

Status: ✅ done 2026-08-16
Type: docs
Files: `doc/mission-maker/GUIDE.md` + `.en.md`

## The measurement

Reported in game: *"les appareils qu'on me propose sont nus (pas de loadout, pas de skin VEAF)"*.

Counted in the built mission, per coalition:

| | |
|---|---|
| templates carrying a loadout | **9** — A-10C_2, F-14B, F-15C, F-15ESE, F-4E, Mirage-F1BE, … |
| templates with **no** loadout | **43** — UH-1H, CH-47F, FA-18C, F-16C, M-2000C, Mi-8MT, Ka-50, Su-25, the SA342s … |
| templates with a named livery | 45 of 52 |

The plumbing is sound, and a one-shot test proved it: an A-10C II taken from a dynamic slot comes
out **armed and painted**. All 52 catalogue entries carry a `linkDynTempl` pointing at their group,
and DCS applies it. A link to an empty template simply yields an empty aircraft.

So this is a **data** gap in `src/defaults/mission-folder/src/dynamic-slot-templates.yaml`, not a
defect in the build.

## David's arbitration

Option 3 of three: **document it**, rather than filling the 43 by hand (deciding an FA-18C's default
loadout for a VEAF mission is a mission-maker call, not a deduction) or regenerating the defaults
from a reference mission.

Both guides now say what a pilot will actually see, name the two families (9 equipped, 43 bare), and
give the one command that replaces the shipped templates with the mission maker's own:

```
veaf-tools.exe content extract-aircraft-groups my-mission.miz --kind dynamic-template
```

The option value was read off `--help` rather than guessed — it is `dynamic-template`, not
`dynamic`, and the first draft of the doc had it wrong.
