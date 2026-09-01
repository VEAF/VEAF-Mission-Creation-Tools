# 01 — Prefix every example, and explain the two shells

Status: ⬜ ready

Type: docs · Files: `doc/**` (28 files, both languages)

## The mechanical half

Every **command line** invoking a shipped executable from a mission folder gets `.\`. Today:

```
grep -rhoE '(^|[^.\/`])veaf-tools\.exe' doc/ --include='*.md' | wc -l   # 118
grep -rho '\.\veaf-tools\.exe' doc/ --include='*.md' | wc -l            # 0
```

**Do not run a blind replace.** Prose that names the file rather than running it must stay as it
is — `the veaf-tools.exe binary`, `place veaf-tools.exe beside your mission`, a path in a tree
diagram. Only what a reader would type gets the prefix.

Cover the other executables too (`veaf-tools-updater.exe`, `ctld-tools.exe`, and anything else run
from a mission folder). The defect is the habit, not the one binary.

## The half that matters more

On pages that **teach** the command line — the tutorial, the concept cards, the getting-started
pages — add a short note: PowerShell is the default shell on Windows, `cmd` behaves differently,
and here is how.

Keep it to what actually bites:

| | PowerShell | `cmd.exe` |
|---|---|---|
| Running a local exe | `.\veaf-tools.exe` (required) | either form |
| Environment variable | `$env:VEAF_LANG = "fr"` | `set VEAF_LANG=fr` |
| Line continuation | backtick `` ` `` | caret `^` |

Say **why** for the first one — PowerShell does not search the current directory, on purpose —
because that is the line that turns a baffling error into an obvious one.

## Definition of done

- [ ] The count of bare `veaf-tools.exe` command lines in `doc/` is zero
- [ ] Prose mentions are untouched — spot-check a few, a blind replace is the risk here
- [ ] Other shipped executables get the same treatment
- [ ] The teaching pages carry the two-shell note, in both languages
- [ ] `poetry run docs-check` passes
