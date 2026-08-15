# 01 — The test mission, and its documented contract

Status: ✅ done — 2026-08-15 (mission built + committed, anchor events verified in game, contract page shipped)

## Delivered 2026-08-15 — the committed mission

`test/veaf-tools/smoke-test-mission/` is the committed **source folder** (the `.miz` is a reproducible,
gitignored build artefact). Built through the normal pipeline (`prepare --theatre Syria`, then the MCP
`create_combat_zone` for the ground group + trigger zone, `add_player_slot` for the client slot), it
**validates clean** (a real player slot; coalitions set) and **builds clean**. It holds a client A-10C
slot, a two-tank ground group at the anchor, and a `SmokeZone` combat zone. `build.dev_mode` is not
persisted so the fixture stays machine-independent. Its README carries the theatre/anchor rationale.

The **anchor was verified in game** (not taken on trust): a unit spawned at `(-32220, 405386)` on a
`land` surface (~242 m) and blown up produced a death event the harness caught. The open-water
counter-example stays credited to `dcs-sms` in the contract page.
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

## Delivered 2026-08-05: the contract page

`doc/developer/smoke-harness.{md,en.md}`, both languages, in the mkdocs nav. It carries the
theatre, the anchor, and the open-water counter-example as the stated reason — plus an explicit
warning that **these coordinates are not verified here**, credited to dcs-sms, with the note that
this repo has already found two claims in their docs to be false.

**Outstanding**: the mission artefact itself, and killing a unit at that anchor to watch the
event arrive. Both need a DCS install.

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
