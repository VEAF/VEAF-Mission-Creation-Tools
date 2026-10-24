# FEAT-GO-VEAF-LOGS-ISOFUNCTIONAL — rewrite veaf-logs in Go, the same program

Status: 🔄 in-progress — J1 merged (#1176); toolkit chosen: walk (ADR 0022); J2 next

Origin: David, 2026-10-24.
The first Go proof of concept (POC-GO-VEAF-LOGS, #1173 and #1174) delivered a Go core identical to the Python one, plus a minimal Gio window that is only a tail with a search.
David judged that window "nulle": what he asked for is **the same program** — its tabs, menus, commands, panels, profiles and filters — as a native binary.
This lot starts over from that goal, and its first step is the inventory below, to be validated before any Go UI code is written.

The figures of the proof of concept (12.3 MB executable, 0.3 s start, 2.4 s indexing) compare a minimal tail with a full application.
They prove nothing about the full application and must not be quoted as if they did.
The choice of Gio ([ADR 0021](../../docs/adr/0021-gio-for-the-go-veaf-logs-proof-of-concept.md)) is reopened.

Python reference, measured 2026-10-23: executable 47.2 MB, window shown in 2.1 s, a 130 MB log of 954 086 entries indexed in 13.3 s, search 0.7 s.

## Scope

- Go, in `src/go/veaf-logs/`, reusing the core already merged (`internal/logcore`, `internal/sshlog`).
- No change to the Python code, to `release.yml` or to any release pipeline.
- Step 1 (this document): the inventory, then David's decisions.
- Later steps are written once the decisions are taken (toolkit, milestones, scope of the analysis modules).

## Method

The inventory was taken by **reading** the code and its tests on `develop` at `53b7cf2e`: `ui/` entire, `filters.py`, `profiles.py`, `session.py`, `appearance.py`, `catalogue.py`, `worker_client.py`, the heads and signatures of `analysis.py`, `report.py`, `proposals.py`, `excerpt.py`, and the test names of `test/python/veaf_logs/` (`test_ui.py`, `test_analysis_ui.py`, `test_indexing.py`, `test_profiles.py`, `test_appearance.py`, `test_icon.py`).
Nothing is listed that was not found in the code.
"To confirm" marks a point read but not exercised.

## Volume

Lines of Python per module (`wc -l`, comments and docstrings included).

### Interface (PySide6)

| Module | Lines | Carries |
|---|---:|---|
| `ui/main_window.py` | 1 305 | main window, log tab, menus, profile bar, chips, status bar, session restore, dark palette |
| `ui/panels.py` | 449 | search bar, side panel, tri-state category buttons |
| `ui/model.py` | 237 | virtualised table model over the index |
| `ui/analysis_view.py` | 200 | *Explain* dialog |
| `ui/indexing.py` | 126 | progressive indexing in slices |
| `ui/delegate.py` | 117 | match highlighting in the Message column |
| `ui/__init__.py` | 8 | |
| **Total UI** | **2 442** | |

### Settings and filtering (no Qt)

| Module | Lines | Carries | Already in Go? |
|---|---:|---|---|
| `filters.py` | 512 | modes plain/glob/regex, tri-state ON/OFF/CONTEXT, two contexts, evaluation | **no** — Go has only a case-insensitive plain search (`search.go`) |
| `profiles.py` | 134 | built-in and user profiles, `profiles.json` | no |
| `session.py` | 108 | `session.json` | no |
| `appearance.py` | 41 | font defaults and bounds, icon path | no |
| **Total** | **795** | | |

### Core (already ported, PR #1173 and #1174)

| Module | Lines | Go counterpart |
|---|---:|---|
| `store.py` | 535 | `store.go` (585) |
| `remote.py` | 392 | `remote.go` (324) + `sshlog.go` (341) |
| `tailer.py` | 176 | `tailer.go` (119) — **without `.zip` archives** (no `zip` in the Go tree) |
| `parser.py` | 164 | `formats.go`, `store.go` |
| `rules.py` | 141 | `rules.go` (203) — `reclassify` (reload the catalogue on open logs) to confirm |
| `buffer.py` | 85 | `buffer.go` (77) |
| `__init__.py`, `__main__.py` | 25 | |
| **Total** | **1 518** | |

### Analysis (scope to decide)

| Module | Lines | Carries | External dependency |
|---|---:|---|---|
| `report.py` | 445 | report block for `/bug`, bounded to a Discord message (2 000 chars) | `veaf_libs.diagnostics` (590 lines, the `veaf-tools doctor` report) |
| `excerpt.py` | 439 | bounded (16 000 chars), redacted excerpt of the view | `veaf_libs.redaction` (274 lines) |
| `proposals.py` | 370 | proposed `rules.json` entries for recurring uncatalogued messages, with regex safety checks | |
| `catalogue.py` | 209 | the catalogue's own wording for each matched record | |
| `analysis.py` | 174 | assembles the four above, calls the online layer | |
| `worker_client.py` | 126 | HTTP + SSE client of the Worker's `/analyze` route (Gemini, no key on the client) | network |
| **Total** | **1 763** | | + 864 lines of `veaf_libs` |

Tests: `test/python/veaf_logs/` holds 4 780 lines, of which `test_ui.py` 959 and `test_analysis_ui.py` 240.

## Inventory — (a) interface and settings

### Window and layout — `ui/main_window.py`

| # | Where | What it does |
|---|---|---|
| A1 | Window | Title "veaf-logs — journaux DCS", 1500×900 by default, application icon (`veaf-logs.ico`, also on the executable). |
| A2 | Layout | Horizontal splitter: side panel of filters on the left (320 px, min 300), right column = profile bar, search bar, chip row, tabs. The splitter handle resizes the panel. |
| A3 | Theme | Qt "Fusion" style with a fixed dark palette (GitHub-dark colours: `#0d1117` background, `#c9d1d9` text, `#1f6feb` selection). No light theme, no theme switch. |
| A4 | Status bar | Left: transient messages (profile loaded, copy count, font size, catalogue reloaded, remote errors). Right, permanent: "N lignes affichées sur M — K masquées par les filtres", and the follow state ("suivi actif" / "suivi en pause" / "archive (pas de suivi)"). "Aucun journal ouvert." with no tab. |

### Menus and shortcuts — `MainWindow._build_menus`

| # | Menu | Entry | Shortcut | Effect |
|---|---|---|---|---|
| M1 | Fichier | Ouvrir le journal DCS courant | Ctrl+D | Opens `~/Saved Games/DCS/Logs/dcs.log`; warning box if missing. |
| M2 | Fichier | Ouvrir un fichier… | Ctrl+O | Multi-file dialog, starts in `Saved Games/DCS/Logs`, filter `*.log *.log.old *.zip`. |
| M3 | Fichier | Ouvrir un journal distant… | Ctrl+Shift+O | List "server › instance" from the user config `servers:` block; boxes for no server / invalid config. |
| M4 | Fichier | Fermer l'onglet | Ctrl+W | Closes the current tab and its source. |
| M5 | Fichier | Quitter | Ctrl+Q | Closes the window (saves the session). |
| M6 | Edition | Copier | Ctrl+C | Context-aware: selected text of a search field, else selected text of the detail panel, else the selected entries **with their stack trace**. |
| M7 | Edition | Copier sans l'en-tête | Ctrl+Shift+C | Selected entries, message only (no timestamp/level/source header). |
| M8 | Edition | Tout sélectionner | Ctrl+A | Text field with focus, else every row of the table. |
| M9 | Affichage | Suivre la fin du fichier (checkable, on) | F | Per tab; scrolls to the bottom when switched on; disabled for archives. |
| M10 | Affichage | Aller à la fin | none in practice | Scrolls to the last row. The code declares `"Ctrl+Fin"`, which Qt does not parse (measured 2026-10-24: `QKeySequence("Ctrl+Fin")` is empty), so the menu entry has no shortcut; the intent is Ctrl+End, which the Go version should give. |
| M11 | Affichage | Police… | — | Font dialog restricted to monospaced fonts. |
| M12 | Affichage | Agrandir / Réduire / Taille par défaut | Ctrl++ and Ctrl+= / Ctrl+- / Ctrl+0 | Zoom in 1-pt steps, bounded 6–36 pt; default Cascadia Mono 9. Ctrl+= exists because Ctrl++ needs Shift on a French keyboard. |
| M13 | Affichage | Panneau de détail (checkable) | Ctrl+I | Shows/hides the detail panel in every tab. |
| M14 | Affichage | Panneau des filtres (checkable) | Ctrl+B | Hides the side panel; its filters **still apply**. Shown again at its previous width, or at 320 px if it had been collapsed with the handle. |
| M15 | Affichage | Tout afficher (réinitialiser les filtres) | Ctrl+R | Empty filter set, search field cleared. |
| M16 | Affichage | Chercher | Ctrl+F | Focus to the search field. |
| M17 | Profils | Enregistrer sous… | Ctrl+S | See P3. |
| M18 | Profils | Supprimer le profil courant | — | See P4. |
| M19 | Règles | Recharger le catalogue | F5 | Reloads `rules.json`, reclassifies every open log, rebuilds the built-in profiles; error box if invalid. |
| M20 | Règles | Ouvrir rules.json | — | Opens the file with the system's default application. |
| M21 | Analyse | Expliquer ce qui est affiché… | Ctrl+E | Opens the *Explain* dialog (section (b)); status message if no log is open. |

All menu shortcuts are window-wide (`addAction` on the window).

### Profile bar — `_build_profile_bar`

| # | Widget | What it does |
|---|---|---|
| P1 | Toggle button | Carries action M14 (same state, same shortcut). |
| P2 | "Profil :" combo box | First item "Session courante" (the unnamed current filters), a separator, the 3 built-in profiles, then user profiles alphabetically. Choosing one loads it (filters replaced, search field cleared, status message). Any change of a filter afterwards switches the combo back to "Session courante". |
| P3 | "Enregistrer…" | Name prompt (pre-filled with the current name unless built-in or unnamed); saves or replaces a user profile; refuses an empty name or a built-in name (warning box). |
| P4 | "Supprimer" | Enabled only for a user profile; Yes/No confirmation; deletes. |
| P5 | "A−" / "A+" | Zoom buttons (same as M12), with the shortcut in the tooltip. |

### Profiles — `profiles.py`

| # | What |
|---|---|
| P6 | Built-in, read-only: **Tout** (no filter), **Lecture (sans le bruit ED)** (noise families marked hidden-by-default in `rules.json` set to OFF), **Diagnostic (erreurs + contexte)** (INFO, DEBUG, TRACE in CONTEXT, same noise OFF, context ±3). Computed from the current catalogue. |
| P7 | User profiles in `%APPDATA%\veaf_logs\profiles.json` (`~/.config` elsewhere), version 1, atomic write; unreadable file or other version → built-ins only. A profile = a full `FilterSet`. Loading returns a copy: editing filters never rewrites the profile. |
| P8 | `rename` exists in `ProfileStore` but **no UI calls it** — not part of the user-visible surface. |

### Search bar — `ui/panels.py` `SearchBar`

| # | Widget | What it does |
|---|---|---|
| S1 | Text field | Placeholder "Rechercher… (Ctrl+F)", clear button. Filters live as you type, on top of the saved filters. |
| S2 | Mode combo | Texte (literal substring) / Jokers (`*` any run, `?` one char, `.` literal, not anchored) / Regex (full). Tooltip explains the three. |
| S3 | "≠" toggle | Invert: hide matching lines. |
| S4 | "Aa" toggle | Case-sensitive. |
| S5 | "±" spin box (0–999) | Context lines for this criterion only; at 0 it shows the common value in parentheses, e.g. "(2)". |
| S6 | "Ajouter au filtre" | Turns the live criterion into a saved criterion (a chip), clears the field. |
| S7 | Error label (red) | An invalid regex shows its error and applies nothing (the view keeps the previous state). |
| S8 | Highlighting — `ui/delegate.py` | Matches of every positive (non-inverted) criterion are highlighted in the Message column (background `#7a5c00`, white text); overlapping matches fused. |

### Chips — `_build_chips`, `_refresh_chips`

| # | What |
|---|---|
| C1 | One flat rounded button per saved text criterion, labelled e.g. "sans Regex : foo  ±5  ✕" (`TextFilter.describe`); click removes it. The row is hidden when there is no saved criterion. |
| C2 | Saved criteria are cumulative (AND for positive ones; an inverted one removes its matches). `TextFilter.enabled` exists in the model but no UI toggles it — to confirm whether it matters (profiles could carry `enabled: false` only if hand-edited). |

### Side panel — `ui/panels.py` `SidePanel`

| # | Widget | What it does |
|---|---|---|
| F1 | Legend | "✓ affiché ◐ contexte ✕ masqué". |
| F2 | "Contexte des catégories : ±" spin box (0–200 lines) | Common context span for categories in CONTEXT. Default 3. |
| F3 | "Contexte de recherche : ±" spin box (0–200 lines) | Common context around search results; default 0. Context lines remain subject to the category filters. |
| F4 | Three groups: **Niveaux**, **Sources**, **Bruit** | One tri-state button per category: "✓ label (count)". Click cycles ON → CONTEXT → OFF → ON. OFF is greyed, CONTEXT italic; levels and sources coloured from `rules.json`. Tooltip: catalogue help text (noise families) + current state + "Clic : état suivant". |
| F5 | Group header buttons "tout / contexte / rien" | Set every category of the group to ON / CONTEXT / OFF. |
| F6 | Per-category "±" spin box | Visible only when the category is in CONTEXT; overrides the common span; shows the common value as a suffix when empty. |
| F7 | Content | Levels in catalogue order; sources sorted by decreasing count, with catalogue labels; noise families listed **only once encountered** in the log. Counts update live while following; chosen states survive refreshes. |
| F8 | State of absent categories | A category not present in the current log keeps its state in the filters (a profile hiding DEBUG keeps doing so on a log that has no DEBUG yet). |
| F9 | Scrolling | The panel is a scroll area. |

### Filtering semantics — `filters.py`

| # | Rule |
|---|---|
| R1 | A category state combines across level, source and every noise family of an entry: OFF beats CONTEXT beats ON. |
| R2 | Text criteria apply only to entries kept by the categories; a match inside a stack trace selects the entry that carries it. |
| R3 | Search context reopens neighbours of results **only among entries the categories allowed** before the text criteria narrowed; added lines are not anchors themselves. Span = widest among active, non-inverted criteria (own span or common one). |
| R4 | Category context then adds CONTEXT entries within their span (widest span wins when several categories disagree) of any kept entry. |
| R5 | Empty filter set → every entry, short-circuited; while following with no filter, new entries are appended without re-evaluation. |
| R6 | Unknown categories (a level appearing while following) are shown by default: only non-ON states are stored. |

### Log tab — `LogTab`

| # | Where | What it does |
|---|---|---|
| T1 | Tabs | One tab per open log; **closable** (× on the tab) and **reorderable** by drag; tooltip = full path or `server/instance` location; title = file name. New tabs inherit the current filters, font and detail setting. |
| T2 | Table | Virtualised over the index (cost independent of the log size). Columns: Ligne (right-aligned, grey), Heure (time only, grey), Niveau, Source (catalogue label, `-module` suffix, source colour), Message. Row selection, multi-select, no grid, no row header, no word wrap. |
| T3 | Row style | Foreground colour, optional background, bold when the level weight ≥ 600 — all from `rules.json`. Row height follows the font. |
| T4 | Folded traces | A message with continuation lines ends with `[+N]`; tooltip shows the full entry. When a trace arrives after its error line while following, the row is refreshed. |
| T5 | Columns width | Fixed defaults (68/92/78/130 px), all user-resizable. Message column sized to the longest message of the log (or the free space if larger, min 200) so a horizontal scroll bar reaches the end of long lines; once the user drags it, it stays; a font change resets that. Horizontal scroll per pixel. |
| T6 | Detail panel | Below the table in a vertical splitter (≈1/5 of the height, resizable, table not collapsible): read-only, no-wrap text of the **whole current entry** whatever its level; hidden when nothing is selected or when M13 is off. Selectable text with its own Ctrl+C. |
| T7 | Context menu (right click on a selection) | "Copier la ligne / les N lignes", "Copier le message / les messages sans l'en-tête". |
| T8 | Ctrl+mouse wheel on the table | Zoom (M12), instead of scrolling. |
| T9 | Indexing | Logs ≤ 4 MB indexed at once; larger ones in event-loop slices (~60 ms each, adaptive chunk 256 KB–16 MB), first rows readable immediately. A progress bar "Indexation… N %" and an "Interrompre l'indexation" button show during it; interrupting keeps what is indexed. Side-panel counts refreshed at most every 400 ms during indexing. |
| T10 | Follow | A 400 ms timer polls every followable tab (remote tabs at their own interval); new entries appended; auto-scroll to the bottom when follow is on. |
| T11 | Rotation | When DCS replaces the log (renamed to `.old`, truncated or rewritten), the tab clears and restarts on the new file. |

### Sources — `tailer.py`, `remote.py`, `veaf_libs.user_config`

| # | What |
|---|---|
| O1 | Local file (`.log`, `.log.old`, any file). |
| O2 | `.zip` archive (DCS crash archive): its log members listed (`.log`, `.txt`, `dcs.*` preferred); a single one opens directly, several → choice dialog; unreadable or empty archive → warning box. Archives are not followable. **Not in the Go core yet.** |
| O3 | Remote log over SFTP, by key, from the `servers:` block of the user config; local mirror, rotation detected. Unknown host key → Yes/No box showing the fingerprint, accepted keys stored in `known_hosts`. |
| O4 | Command line: every non-option argument is opened as a file; with none and no session tab, `~/Saved Games/DCS/Logs/dcs.log` is opened as a fallback. |

### Session — `session.py`, `_restore`, `_capture`

| # | What |
|---|---|
| X1 | Saved on close to `%APPDATA%\veaf_logs\session.json` (version 2, atomic, unknown keys ignored, a failed save never blocks closing): open files (path, archive member, remote), active tab, selected profile, current filters, window geometry, font family and size (clamped on load), detail and filters panels visibility. |
| X2 | Restore: local tabs reopened before the window shows, files that disappeared skipped; remote tabs reopened **after** the window shows, one at a time from the event loop, each at its session position, without stealing the foreground from the tab being looked at. |
| X3 | Remote failures at restore go to the status bar, not dialog boxes; a server that just failed is not retried for its other instances; a remote no longer in the config is skipped with a message. |
| X4 | A file passed on the command line or opened during the restore keeps the foreground; the fallback log is not added to a restored session. Closing the window during a remote connection keeps the pending remotes in the saved session and releases the source. |

## Inventory — (b) analysis modules (scope to decide, not costed)

| # | Where | What it does | Modules |
|---|---|---|---|
| B1 | Analyse › Expliquer… (Ctrl+E) → dialog "Analyse du journal" (1000×700) | Computes, **offline and immediately**, an analysis of the entries currently visible (the view, not the whole log): bounded and redacted excerpt with a header stating which categories were hidden (a hidden ERROR level is called out), the catalogue's verbatim explanation of each matched record with counts, the uncatalogued messages (capped, with the remainder counted), and proposed `rules.json` entries for recurring uncatalogued messages. Shown as read-only text. | `analysis.py`, `excerpt.py`, `catalogue.py`, `proposals.py`, `veaf_libs.redaction` |
| B2 | Dialog: optional question field + "Analyser en ligne" | Sends the excerpt and the catalogue matches (nothing else) to the VEAF Worker on a background thread; the model's answer replaces the model section; failure is written in the dialog's status line, never a box; a second click while running is ignored; closing waits up to 1 s for the request. | `worker_client.py` (HTTP POST, SSE stream, 45 s timeout) |
| B3 | Dialog: "Préparer un rapport" | Builds a block for the Discord `/bug` command — `veaf-tools doctor` diagnostic, excerpt, catalogue, what is unexplained — bounded to a Discord message and saying what it dropped; puts it on the clipboard; status "Rapport copié (N caractères)". A diagnostic that cannot be collected costs that section only. | `report.py`, `veaf_libs.diagnostics` |
| B4 | Dialog: "Fermer" | Closes. | |

`report.parse_report_block` (the reader half of the report contract) has no caller outside `veaf_logs` and its tests; the support bot reads the `doctor` block inside the report with `veaf_libs.diagnostics.parse_block` (`services/support-bot/veaf_support_bot/toolkit.py`).

## What each toolkit must provide

The UI above needs, whatever the toolkit:

1. **Menu bar** with mnemonics (`&Fichier`), separators, checkable entries, shortcuts displayed in the menus, window-wide shortcuts (Ctrl+D/O/W/Q/C/A/F/B/I/E/R/S, Ctrl+Shift+O/C, Ctrl+End (see M10), Ctrl+0, Ctrl++ and Ctrl+=, F, F5), working on a French keyboard.
2. **Tabs**: closable (× per tab), reorderable by drag, tooltip per tab, programmatic insertion at a given index.
3. **Virtualised table** for millions of rows: 5 columns, resizable column headers, per-cell colour/background/bold, multi-row selection (click, Shift, Ctrl), keyboard navigation, horizontal scroll per pixel, scroll-to-bottom, row height derived from the font, per-row tooltip, right-click context menu.
4. **Rich cell rendering**: highlight several sub-ranges of the Message cell in another colour.
5. **Splitters**: horizontal (side panel / content) and vertical (table / detail), draggable, remembering the width of a hidden pane.
6. **Read-only multi-line text view** (detail panel, analysis dialog): monospaced, no wrap, text selection and copy, scrollable.
7. **Form widgets**: line edit with placeholder and clear button, combo box (with a separator item), toggle buttons, push buttons, integer spin boxes with prefix/suffix and a "special value" display at 0, labels, a **three-state button** with custom glyph/colour/italic per state.
8. **Scrollable panel** holding grouped widgets (group boxes with titles), rebuilt incrementally without losing state.
9. **Chips**: a row of small removable buttons, rebuilt on change.
10. **Progress bar** and a cancel button inside the tab.
11. **Status bar** with a transient message area and permanent labels.
12. **Standard dialogs**: native multi-file open dialog with filters and a start folder, monospaced-font chooser, text input prompt, item chooser (list), information/warning/critical boxes, Yes/No confirmation.
13. **Custom modal dialog** (analysis) with a text field, buttons, a text view, a status line.
14. **Clipboard** write.
15. **Open a file with the system's default application** (`rules.json`).
16. **Timers and event-loop scheduling**: a 400 ms poll, zero-delay single shots (progressive indexing, sequential remote restore), so long work never freezes the window; a background thread or goroutine whose result is posted back to the UI thread (online analysis).
17. **Mouse wheel with modifier** interception (Ctrl+wheel = zoom).
18. **Dark theme** applied application-wide (palette), plus per-widget styling (chip borders, greyed/italic states).
19. **Window**: application icon (window, taskbar, executable), save and restore of the geometry.
20. **Fonts**: choose family and size at runtime, monospaced, metrics (character width for the Message column, line height).
21. **Windows**: `release.yml` publishes `veaf-logs.exe` from its Windows job only, while `veaf-tools` also ships Linux and macOS arm64 binaries; whether a Go veaf-logs must follow them is a decision, not a requirement found in the code.

## Tickets

| # | Ticket | Milestone | Status |
|---|--------|-----------|--------|
| 01 | [The filter engine of `filters.py`, in the Go core](tickets/01-filter-engine.md) | J1 | ✅ |
| 02 | [DCS crash archives (`.zip`) in the Go core](tickets/02-zip-archives.md) | J1 | ✅ |
| 03 | [The Go parity tests run in CI, on a checkout that has the corpus](tickets/03-go-tests-in-ci.md) | J1 | ✅ |
| 04 | [Compare the toolkits on the 21 needs, and choose](tickets/04-toolkit-comparison.md) | before J2 | ✅ |

## J1 — what was measured

**Parity.** `gen_golden.py` writes, per corpus file, an enumerated set of filter cases — every category present set to OFF and to CONTEXT ±0/1/3, 23 patterns across the three modes × case × inversion × search context, and combinations — evaluated by the Python `evaluate` (2 053 cases over the seven corpus files).
The Go engine reads each case through its `FilterSet` JSON reader and returns the same visible entries for all of them.
On the 130 MB / 954 086-entry journal of the proof of concept, five filter sets give the same entries on both sides (equal SHA-1 of the visible indices).

**Speed**, same journal, same visible entries, `Evaluate` alone:

| Filter set | Python | Go |
|---|---:|---:|
| Diagnostic profile (INFO/DEBUG/TRACE in context ±3) | 0.69 s | 0.02 s |
| Plain "SCRIPTING", case ignored | 0.97 s | 0.08 s |
| Regex `VEAF\|[WE]\|` | 0.76 s | 0.44 s |
| Glob `*error*lua*` + search context ±2 | 56.93 s | 0.64 s |
| Plain "INFO", case-sensitive, inverted | 0.48 s | 0.04 s |

A straight port was **slower** than Python on case-insensitive searches (3.1 s plain, 2.2 s regex): Go's `(?i)` defeats the literal prefilter and is slow by itself.
Plain text now runs a byte search over an ASCII-lowered block — exactly Python's `IGNORECASE` on bytes — and a regex with no anchor that cannot cross a line runs only on the lines holding one of its required literals; anything else is scanned whole, as Python does.
Each shortcut is proven to give the same entries by the parity, and the parity is proven able to fail on it (a mutation disabling the guard fails the cross-line cases).

**Where Go and Python cannot agree** — pinned by `TestKnownDivergencesFromPython`, measured on the Python side 2026-10-24:

| Pattern | Python (`re` on bytes) | Go (RE2) |
|---|---|---|
| Regex `é`, case ignored, on `É` | no match: bytes `IGNORECASE` folds ASCII only | match: `(?i)` folds Unicode (plain mode does fold like Python) |
| Lookahead `(?=…)`, backreference `\1`, `\Z` | accepted | refused, shown as an invalid pattern |
| Class `[é]` on a lone byte `0xA9` | match: the class is encoded to bytes | no match: classes hold characters |

A `$` outside multi-line mode also matches before the block's final newline in Python; Go's regex was rewritten to do the same, until [FIX-VEAF-LOGS-VIEWER-DEFECTS](../FIX-VEAF-LOGS-VIEWER-DEFECTS/PRD.md) made `^` and `$` bind to lines on both sides.

**Found in the Python viewer, not fixed here** (the lot does not touch the Python code; all three are fixed by [FIX-VEAF-LOGS-VIEWER-DEFECTS](../FIX-VEAF-LOGS-VIEWER-DEFECTS/PRD.md)):

1. *Aller à la fin* has no shortcut: the code declares `"Ctrl+Fin"`, which Qt does not parse (M10).
2. A regex starting with `^` matches only the first entry of each 8 MB search block: the pattern runs over the block without `MULTILINE`. The Go engine reproduces it for parity; fixing it means fixing both sides together.
3. A glob starting with `*` freezes the window for about a minute on a 130 MB journal (56.9 s measured): the leading `.*` is retried from every position of every line. Dropping the leading and trailing `*` of an unanchored glob matches the same entries.

None of the three goes into `known-limitations.yaml`: that file is what an agent must know to build a mission, served as is by the MCP, and a log viewer's defects would only be noise there.

## Lessons carried over from the proof of concept

- Go's `regexp` is slower than Python's `re` on the `rules.json` patterns: a direct port was 1.5× **slower**. The literal prefilter in `internal/logcore/prefilter.go` (`bytes.Contains` on required literals) makes it 5× faster without changing a result; any new pattern engine (search modes, filters) must go through the same path.
- In Gio, scrolling a list before its first layout blocked the first frame for more than 10 s at 100 000 lines.
- Never hold the window lock across a network call (a test in `cmd/veaf-logs` checks it).
- ADR 0021 quotes 9.5 MB for the executable: that is the build without SFTP; with it, 12.3 MB.

## Decisions

Taken by David on 2026-10-24, unless marked *default* (a recommendation he did not overturn).

1. **Analysis in scope, entirely** — the program must be isofunctional, so *Explain* (B1–B4) is ported with the excerpt, the catalogue, the proposals, the online layer and the `/bug` report.
   The report carries the `veaf-tools doctor` block, so its collectors come too: `veaf_libs.diagnostics` (590 lines: tool version, machine, DCS install and version, VEAF home, recent errors of `veaf-tools.log`), `veaf_libs.redaction` (274) and the Lua module count of `veaf_libs.lua_module_scanner` (434).
   The block format must stay identical: the support bot parses the `doctor` block with `diagnostics.parse_block`, and `report.parse_report_block` defines the report's own contract.
2. *Default* — milestones in this order: J1 filter engine in the Go core (modes, tri-state, both contexts, cumulative criteria, `.zip` archives), proven identical to the Python with the existing parity harness; J2 window, tabs, table, menus, detail, copy; J3 side panel, search bar, chips, profiles, session; J4 remote logs and session restore; J5 analysis and report.
   J1 needs no toolkit, so it can start before decision 3 is settled.
3. **Pure GUI toolkits only, no web view** — Wails and anything embedding a browser engine are out.
   Candidates to compare on the 21 needs above: Gio, Fyne, miqt (Qt bindings: native Qt widgets, but the Qt runtime comes back into the executable size) and walk (native Win32 controls, Windows only — consistent with decision 4).
4. *Default* — Windows only, as `release.yml` ships `veaf-logs.exe` today.
5. *Default* — success is measured on the **complete** application against the Python reference (47.2 MB, 2.1 s, 13.3 s, 0.7 s); "we do not ship it" remains a valid outcome.
