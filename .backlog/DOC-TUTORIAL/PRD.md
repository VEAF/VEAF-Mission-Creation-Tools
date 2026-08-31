# DOC-TUTORIAL — nothing teaches VMCT, it only documents it

Status: ⬜ ready

Origin: VEAF meeting, 2026-08-30 ("ajouter un tuto pas trop détaillé pour introduire tous les
concepts avec des exemples"). Shape chosen by David on 2026-08-31: **all three levels**.

## The gap

`doc/mission-maker/GUIDE.md` is 51 KB of reference. `MIGRATION_GUIDE.md` addresses people who
already have a v5 mission. Neither takes somebody who knows the DCS Mission Editor and has never
opened VMCT, and gets them to a working mission.

## The three levels, and why all three

Asked to choose one, David asked for all three — they answer different moments, and each fails
alone:

1. **The map** — one page, ten minutes: what a mission folder is, what the build does, how modules,
   `custom_scripts`, presets, dynamic slots and combat zones relate. Answers "what is this?" and
   nothing else. Alone, the reader understands and still cannot do.
2. **The cards** — one short page per concept, twenty lines, each with a minimal example that
   works. Answers "how do I write this one thing?". Alone, it duplicates the reference.
3. **The walkthrough** — one thread from an empty `.miz` to a mission that runs: create the folder,
   enable a module, add a slot, a radio preset, a combat zone, build, test. Every concept appears
   where it is needed, with the exact YAML and what to expect in game. Answers "get me started".
   Alone, it is long and hard to come back to.

The map links into the cards; the walkthrough links to a card whenever it uses a concept.

## Constraints

- **Both languages**, in the `nav`, with `nav_translations` — a page reachable only by an inline
  link is invisible to anyone browsing the menu (see the doc rules in `CLAUDE.md`).
- **Explicit English anchors** on any section linked from another page.
- **Every example must actually work.** A tutorial whose YAML is wrong is worse than none. Prefer
  examples lifted from `src/defaults/mission-folder/` and from the tests, and check the ones you
  write against the real scaffold.
- **No hand-written version numbers.**
- `poetry run docs-check` passes.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [The map — one page, the whole territory](tickets/01-the-map.md) | docs |
| 02 | [The cards — one concept, one page](tickets/02-the-cards.md) | docs |
| 03 | [The walkthrough — an entire mission, end to end](tickets/03-the-walkthrough.md) | docs |

## Out of scope

- Rewriting `GUIDE.md`. It stays the reference; the new pages link **into** it rather than
  restating it. If the guide turns out to contradict them, fix the guide — but that is a finding to
  report, not a rewrite to undertake here.
