# FIX-GO-VEAF-LOGS-UI — the Go veaf-logs window, brought level with the Python one

Status: 🔄 in-progress

Origin: David, 2026-10-24, on a capture of the Go viewer opening a 59-line `dcs.log`: the filters panel spread its three groups over the whole height, the *tout / contexte / rien* buttons a hundred pixels tall and each category floating in an empty band.
The defect has been on `develop` since J3 (#1181); a journal with many categories fills the panel and hides it.
Part of the Go rewrite (FEAT-GO-VEAF-LOGS-ISOFUNCTIONAL), toolkit walk (ADR 0022); the Python viewer and the release pipeline are not touched.

## Method

Each change is checked on screen against the Python viewer, both opened on the same journals with `APPDATA` pointed at a scratch folder, by capturing the window alone (`PrintWindow` from a throwaway DPI-aware helper, never the desktop).
Measured before and after on a short journal (2 levels, 1 source, 1 noise family) and on `testdata/corpus/fuzz-1.log` (8 levels, 25 sources).

## Root cause of ticket 01

A walk `CustomWidget` — what `painted.go` draws the categories and the group buttons with — always reports a greedy layout item, in both directions.
A box layout ignores a maximum across its direction (an `HBox` gives every growable child its full height), and a composite holding a greedy child is greedy itself.
So each group was greedy and unbounded, and the three shared all the room the panel had; the `VSpacer` meant to take it comes after greedy widgets in walk's order and got nothing.

## Tickets

- [01 — The filters panel keeps its groups compact](tickets/01-side-panel-compact.md) · ✅
- [02 — The rest of the window against the Python](tickets/02-window-review.md) · ✅ a–f and h fixed, g and i left (David)
