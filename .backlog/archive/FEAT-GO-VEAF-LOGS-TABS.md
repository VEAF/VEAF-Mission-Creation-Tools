# FEAT-GO-VEAF-LOGS-TABS — the tab strip scrolls, lists its tabs, and a tab can be renamed

Status: ✅ done · archived 2026-11-24

David, 2026-10-26, after opening seven API tabs of dcs.veaf.org at once: the tabs past the window's width were cut off, and each title was `veaf-api:VEAF (www.veaf.org) [fr] - Privé 1`.

## What the lot delivers

1. **The strip scrolls** (ticket 01): the mouse wheel over the strip scrolls it, ‹ › arrows show at its right edge only when the tabs overflow, and the current tab is always brought into view (opened, chosen from the list, restored).
2. **A list button** (ticket 02) at the strip's left, hidden with fewer than two tabs: a menu of every tab's title, the current one checked; choosing one goes there.
3. **Aliases** (ticket 03), decided by David: renamed in the window or in the configuration, and a rename in the window writes the configuration.
   - A remote tab's alias is `servers.<server>.aliases.<log>` in `~/veafmct.yaml`, for SSH and API servers alike; a local file's is `log_aliases.<path>` at the top of the file.
   - *Renommer l'onglet…* on the tab's right-click menu writes it there (empty: the alias is removed), the rest of the file left as it was, comments included.
   - Without an alias, the logs an API discovers lose the prefix all its servers share: `veaf-api:Privé 1` rather than `veaf-api:VEAF (www.veaf.org) [fr] - Privé 1`.
     The full name stays in the tab's tooltip and in the session.
   - The title is: the alias, else the shortened name, else the name.

## Results

Checked by hand by David, 2026-10-26: the strip scrolls with the wheel and the arrows, the ≡ list goes to the chosen tab, *Renommer l'onglet…* writes the alias and the tab takes it.
Writing `~/veafmct.yaml` back keeps its content, order and comments; the space before an end-of-line comment can change (yaml.v3 re-emits it).

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [The strip scrolls](FEAT-GO-VEAF-LOGS-TABS.md) | ✅ |
| 02 | [The list button](FEAT-GO-VEAF-LOGS-TABS.md) | ✅ |
| 03 | [Aliases, in the window and in the configuration](FEAT-GO-VEAF-LOGS-TABS.md) | ✅ |

One branch and one PR for the lot.

## Tickets, in full

## 01 — The strip scrolls

Status: ✅ done

The wheel over the strip scrolls it; ‹ › arrows at its right edge when the tabs overflow; the current tab is brought into view whenever it changes.

### Done when

- `internal/logview` tests for the offset: clamped to the overflow, the current tab brought into view from either side, no scroll without overflow.

## 02 — The list button

Status: ✅ done

A button at the strip's left, shown from two tabs on, opens a menu of the tabs' titles, the current one checked; choosing one makes it current and brings it into view.

### Done when

- The layout leaves room for the button only from two tabs on (tested in `internal/logview`); the menu checked by hand.

## 03 — Aliases, in the window and in the configuration

Status: ✅ done

- `servers.<server>.aliases.<log>` and a top-level `log_aliases.<path>` in `~/veafmct.yaml`.
- *Renommer l'onglet…* writes them, an empty name removes the alias, the rest of the file untouched (comments, order, other servers).
- Without an alias, an API's discovered logs lose the prefix all its servers share.

### Done when

- Tests: parsing the aliases; writing one into a file with comments and reading it back; removing one; a file created when there was none; the shared prefix cut only at a word boundary and only when every name keeps something.
