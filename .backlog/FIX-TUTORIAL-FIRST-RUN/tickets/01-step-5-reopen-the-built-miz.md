# 01 — Step 5 edits the mission it already built

Status: 🔄 in-progress

Type: docs

## The problem

Step 5 tells the reader to create a mission in the DCS editor and save it as
`Mon-Premier-Vol.miz` — the name of the file step 4 has just built. Two files claim one name, and
the page contradicts its own call-out twenty lines further down: *"le fichier à rouvrir dans
l'éditeur … c'est toujours celui de la racine du dossier"*.

Paluche's words: *"pourquoi créer une nouvelle mission ? … Il suffit de l'éditer et d'ajouter les
éléments indiqués. L'instruction « créer » une nouvelle mission a généré une certaine incertitude
chez moi en tant que novice des outils."*

He is right, and it is also the loop the page teaches everywhere else: the build strips the VEAF
triggers before re-injecting them, so reopening its own output is safe and repeatable.

## The naming trap next door

`build` only leaves the filename alone when it is given one ending in `.miz`
([`build.py:76`](../../../src/python/veaf-tools/veaf_tools/commands/build.py)):

| Typed | Written |
|---|---|
| `build Mon-Premier-Vol.miz` | `Mon-Premier-Vol.miz` |
| `build Mon-Premier-Vol` | `Mon-Premier-Vol_<YYYYMMDD>.miz` |
| `build` | `Mon-Premier-Vol_<YYYYMMDD>.miz` — name read from `mission.yaml` |

The tutorial always writes the `.miz` form, so it is correct as it stands. But a beginner dropping
the argument gets a dated file and can no longer find "the one at the root" the page keeps pointing
at. [`concepts/build.md`](../../../doc/mission-maker/concepts/build.md) documents the rule; the
walkthrough never mentions it.

## Definition of done

- [ ] Step 5 opens the `.miz` built at step 4 instead of creating a mission
- [ ] Step 4 says, in one sentence, that the filename is only preserved when the `.miz` is spelled
      out, and links to the build card for the dated form
- [ ] Both languages
- [ ] `poetry run docs-check` passes
