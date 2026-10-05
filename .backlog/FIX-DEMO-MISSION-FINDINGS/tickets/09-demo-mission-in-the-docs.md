# 09 — The docs point to the v6 demo mission, and say what it is for

Status: ⬜ ready
Type: doc
Files: `README.md` (l. 55, 195), `doc/index.md` / `.en.md` (l. 69), `doc/mission-maker/GUIDE.md` / `.en.md` (l. 163-166, 1153), the module pages, `CLAUDE.md` / contributing rules, `.prompts/`

## What is wrong

Every link still points to the old `VEAF/VEAF-Demo-Mission` (a v5 conversion, to be archived), and the GUIDE tells makers to fork it to start a mission — `scaffold_mission` / `prepare` is the v6 way.
Nothing says that a demo exists where every feature can be tried in game, with a guided tour, nor that it is the pre-release check.

## What to write

- Replace the links with `https://github.com/VEAF/VEAF-Demo-Mission-v6`, and stop presenting a fork as the way to start (the scaffold is).
- A short « Mission de démo / Demo mission » section (index, pilot guide, mission-maker guide): what it shows, the guided tour (F10 > Autre > Visite guidée / Guided tour), the FR and EN builds.
- On each module page whose feature the demo shows, one line « Voir en jeu : étape NN de la mission de démo » linking to the matching README section (the step list is `tour/steps.yaml` in the demo repository).
- In the repository's rules (`CLAUDE.md` / contributing): a new feature adds its step to the demo (its `CLAUDE.md` says how), and a release runs the demo's `docs/recette.md`.
- Keep the old repository's links only where they are history (`mission-editing-mcp.md` l. 311 cites a polygon read in the old demo's `.miz`).

## Done when

No live link to `VEAF-Demo-Mission` (v5) outside history; FR and EN pages in step; `mkdocs build` clean.
