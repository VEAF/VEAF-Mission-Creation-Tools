# 05 — QRA fighters scramble and never engage

Status: 🧑 waiting-human

Type: fix

## The report

Tripack, 2026-09-03: *"réaction bizarre des avions de la QRA, tout se déclenche mais ils font leur
nav tranquilos"*, with an F10 screenshot showing the QRA airborne and unbothered. Then the part that
makes it a regression rather than a mission-design question:

*"la semaine passée ils étaient méchants, rien touché de mon côté depuis"*

Between the two, his toolchain went from 6.16.0 to 6.19.0 — the same jump the log records.

## What the log gives

Nothing. `VEAF-QRA` prints its load line four times and never speaks again: everything the manager
says about a deployment is `debug` or `trace`, and the log is at `INFO`. Red aircraft were flying
(a MiG-25PD and a MiG-23MLD are shot down at 19:14-19:15), but nothing ties them to the QRA.

## The hypothesis that was checked and ruled out

A cloned group flying a route stripped of its tasks is exactly what "they fly their nav quietly"
looks like, and MiST's `getGroupRoute` did return a task-less route unless asked otherwise — a
plausible thing for the port to have inherited.

It did not. [`veafDcsSpawner.getGroupRoute`](../../../src/scripts/veaf/veafDcsSpawner.lua) projects
`task` along with `alt`, `speed`, `airdromeId` and the rest, its docstring records that all eight
call sites wanted tasks, and `_spawn` assigns the projected route to `data.route` before submitting.
The QRA's DCS-group branch goes through that path
([`veafQraCore.lua:1042`](../../../src/scripts/veaf/veafQraCore.lua)).

So the mechanism is elsewhere, and there is no second candidate yet.

## What is needed before this can be worked

1. **Which QRA branch the mission uses** — a DCS group placed in the editor, or a VEAF command. The
   two spawn through entirely different code.
2. **A run with the VEAF logs at `debug`**, which is what makes `VeafQRACore:deploy` legible at all.
3. **Tripack's `Snowfox_20260903.miz`**, asked for on 2026-09-05.
4. A worthwhile bisect once the shape is known: 6.16.0 → 6.19.0 covers
   [#840](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/840) (VEAF creates its own groups),
   [#842](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/842) (the spawn builder) and
   [#900](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/900) (a clone always renames its
   units) — all three on the exact path a QRA scramble takes.

## Definition of done

- [ ] The QRA's passivity is reproduced
- [ ] Its cause is named, with the measurement that shows it
- [ ] Fix, plus a test asserting **the wiring** — that a scrambled group reaches DCS carrying the
      task that makes it fight — and not merely that the handler was called
- [ ] `luacheck` + `stylua --check` clean; Lua coverage floor bumped per the ratchet policy
