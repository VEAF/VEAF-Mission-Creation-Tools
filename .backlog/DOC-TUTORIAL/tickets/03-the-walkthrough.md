# 03 — The walkthrough: an entire mission, end to end

Status: ⬜ ready

Type: docs · Files: `doc/mission-maker/TUTORIAL.md` + `.en.md`, `mkdocs.yml`

## What it is

One thread, from an empty `.miz` to a mission that runs. Each step gives the exact command or the
exact YAML, says what should happen, and says how to tell it worked.

A workable spine, to adapt: create the mission folder from the defaults · look at what was
generated · enable a couple of VEAF modules · build and fly it · add a playable slot · add a radio
preset · add a combat zone and trigger it in game · add a dynamic slot · rebuild.

Every concept is introduced where it is first needed, with a link to its card (ticket 02) rather
than a full explanation inline.

## Definition of done

- [ ] A reader who knows the Mission Editor and nothing about VMCT ends up with a mission that
      loads and works
- [ ] Every command and every YAML block is real — run them; a step that does not work is a reader
      lost for good
- [ ] Says what to check in game after each step, not only what to type
- [ ] Both languages, in the `nav`
- [ ] `poetry run docs-check` passes

## Watch out

Keep it "pas trop détaillé", as asked. The temptation is to explain everything at each step; the
cards exist precisely so this page can stay a thread. If a step needs three paragraphs of
background, that background belongs in a card.
