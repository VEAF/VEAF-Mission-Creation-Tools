# 10 — Ship the drawing shapes now that their layout is measured

Status: ✅ done 2026-08-15 — circle/oval/free ship (measured from bridge-Syria-editeur.miz); arrow and
icon stay refused, each with its own reason (arrow needs an in-game outline round-trip, icon needs an
icon-name catalogue).
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/map_drawings.py`, the mission-maker action catalogue
(both languages), tests

Depends on: [07](07-map-drawings.md), whose measurement table this spends.

## Why now

Ticket 07 shipped three shapes and refused five by name, on the rule that a field layout is read out
of a real `.miz` rather than invented. **That data now exists** — David drew one of each in the editor
on 2026-08-15 — so the reason for the refusal is gone for most of them.

## What ships, and what does not

- **`circle`** (`radius`), **`oval`** (`angle`, `r1`, `r2`) and **`free`** (`points`, relative to the
  anchor exactly like `line`): a handful of fields each, no open question. These ship.
- **`arrow`**: ships **only** if a round-trip settles the `points` question first — the editor stores
  `length` + `angle` **and** an 8-point outline. Write the parameters without the outline, save in the
  editor, and see whether DCS recomputes it. If it does not, the action must compute the outline, which
  is a different piece of work and deserves its own ticket rather than a guess.
- **`icon`**: does **not** ship here. It needs a `file` (`P91000007.png` in the sample), an opaque name
  from the editor's icon set, and nothing in this repository lists the valid ones. Shipping it means
  either a catalogue nobody has, or an unvalidated string that renders as nothing when wrong — the
  silent failure this whole ticket family exists to avoid. Keep it refused, and say why in the refusal.

## Careful

The refusal list is not decoration: `chevron` sat in it until 2026-08-15 and turned out not to exist.
Whatever stays refused must name a shape the editor actually draws, and the test added with that fix
asserts a shape is either shipped or refused, never both.

## TDD

- One test per new shape asserting the **exact** field set from the measured table, so a missing key
  fails rather than producing a drawing DCS drops.
- `free` anchors its first point at `{0,0}` like `line` — the anchoring bug this module was written to
  prevent, so it gets its own assertion.
- `icon` and `arrow` are still refused, each with a message naming its reason.

## Acceptance criteria

- [x] `circle`, `oval`, `free` ship, documented in both locales.
- [~] `arrow` **deferred** to its own future ticket rather than shipped or guessed: the editor stores a
      computed 8-point outline beside its `length`/`angle`, and whether DCS recomputes it needs a DCS
      round-trip nobody has run yet. Refused with that exact reason.
- [x] `icon` stays refused with a reason a maker can act on (needs a `file` from the editor's icon set,
      which nothing here enumerates).
- [x] Full Python gate green; coverage ratchet respected.
