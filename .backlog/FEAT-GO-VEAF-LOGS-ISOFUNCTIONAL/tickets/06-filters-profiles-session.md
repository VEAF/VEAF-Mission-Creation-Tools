# 06 — J3: filters panel, search, chips, profiles, session

Status: 🔄 in-progress

Milestone J3, in the same pull request as J2 (#1181): David tested J2 — "the dark mode is OK, but the UI is not isofunctional at all, the filters panel is missing" — and asked to go on with J3 before merging.

## Scope

Inventory items:

- Side panel (F1–F9): legend, the categories' and the search's context spans, the three groups with their tri-state categories, per-category spans in CONTEXT, `tout / contexte / rien`, counts kept live, categories absent from the journal keeping their state, hidden with Ctrl+B (M14) and its button (P1).
- Search bar (S1–S8) and chips (C1, C2), Ctrl+F (M16), Ctrl+R (M15).
- Profiles (P2–P7, M17, M18): the three built-in ones, the user's in `%APPDATA%\veaf_logs\profiles.json` — the Python's file, read and written in its format.
- Session (X1, X2 for local files, X4): `%APPDATA%\veaf_logs\session.json` — the Python's file; the remote entries it holds are kept as they are and reopened in J4; the Python's Qt geometry is kept for the Python.
- Our own dark dialogs for the text prompt and the yes/no confirmation.

Not here: the *Règles* menu (M19, M20) and the remote journals (M3, O3, X3) go with J4, the analysis (B1–B4) is J5.

## Done when

- The profile store, the session and the side panel's model live in `internal/logview` with their tests, the file formats checked against what the Python writes.
- The window shows the panel, the search bar, the chips and the profile bar, all dark, and they filter every tab as the Python does.
- Closing and reopening restores the tabs, the current tab, the filters, the profile, the font, the panels and the window's place.
