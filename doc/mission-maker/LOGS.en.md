# veaf-logs — reading DCS logs

`veaf-logs` opens a DCS log and shows only what matters. It knows the VEAF, CTLD,
CSAR, AIEN and Skynet scripts, recognises Eagle Dynamics' harmless errors, and
follows the file live while the mission runs. It also reads a server's other logs:
DCSServerBot, Real Weather and LotAtc (see [Other server logs](#other-logs)).

## Running it

From the executable shipped with the release:

```
.\veaf-logs.exe
```

With no argument it reopens the last session's files, falling back to the current
`dcs.log` (`Saved Games\DCS\Logs\dcs.log`). You can also pass it a path, or drop a
file onto it.

`veaf-logs.exe` is a standalone Windows program written in Go: one file of about fifteen megabytes, with no Python or anything else to install.
Its sources are in `src/go/veaf-logs/`, whose `README.md` says how to build it.

## A remote server's log {#remote}

`File › Open a remote log…` (Ctrl+Shift+O) follows the `dcs.log` of a DCS server over
SSH, with the same filters, rules and profiles as a local file. One machine often
hosts several DCS instances: declare the machine once, then one log per instance,
in `~/veafmct.yaml` (see [the global user configuration](GUIDE.en.md#global-user-configuration)):

```yaml
servers:
  veaf:
    host: dcs.veaf.org
    user: veaf
    port: 22                  # optional
    key: ~/.ssh/id_ed25519    # optional: the SSH agent and default keys otherwise
    logs:
      private1: C:/Users/veaf/Saved Games/private1_server/Logs/dcs.log
      public1: C:/Users/veaf/Saved Games/public1_server/Logs/dcs.log
```

The menu then offers `veaf › private1`, `veaf › public1`… Each instance opens a
`veaf:private1` tab, reopened at the next launch like a local file — once the
window is up, in its place among the tabs: each connection takes a second or two,
and the window does not wait for them.

**Key authentication only.** The tool never asks for, reads or stores a password.
When the machine's key is not yet in `~/.ssh/known_hosts`, a dialog shows its
fingerprint and offers to remember it, as `ssh` does the first time.

The log is mirrored locally as it grows: one `stat` per second, and only the new
bytes travel. When DCS restarts on the server and starts a fresh file, the tab
starts over with it. A network outage puts the tab on hold; it resumes where it
was as soon as the server answers, retrying every five seconds. Opening a stopped
instance (no `dcs.log` on the server) shows a message; a tab already open stays on
hold until the instance starts again. At launch, an unreachable server is reported
in the status bar and its tabs are not reopened: nothing blocks.

On the Windows server side you need the **OpenSSH Server** service (a Windows
optional feature, `Settings › Apps › Optional features`): SFTP is included and
enabled by default. Classic trap: for an **administrator** account the public key
goes to `C:\ProgramData\ssh\administrators_authorized_keys`, not to
`~\.ssh\authorized_keys`, and that file must be readable only by `SYSTEM` and
`Administrators`.

`veaf-tools.exe` does not carry this feature: it lives in `veaf-logs`.

### Through DCSServerBot's API, without an SSH account {#remote-api}

A server running DCSServerBot with its RestAPI plugin can also be read without an account on the machine: an API key is enough, and the bot only reads.
Declare the API instead of `host` (a server has one or the other, never both):

```yaml
servers:
  veaf-api:
    api:
      url: https://dcs.veaf.org/serverapi       # the API, with its prefix if it has one
      api_key_file: ~/.veaf/dcssb-api-key       # a file holding the key alone
    # logs:                                     # optional: narrow or rename
    #   private1: {instance: VEAF Private 1}    # the server's name in the bot
    #   bot: {node: dcs-veaf-org}               # a node's bot log
```

Without `logs:`, the menu asks the API what it has: every DCS server it knows (`veaf-api › VEAF Private 1`…) and the bot's log (`veaf-api › bot`).
The tabs are reopened at launch like those of an SSH server.

**On dcs.veaf.org**, the address is `https://dcs.veaf.org/serverapi`, and the key file holds the **technician key David hands out**, not the bot's key: from the internet, only the technician key gets through.
Any other key gets the same answer as a missing route there; the tool shows it as an authentication refused.

`File › Open an older log…` (`Fichier › Ouvrir un ancien journal…`), on a tab opened through the API, lists that log's files with their size and date: `dcs.log.old`, the `dcs-YYYYMMDD-HHMMSS.log` copies the bot makes at each shutdown, or the bot's `dcssb-<node>.log.1` to `.5`.
The chosen file opens read-only in a tab, loaded from start to end in chunks; it is not reopened at the next launch.

What differs from SSH:

- a tab opens on the last 2,000 entries of the log, then follows what is written; to go further back, open the file through `Open an older log…`;
- the API returns entries, which the tool writes back as lines: only the level's padding (the spaces after `INFO`) and a line longer than 8 KiB (cut by the bot) differ from the original file, and no rule reads them;
- when the log restarts and the bot can no longer find the end of the old file, the status bar says so: lines were lost;
- the status bar also says why a log cannot be read: key refused, no log yet, unknown server or file, log on another node, server unreachable.

On the server side you need:

- DCSServerBot with the log reading routes (`/instance/logs`, `/instance/log`, `/node/logs`, `/node/log`): the `veaf` branch of [VEAF/DCSServerBot](https://github.com/VEAF/DCSServerBot), until the DCSServerBot release that publishes them;
- the RestAPI plugin with an `api_key` in its `restapi.yaml`: without a key these routes do not exist;
- an HTTPS reverse proxy in front of the API (Caddy, nginx, IIS), the bot's web service listening on `127.0.0.1` only;
- from DCSServerBot 3.0.5 on, which asks connections from the internet for a JWT by default: allow the API key on the log routes **and** on `servers`, which the menu reads (`endpoints.<route>.security.remote: api_key` in `restapi.yaml`).

Security:

- the key lives in a file only you can read, never in `veafmct.yaml`; the tool reads it when a tab opens and writes it nowhere, not in the session, not in a message, not in the `/bug` report;
- the tool refuses an `http://` URL except to `127.0.0.1` or `localhost` (the end of an SSH tunnel): the key and the logs cross the network;
- the logs hold player names and IP addresses: give a key to whoever administers the server.

## Tabs {#tabs}

When the tabs are wider than the window, the strip scrolls: with the mouse wheel over it, or with the ‹ › arrows that then show at its right.
The current tab is always brought into view.
From two tabs on, the ≡ button at the strip's left lists them all; a click on a title goes there.

A right click on a tab offers to close it or to rename it.
*Rename the tab…* (`Renommer l'onglet…`) writes its alias into `~\veafmct.yaml`, and the alias is back at the next launch; an empty name gives the tab its own name back.
It can be written by hand too:

```yaml
log_aliases:                       # local files, by their path
  'C:\Users\me\Saved Games\DCS\Logs\dcs.log': My game
servers:
  veaf-api:
    api: {url: https://dcs.veaf.org/serverapi, api_key_file: ~/.veaf/dcssb-api-key}
    aliases:                       # a server's logs, SSH or API, by their name
      VEAF (www.veaf.org) [fr] - Privé 1: P1
```

The tool rewrites the file keeping its content and its comments, though not always their alignment.
Without an alias, the logs an API discovers lose the words all its servers share: `veaf-api:Privé 1` rather than `veaf-api:VEAF (www.veaf.org) [fr] - Privé 1`.
The full name stays in the tab's tooltip.

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

To give the log the whole width, the **Panneau des filtres** button, at the start of the
profile bar (or `Ctrl+B`), hides this panel; pressing it again brings it back at the width
it had. Hidden, the filters **still apply**: the status bar keeps saying how many lines
they hide. The panel stays hidden from one session to the next.

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

In regex mode, `^` and `$` mean the start and end of a line.

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

## Other server logs {#other-logs}

A DCS server writes other logs than `dcs.log`, each with its own line shape.
`veaf-logs` recognises these, with the time, level and emitter of every line:

| Log | Sample line | Source shown |
|---|---|---|
| DCSServerBot (`logs\dcssb-*.log`, chat log) | `2026-09-29 18:02:44.490 WARNING⇥New update…` | DCSSB |
| DCSServerBot, performance (`perf-*.log`) | `2026-09-29 18:03:38,541⇥INFO⇥4.80s⇥…` | DCSSB |
| DCSServerBot, exceptions (`async_errors.log`) | `2026-05-26T00:47:56.023909: Task exception…` | DCSSB, as `ERROR` |
| Real Weather (`realweather.log`) | `2026-09-29T20:03:44.385+0200⇥WARN⇥…` | Real Weather |
| LotAtc (`LotAtc_server.log`) | `[2026-09-29 20:05:21 +02:00] [W] [clienthandler] Init` | LotAtc |

The shape is recognised **line by line**, not file by file: DCSServerBot copies
Real Weather's output verbatim into its own log, and those lines show there with
the Real Weather source and their real level (`WARN` as a warning, `FATAL` as an
alert).

Script prefixes (VEAF, CTLD…) are looked for in `dcs.log` lines only: elsewhere, a
message containing "SRS" does not come from the SRS script.

Five noise families belong to these logs, hidden by the **Lecture** and
**Diagnostic** profiles:

| Family | What it is | Share of the log |
|---|---|---|
| DCSSB: mission events | every mission event relayed from the server to the bot, as JSON | 70 % |
| DCSSB: periodic polling | status, load and frame rate requested every minute | 3.5 % |
| LotAtc: startup options | the option list, copied on every start | 19 % |
| LotAtc: airfield sides | the side of every airfield, on every mission start | 17 % |
| LotAtc: client connections | a client connecting and disconnecting, including the `Init`, `Finish` and *The remote host closed the connection* warnings of a normal disconnection | 33 % |

Measured on 2026-09-29 on the dcs.veaf.org logs: of the DCSServerBot log's 4,090
entries, 1,084 remain once the noise is set aside; of LotAtc's 8,735, 2,669.

A file where no line has a known shape reads line by line, at level `UNKNOWN`. The
filter panel lists only the sources and noise families present in the open log.

To follow one of these logs remotely, declare it like a `dcs.log` under `logs:`
([A remote server's log](#remote)), for instance
`dcssb: C:/Users/veaf/VEAF-DCSServerBot/logs/dcssb-dcs-veaf-org.log`.

## Large logs

The text is not held in memory: only a compact index is, and lines are decoded as
they are displayed. On a 130 MB server log (954,086 entries):

| | |
|---|---|
| Window shown | 0.04 s |
| Full indexing | 2.4 s, in the background |
| Memory, log open | 116 MB |

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
| `Ctrl+End` | go to the end |
| `Ctrl+R` | show everything |
| `Ctrl+S` | save the profile |
| `Ctrl++` / `Ctrl+-` | grow / shrink the font |
| `Ctrl+0` | default font size |
| `Ctrl`+wheel | grow / shrink the font |
| `Ctrl+I` | show or hide the detail pane |
| `Ctrl+B` | show or hide the filter panel |
| `F5` | reload the rule catalogue |

## Adding your own rules

Recognised sources, colours and noise families all live in one catalogue, `rules.json`, built into the executable.
The **Règles** menu opens an editable copy of it, which `F5` reloads without leaving the application.
That copy only lasts for the current session: a rule meant to stay goes into the repository's `src/python/veaf-tools/veaf_logs/rules.json`, and ships with the next release.

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

A family that belongs to another log than `dcs.log` names its format with
`"formats": ["dcssb"]` (or `realweather`, `lotatc`): it is then looked for in that
log's lines only. Source prefixes (`match`) apply to `dcs.log` lines only.

## Where the settings live

| | |
|---|---|
| Session (open files, filters, geometry, font, panels shown) | `%APPDATA%\veaf_logs\session.json` |
| Profiles | `%APPDATA%\veaf_logs\profiles.json` |
| Remote servers (`servers:`) | `~\veafmct.yaml` |
| A server's API key | the file of its `api_key_file` |
| Tab aliases | `~\veafmct.yaml` (`log_aliases:`, and each server's `aliases:`) |
| Local mirror of a remote log | `%TEMP%\veaf-logs-*.log`, removed when the tab closes |
