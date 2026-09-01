# veaf-logs — reading DCS logs

`veaf-logs` opens a DCS log and shows only what matters. It knows the VEAF, CTLD,
CSAR, AIEN and Skynet scripts, recognises Eagle Dynamics' harmless errors, and
follows the file live while the mission runs.

## Running it

From the executable shipped with the release:

```
.\veaf-logs.exe
```

With no argument it reopens the last session's files, falling back to the current
`dcs.log` (`Saved Games\DCS\Logs\dcs.log`). You can also pass it a path, or drop a
file onto it.

From the sources:

```
poetry install --all-extras
poetry run veaf-logs
```

The window needs PySide6, declared as an optional dependency (`--all-extras`, or
`--extras logs`). Nothing else in `veaf-tools` requires it.

## The three states

Every level, source and noise family cycles through three states on click:

| | |
|---|---|
| ✓ | shown |
| ◐ | **context** — shown only around a kept line |
| ✕ | hidden |

Context mode is what makes a log readable. Setting `INFO` to ◐ with ±3 lines
keeps only errors and warnings, surrounded by what explains them. Each category
can have its own span: the `±` field appears beside it as soon as it switches to
◐, and leaving that field empty falls back to the shared value set at the top of
the panel.

Dropping the ED noise changes the scale of what is left to read:

| Log | Severe lines | Shown |
|---|---|---|
| One session `dcs.log` | 416 | **34** |
| That `dcs.log` and four archived logs | 2,714 | **278** |

"Severe" means level `ERROR`, `ERROR_ONCE` or `ALERT`. A log grows while the game
runs, so counts taken on another day differ by a few lines.

## Profiles

The dropdown at the top holds a complete filter set — category states, search
criteria, context spans. Three profiles ship with the tool:

- **Tout** — no filter at all, the way out when you have lost yourself;
- **Lecture** — ED noise hidden;
- **Diagnostic** — errors and warnings, with three lines of context.

`Enregistrer…` saves a profile; the shipped ones can be neither edited nor
deleted. As soon as a filter changes, the dropdown falls back to "Session
courante": a saved profile never moves unless you ask it to.

## Search

Three modes, chosen from the dropdown:

| Mode | `.` | `*` `?` | Example |
|---|---|---|---|
| Texte | literal | literal | `CSAR.lua` |
| Jokers | literal | wildcards | `No taxiroad*Batumi*` |
| Regex | wildcard | quantifiers | `VEAF\|[WE]\|` |

`≠` inverts the criterion, `Aa` makes it case-sensitive. **Ajouter au filtre**
stacks the current criterion: filters combine, and show up as chips you can
remove with one click.

Search covers the line **and** the stack trace under it: looking for a symbol
that only appears in the trace brings back the error that produced it.

## What it understands of the log

**Stack traces stay with their error.** A `Mission script error` followed by its
`stack traceback` forms a single entry, so filtering on errors no longer hides
the explanation. The line then carries a `[+3]` marker, and the detail shows at
the bottom when you select it.

**The level shown is the real one.** DCS logs all Lua as `INFO SCRIPTING`,
including a `VEAF|W|` that is a warning. `veaf-logs` reads it from the prefix:
filtering on WARNING does bring up VEAF, CTLD and CSAR warnings.

**Archives open directly.** The `.zip` files in `Saved Games\DCS\Logs` also carry
the memory dump, the mission and the dxdiag report: the log is picked for you.

**The log is never locked.** On Windows a file held open cannot be renamed — and
that is exactly what DCS does to its `dcs.log` on every launch. `veaf-logs` opens
and closes on each read, so it never keeps the game from starting.

## Large logs

The text is not held in memory: only a compact index is, and lines are decoded as
they are displayed. On a 119 MB server log (991,392 lines):

| | |
|---|---|
| First lines readable | 0.3 s |
| Full indexing | 8.6 s, in the background |
| Memory | 37 MB |
| Search | 0.65 s |

Indexing carries on while you read and filter; a progress bar shows up with a
button to stop it — whatever is already indexed stays usable.

## Shortcuts

| | |
|---|---|
| `Ctrl+D` | open the current `dcs.log` |
| `Ctrl+O` | open a file |
| `Ctrl+W` | close the tab |
| `Ctrl+F` | search |
| `F` | follow the end of the file / pause |
| `Ctrl+R` | show everything |
| `Ctrl+S` | save the profile |
| `F5` | reload the rule catalogue |

## Adding your own rules

Recognised sources, colours and noise families all live in one file,
`veaf_logs/rules.json`, which the **Règles** menu opens and reloads (`F5`)
without leaving the application.

A script of your own takes one entry:

```json
{
  "id": "monscript",
  "label": "MonScript",
  "color": "#ff8800",
  "match": "^MONSCRIPT\\|(?P<lvl>[A-Z])\\|",
  "level_group": "lvl",
  "level_map": {"D": "DEBUG", "I": "INFO", "W": "WARNING", "E": "ERROR"}
}
```

A noise family to drop:

```json
{
  "id": "mon_bruit",
  "label": "Short label shown",
  "help": "Sentence shown as a tooltip.",
  "default_hidden": true,
  "match": "the pattern to hide",
  "regex": true
}
```

Patterns are matched against bytes to keep indexing fast, so they must stay
ASCII. The number of noise families is capped at 64.

## Where the settings live

| | |
|---|---|
| Session (open files, filters, geometry) | `%APPDATA%\veaf-logs\session.json` |
| Profiles | `%APPDATA%\veaf-logs\profiles.json` |
