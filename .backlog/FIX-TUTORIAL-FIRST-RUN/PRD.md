# FIX-TUTORIAL-FIRST-RUN — the walkthrough asks for three things that cannot be done

Status: 🔄 in-progress

Origin: Paluche's write-up of his first run through
[`doc/mission-maker/TUTORIAL.md`](../../doc/mission-maker/TUTORIAL.md), reported 2026-09-02 against
6.18.0. Five remarks, all of them verified in the code; three describe instructions that are
**impossible to follow**, one a missing confirmation, and one a runtime defect he found on the way.

## What he hit

| His step | What the page says | What actually happens |
|---|---|---|
| 5 | "create a mission … save it as `Mon-Premier-Vol.miz`" | that file already exists — step 4 built it. The page's own call-out says the file to reopen is the one at the root |
| 7 | "restore with `git checkout src/presets.yaml`" | the folder was never made a git repo — step 0 only calls it "your Git repository". The command cannot work |
| 8 | "uncomment the `COMBATZONE` block" | there is no such block: step 1 selects `--template minimal`, and COMBATZONE is `standard`/`full` only |
| 8 | — | nothing in the build output says the combat zone was picked up |
| 9 | "give an airfield to the blue coalition" | already true: adding a blue client slot does it, and the shipped `warehouses.yaml` needs no edit |

His fallback for step 7 made it worse, and that is a defect of its own: he re-ran `prepare`, whose
replace/keep menu does **not** cover `mission.yaml` — `--template` rewrites it unconditionally
([`prepare.py:281`](../../src/python/veaf-tools/veaf_tools/commands/prepare.py)), so his edits went
with it and he had to redo them.

## The runtime defect

The zone's smoke produced its confirmation message and no smoke, while illumination flares worked.
`spawnSmoke` schedules its only shell for **exactly `timer.getTime()`**
([`veafSpawnEffects.lua:68`](../../src/scripts/veaf/veafSpawnEffects.lua)); the illumination flare
is the only one of the four effects with a strictly positive delay. Until #828 (2026-08-28, shipped
in 6.18.0) this path went through `mist.scheduleFunction`, whose own 10 ms loop ran anything overdue
at the next tick and so could never drop a task; it now goes through one native
`timer.scheduleFunction` per task.

**Not proven**: whether DCS runs a function whose time has already elapsed. That is the whole
hypothesis, and it needs the game. The fix does not depend on the answer — a task due now or overdue
must still run, which is what MiST guaranteed and what this framework silently stopped guaranteeing.
One site is worse than "now": `veafSpawnEffects.lua:66` schedules an explosion one second in the
past.

## Constraints

- **Both languages** for every page touched, in lockstep.
- The walkthrough's promises are load-bearing: `validate` still reports **0 errors, 3 warnings** on
  the `standard` template (measured 2026-09-02, identical to `minimal`), and the `pipeline:` block
  is the same in both, so the build output does not change. Anything else the switch alters must be
  re-checked against the page, not assumed.
- No hand-written version numbers; `poetry run docs-check` passes.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Step 5 edits the mission it already built](tickets/01-step-5-reopen-the-built-miz.md) | docs |
| 02 | [Step 7 stops teaching git, and explains it instead](tickets/02-step-7-no-git-in-the-loop.md) | docs |
| 03 | [Step 8 gets a block it can actually uncomment](tickets/03-step-8-standard-template.md) | docs |
| 04 | [The build says which modules it picked up](tickets/04-build-reports-active-modules.md) | feat |
| 05 | [A task due now still runs](tickets/05-scheduler-floor.md) | fix |
| 06 | [`prepare --template` asks before rewriting `mission.yaml`](tickets/06-prepare-keeps-mission-yaml.md) | fix |

## Out of scope

- Rewriting `GUIDE.md` or the concept cards. Ticket 01 leans on
  [`concepts/build.md`](../../doc/mission-maker/concepts/build.md), which already documents the
  dated-filename rule correctly.
- Asking Paluche for his `dcs.log`. Raised and not taken up; ticket 05 ships the fix without it.
