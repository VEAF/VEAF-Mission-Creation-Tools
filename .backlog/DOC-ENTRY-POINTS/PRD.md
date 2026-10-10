# DOC-ENTRY-POINTS — the main ways in should be obvious

Status: ✅ done — shipped in #1112

Origin: David, 2026-10-09 — "I can't easily find the AI entry point in the docs; it should be obvious, and so should every main entry point".

## What was wrong

- The home page opened on a table of three roles; the AI assistant appeared nowhere on it, nor did the tutorial or the way to take over an existing mission.
- In the menu, the AI assistant came thirteenth under Mission Maker, after "Read the DCS logs", and five Mission Maker labels showed in English on the French site (no `nav_translations` entry).

## Decided (David, 2026-10-09)

- a. The home page opens on a grid of "I want to…" cards: fly, discover VMCT, my first mission, create with an AI, take over a mission, get help. The developer guide keeps a link below.
- b. The Mission Maker overview opens on the same kind of grid, four cards.
- c. In the menu, the AI pages move right after the tutorial, as "Create with an AI" and "What to ask the AI".
- Not done: a banner on every page — a theme override, a "new" that stays for ever, and it would single out one entry point.

## Tickets

- [01 — Home page cards](tickets/01-home-cards.md)
- [02 — Mission Maker overview cards](tickets/02-mission-maker-cards.md)
- [03 — Menu order and French labels](tickets/03-menu.md)
