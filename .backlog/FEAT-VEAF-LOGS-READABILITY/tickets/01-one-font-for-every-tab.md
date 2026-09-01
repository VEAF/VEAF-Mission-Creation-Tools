# 01 — one font for every tab, and a way to change it

Status: ✅ done

Part of [FEAT-VEAF-LOGS-READABILITY](../PRD.md).

`QFont("Cascadia Mono", 9)` is built three times independently — `LogTab.view`, `LogTab.detail`,
`LogModel._mono` — and `verticalHeader().setDefaultSectionSize(18)` assumes the result. Change the
size in one of them and the rows stay 18 pixels tall.

So the first move is not the zoom, it is the single source of truth: one family and one size held
by the window, pushed to every tab that exists and to every tab opened afterwards. The row height
is then derived from the font metrics, never written down.

On top of that:

- menu **Affichage** — « Police… » (`QFontDialog`, monospace only), « Agrandir » `Ctrl++`,
  « Réduire » `Ctrl+-`, « Taille par défaut » `Ctrl+0`
- two `A−` / `A+` buttons in the top bar, for the people who do not read the menus
- `Ctrl`+wheel over the table
- bounded 6–36, so a wheel held down cannot make the tool unusable

Persisted in `session.json`. `Session.load` already drops unknown keys and fills missing ones from
the dataclass defaults, so new fields need **no** `SESSION_VERSION` bump — bumping it would throw
away every user's open files and filters for a font size.

Done when a size chosen in one tab holds in a tab opened afterwards, survives a restart, and the
rows are as tall as the glyphs.
