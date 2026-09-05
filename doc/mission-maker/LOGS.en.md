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
◐, and leaving that field empty falls back to the **Contexte des catégories**
value set at the top of the panel.

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

### Context lines {#search-context}

A hit on its own says little; what surrounds it is usually what explains it.
**Contexte de recherche**, in the side panel, keeps ±N lines on each side of
every hit, the way `grep -C` does. It is 0 by default: until you change it, a
search returns exactly its own lines.

The `±` field in the search bar gives one criterion a span of its own; left
empty, it follows the shared value. With several criteria active, the widest
span applies. An inverted criterion (`≠`) has no hit to surround and does not
count.

**Filters still win.** A line hidden by its level, its source or its noise family
stays hidden even right next to a hit: context widens the search, it does not
undo a filter. Searching `ERROR` with ±2 while `INFO` is set to ✕ does not bring
the neighbouring `INFO` lines back.

The two contexts compose: a category in ◐ shows up around a search hit according
to **its own** span.

## Reading a whole line

**The detail pane, under the table.** Clicking a line — any line, not only an
error — shows it in full underneath, stack trace included. The divider is
draggable, and `Ctrl+I` closes the pane when you want the full height for the
table.

**The horizontal scrollbar.** The Message column is sized on the longest message
in the log, so a line wider than the window is read by scrolling right. Dragging
the column by hand pins the width you chose; changing the font hands control
back.

**Text size.** The `A−` / `A+` buttons at the top right, `Ctrl++` / `Ctrl+-`, or
`Ctrl`+wheel over the table. `Ctrl+0` restores the original size and
**Affichage → Police…** picks another monospaced font. The choice applies to
every tab and comes back with the next session.

## Copying

| | |
|---|---|
| A block of lines | select them in the table (`Shift`+click, `Ctrl`+click), then `Ctrl+C` |
| Part of one line | select it character by character in the detail pane, then `Ctrl+C` |

A copied line brings its stack trace along: pasting a `Mission script error`
without it would give an error nothing explains. The right-click menu also offers
the message **without the DCS header**, for when you want neither the timestamp
nor the subsystem.

## Explaining what is on screen {#explain}

**Analyse → Expliquer ce qui est affiché**, or `Ctrl+E`. The answer comes in two
layers, kept apart on screen, and the order between them is the whole design.

**The catalogue answers first.** Every pattern `rules.json` recognises is
rendered with its own wording, as it stands. No model, no cost, no network: this
layer alone is already an answer, and it is the degraded mode for the rest.

**The model puts it in context second**, only if you press **Analyser en ligne**.
It receives the excerpt and the patterns already matched locally, and it chains:
what happened first, what is only a consequence of it, which line to act on.
Where the catalogue is silent it says *pattern not catalogued* instead of
proposing a cause.

The worst failure of this feature is not silence, it is a plausible wrong answer:
*"it comes from your module X"* when it does not. The reader has no way to tell
it from a right one, and will spend his evening on it. That is why the two layers
carry their own headings rather than a disclaimer at the bottom nobody reads.

With no network, no quota left, behind a corporate proxy: the catalogue layer
answers and no error dialog appears.

### What leaves the machine {#explain-privacy}

Nothing, until **Analyser en ligne** is pressed. At that point what leaves is the
excerpt on screen, **bounded** (a character ceiling, omissions stated) and
**redacted** by the same code as `veaf-tools doctor`: Windows account name →
`<user>`, IP addresses → `<ip>`, e-mail addresses → `<email>`, tokens and
passwords → `<redacted>`. Mission, aircraft and payload names are kept: they are
what says *what* it crashed on.

The excerpt header also declares the categories set to ✕. A log filtered down to
"no errors" because `ERROR` was unticked must not read as a clean log.

### Recurring uncatalogued patterns {#proposals}

A message that recurs and that `rules.json` does not explain is a **missing
catalogue entry**. The analysis proposes one, in the file's own shape, with
identifiers and variable values already replaced by wildcards.

Nothing is written to `rules.json`: a proposal stays a proposal, and it is
precisely because the catalogue is hand-curated that its wording is quotable. The
generated `help` deliberately explains nothing — it says it is to be reworded.

## Preparing a report {#report}

The **Préparer un rapport** button assembles into one block the output of
`veaf-tools doctor`, the bounded and redacted excerpt, the catalogue matches and
what the analysis concluded — including what it could not explain — and puts it
on the clipboard, ready to paste into `#support` or an issue.

It is a **paste**, not a transmission: nothing leaves on its own. The block is
sized to fit one Discord message; when it does not all fit, it states what it
removed rather than being cut in silence.

Its format is versioned and documented: see
[Report block format](../developer/report-block.en.md).

## What it understands of the log

**Stack traces stay with their error.** A `Mission script error` followed by its
`stack traceback` forms a single entry, so filtering on errors no longer hides
the explanation. The line then carries a `[+3]` marker saying how many lines are
folded behind it.

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
| `Ctrl+C` | copy the selection |
| `Ctrl+Shift+C` | copy without the DCS header |
| `Ctrl+A` | select everything |
| `F` | follow the end of the file / pause |
| `Ctrl+R` | show everything |
| `Ctrl+S` | save the profile |
| `Ctrl++` / `Ctrl+-` | grow / shrink the font |
| `Ctrl+0` | default font size |
| `Ctrl`+wheel | grow / shrink the font |
| `Ctrl+I` | show or hide the detail pane |
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
| Session (open files, filters, geometry, font) | `%APPDATA%\veaf-logs\session.json` |
| Profiles | `%APPDATA%\veaf-logs\profiles.json` |
