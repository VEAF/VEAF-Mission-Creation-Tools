# 01 — The test mission, and its documented contract

Status: ⬜ ready
Type: feat
Files: a committed test `.miz` (or its `mission.yaml` + build recipe), `docs/` contract page

## Why the contract matters more than the mission

Anyone can make an empty mission. The part that is hard to reacquire is **where to put it and why**,
and `dcs-sms` documents theirs: theatre **Syria**, anchor **`(-32220, 405386)`**, described as "empty
desert, far from anything, but DCS does process events there".

The counter-example is the whole point: at **`(-50000, -50000)`**, over open water, **DCS silently
drops death events**. A harness whose units die without the engine reporting it produces confident
false failures. Nobody deduces that; you lose a day to it or you are told.

So this ticket's deliverable is half artefact, half written rationale — and the rationale is the half
that must not be skipped.

## The mission

- [ ] Built from a committed `mission.yaml` through the normal pipeline rather than hand-made in the
      editor, so it is reproducible and so it exercises the toolchain on the way in.
- [ ] Theatre and anchor chosen and **justified in writing**. Take Syria + their anchor unless there
      is a reason not to; if a different theatre is needed (a WWII check, say), state the anchor for
      that one too and verify events fire there.
- [ ] Minimal but not empty: a human-playable slot (a mission with no client slot behaves
      differently), a small ground group, a trigger zone, and whatever the first assertions need.
- [ ] The VEAF scripts injected the normal way, so what runs is what ships.

## The contract page

- [ ] Theatre, anchor, and **why that anchor** — including the open-water event-dropping trap as the
      stated reason, credited to the dcs-sms study.
- [ ] What the mission contains and what may be added without invalidating existing assertions.
- [ ] How to run it, and what "no DCS installed" looks like.
- [ ] Verify, in game, that events actually fire at the chosen anchor — kill a unit, watch the event
      arrive. **Do not take their coordinates on trust**: this repo has twice found claims in that
      project's docs to be false (the hook/editor VM claim, the "dies at the main menu" claim).

## Acceptance criteria

- [ ] The mission builds from its `mission.yaml` with `validate` + `build` clean.
- [ ] A death event observed at the chosen anchor, in game, and the observation recorded.
- [ ] The contract page passes `docs-check` (links, anchors, both languages if it is user-facing).
