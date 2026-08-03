# 08 — a build-time choice between the picture and plain text

**Status:** ✅ done — 2026-08-02. Asked for by David after flying ticket 05; not yet seen in game.

The generated picture is the nice version and the expensive one: seven states of the six-step F-16C
checklist weigh 68 KB, and a forty-step checklist would run past half a megabyte. A mission maker who
cares more about the `.miz` than about the looks should be able to say so.

**This is a build option, not an in-game toggle.** The point is that in text mode the build generates
**no image at all** — nothing rendered, nothing embedded, nothing in `mapResource`. A per-pilot
toggle would have to embed the pictures anyway and would save nothing.

## Configuration

```yaml
modules:
  ASSIST:
    enabled: true
    display: text        # or `picture`, the default
    checklists: [f16c-cold-start]
```

`picture` when absent — the behaviour shipped today does not change under anyone's feet. An
unrecognised value fails the build, like every other checklist mistake: a typo that silently falls
back to the expensive mode is exactly what a mission maker would not notice.

## Runtime

**The engine infers the mode from the data, with no extra field.** A checklist emitted without
`images` is a text-mode checklist, because that is precisely what text mode means. The engine already
tolerates a missing `images` table (it simply shows nothing); this ticket gives that case a behaviour
instead — on every step change, one short message carrying the current instruction and the progress
(`Étape 3/6 : …`).

Two consequences to handle:

- **The "hide / show the checklist" entry has no meaning in text mode** — there is no picture to hide.
  Its `groupFilter` must also require the session to have images.
- The event texts (validated, skipped, complete) are unchanged. In text mode a step change therefore
  produces two lines: what was just done, then what to do next. That reads correctly and is cheaper
  than inventing a combined message.

## Tests

Python: `display: text` renders nothing and embeds nothing, while the checklist is still registered;
`display: picture` and an absent key behave identically; an unknown value fails the build.

Lua: a checklist with no `images` sends the current-instruction message on each step change and never
calls `a_out_picture_u`; one with `images` behaves as today and sends no such message; the toggle
entry is hidden in text mode.

## Definition of done

- Both modes work in game, and text mode produces a `.miz` with no `assist-*.png` in it.
- FR + EN catalog entry for the current-instruction message.
- `src/defaults/mission-folder/mission.yaml` documents the key (`CLAUDE.md` §9.7).
- Documentation in both languages says plainly what the trade is: nice and heavy, or light and plain.
