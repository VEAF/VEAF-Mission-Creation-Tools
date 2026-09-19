# 01 — The index page, and the shape the others follow

Status: ⬜ ready

Type: docs · Files: `doc/mission-maker/build-messages/README.md` + `.en.md`, `mkdocs.yml`

## What it is

The page a mission maker lands on with a message in hand. It has to do three things and no more:

1. **Say where the message came from** — `build` prints most of them and builds the `.miz` anyway;
   `validate` prints the same checks and exits non-zero. A reader who thinks the build failed when
   it did not will go looking for a `.miz` that is right there.
2. **Route to the family page**, through a table of every covered message.
3. **Say what to do when the message is not here** — 65 of the 98 are not, and pretending otherwise
   is worse than admitting it. Point at `SUPPORT.md`.

## Definition of done

- [ ] Both languages, in the `nav` with `nav_translations`
- [ ] The table lists every message the lot covers, each linking to its explicit anchor
- [ ] States plainly that the list is not exhaustive, and where to go otherwise
- [ ] No version number written by hand; PowerShell examples use `.\veaf-tools.exe`
- [ ] `poetry run docs-check` passes
