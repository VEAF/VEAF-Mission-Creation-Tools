# DOC-TUTORIAL — nothing teaches VMCT, it only documents it

Status: ✅ done · archived 2026-09-28

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
| 01 | [The map — one page, the whole territory](DOC-TUTORIAL.md) | docs |
| 02 | [The cards — one concept, one page](DOC-TUTORIAL.md) | docs |
| 03 | [The walkthrough — an entire mission, end to end](DOC-TUTORIAL.md) | docs |

## Out of scope

- Rewriting `GUIDE.md`. It stays the reference; the new pages link **into** it rather than
  restating it. If the guide turns out to contradict them, fix the guide — but that is a finding to
  report, not a rewrite to undertake here.

---

## Tickets, in full

## 01 — The map: one page, the whole territory

Status: ✅ done

Type: docs · Files: `doc/mission-maker/DISCOVER.md` + `.en.md` (name it as you see fit), `mkdocs.yml`

### What it is

Ten minutes of reading that answer "what is this thing, and how do the pieces fit". Not how to do
anything — that is tickets 02 and 03.

Cover, with one short example each: the mission folder and what lives in it, what `build` actually
does, `mission.yaml` and its `modules:`, `custom_scripts:`, radio presets, dynamic slots, combat
zones, and where the VEAF Lua scripts come in at runtime.

The reader should finish able to say what each piece is for, and follow a link to the card that
teaches it.

### Definition of done

- [x] One page, both languages, in the `nav` with its `nav_translations`
- [x] Every concept named links to its card (ticket 02) or to the reference
- [x] No version number written by hand
- [x] `poetry run docs-check` passes

---

## 02 — The cards: one concept, one page

Status: ✅ done

Type: docs · Files: a `doc/mission-maker/concepts/` folder, both languages, `mkdocs.yml`

### What they are

One short page per concept — aim for twenty to forty lines — each answering "how do I write this
one thing?", with a minimal example that works and a link to the reference for the rest.

A reasonable first set, to adjust as you write: the mission folder, `mission.yaml` and its modules,
`custom_scripts` (and load staging), radio presets, dynamic slots and warehouses, combat zones,
spawnable groups, weather variants. Add or merge as the material dictates — the list is a starting
point, not a contract.

### Definition of done

- [x] Each card: what it is, the smallest example that works, one gotcha, a link to the reference
- [x] Every example verified against `src/defaults/mission-folder/` or a test — a wrong example is
      worse than no card
- [x] Both languages, all in the `nav`
- [x] Explicit English anchors on anything linked from another page
- [x] `poetry run docs-check` passes

---

## 03 — The walkthrough: an entire mission, end to end

Status: ✅ done

Type: docs · Files: `doc/mission-maker/TUTORIAL.md` + `.en.md`, `mkdocs.yml`

### What it is

One thread, from an empty `.miz` to a mission that runs. Each step gives the exact command or the
exact YAML, says what should happen, and says how to tell it worked.

A workable spine, to adapt: create the mission folder from the defaults · look at what was
generated · enable a couple of VEAF modules · build and fly it · add a playable slot · add a radio
preset · add a combat zone and trigger it in game · add a dynamic slot · rebuild.

Every concept is introduced where it is first needed, with a link to its card (ticket 02) rather
than a full explanation inline.

### Definition of done

- [x] A reader who knows the Mission Editor and nothing about VMCT ends up with a mission that
      loads and works
- [x] Every command and every YAML block is real — run them; a step that does not work is a reader
      lost for good
- [x] Says what to check in game after each step, not only what to type
- [x] Both languages, in the `nav`
- [x] `poetry run docs-check` passes

### Watch out

Keep it "pas trop détaillé", as asked. The temptation is to explain everything at each step; the
cards exist precisely so this page can stay a thread. If a step needs three paragraphs of
background, that background belongs in a card.

---
