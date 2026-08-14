# 03 — The pages that quote the old labels

Status: ✅ done 2026-08-13 — every page quotes its own language's labels; the French pages also named five root menus in English
Type: docs
Files: `doc/pilot/GUIDE.{md,en.md}`, `doc/mission-maker/scripts/veafCombatMission.{md,en.md}`, and any
other page quoting a menu label

## Why this ticket exists

`DOC-MODULE-PAGES` corrected the pilot guide **to the English labels**, because that is what the game
showed, and added a note explaining why they were English. This lot makes that note false and those
labels wrong on a French server.

Each page must quote the labels **of its own language**, and the note explaining the English-only
labels goes away — replaced by one line saying the menu follows `mission.language`.

## Inventory to redo rather than trust

The 9 French and 8 English menu paths corrected in `DOC-MODULE-PAGES`, plus
`veafCombatMission`'s F10 table in both languages, plus whatever a fresh grep for the old labels
turns up. Enumerate; the previous pass found more sites than its own ticket predicted.

## Acceptance criteria

- [ ] No page quotes a label the game no longer shows, in either language.
- [ ] The "labels are in English" notes are gone.
- [ ] `docs-check` green.
