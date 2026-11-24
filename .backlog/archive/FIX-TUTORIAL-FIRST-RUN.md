# FIX-TUTORIAL-FIRST-RUN — the walkthrough asks for three things that cannot be done

Status: ✅ done — every ticket shipped in #908; ticket 05's smoke verified in game 2026-10-03 (R12) · archived 2026-11-24

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
| 01 | [Step 5 edits the mission it already built](FIX-TUTORIAL-FIRST-RUN.md) | docs |
| 02 | [Step 7 stops teaching git, and explains it instead](FIX-TUTORIAL-FIRST-RUN.md) | docs |
| 03 | [Step 8 gets a block it can actually uncomment](FIX-TUTORIAL-FIRST-RUN.md) | docs |
| 04 | [The build says which modules it picked up](FIX-TUTORIAL-FIRST-RUN.md) | feat |
| 05 | [A task due now still runs](FIX-TUTORIAL-FIRST-RUN.md) | fix |
| 06 | [`prepare --template` asks before rewriting `mission.yaml`](FIX-TUTORIAL-FIRST-RUN.md) | fix |

## Landed 2026-09-02 — #908, merged on green CI

All six tickets are implemented and merged. The lot stays `🧑 waiting-human` for **one observation
that needs the game**, tracked as item R12 in [`DCS-SESSION-TODO.md`](../../DCS-SESSION-TODO.md):
does the scheduler floor actually make a combat zone's smoke appear? That also settles the
hypothesis behind ticket 05 — whether DCS discards a call scheduled for a time already elapsed — and
nothing on a workstation can answer it.

Sourcery's weekly 250 000-character budget was spent when the PR opened, so it answered with its
rate-limit message instead of a review. Merged on CI alone, David's call, to be re-read later.

Two things worth keeping from the measurements:

- `standard` reports the **same three warnings and zero errors** as `minimal`, word for word, and
  the `pipeline:` block is identical in both — which is what made switching the tutorial's tier a
  contained change rather than a rewrite of steps 3 and 4.
- The reported-modules line was **rendered before being quoted** in the tutorial, and that is how
  `NAMEDPOINTS (0), SHORTCUTS (0)` was caught: an optional list reporting zero reads as a problem
  where there is none. Only the five modules a list *defines* are counted.

## Out of scope

- Rewriting `GUIDE.md` or the concept cards. Ticket 01 leans on
  [`concepts/build.md`](../../doc/mission-maker/concepts/build.md), which already documents the
  dated-filename rule correctly.
- Asking Paluche for his `dcs.log`. Raised and not taken up; ticket 05 ships the fix without it.

## In-game check — 2026-10-03

From `FIX-IN-GAME-SESSION-2026-10-03`.

Ticket 05 verified (R12): `spawnSmoke` with a valid colour makes smoke, and the combat-zone smoke
rises at the zone (David). A marker's `_spawn smoke` failed for another reason — the colour names,
fixed in `FIX-IN-GAME-SESSION-2026-10-03` ticket 01. STTS left on without SRS logs two info lines and nothing else.

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**Paluche's first run through the walkthrough hit three instructions that cannot be followed**, reported 2026-09-02 against 6.18.0 and all three verified: step 5 has him create a mission under the name step 4 already built, contradicting the page's own call-out; step 7 restores a file with `git checkout` in a folder the walkthrough never made a repository; step 8 uncomments a `COMBATZONE` block that `--template minimal` does not write at all. Two more findings ride along — the build acknowledges no module it reads, so a combat zone that resolved to nothing looks like a healthy build, and `prepare --template` rewrites `mission.yaml` past its own replace/keep menu, which is how his edits died while he was trying to restore a different file. Plus the defect he found in game: zone smoke confirms and never appears, because `spawnSmoke` schedules its only shell for exactly `timer.getTime()` and #828 swapped MiST's overdue-tolerant loop for one native timer call per task — the illumination flare that worked is the only effect with a strictly positive delay. Whether DCS drops a past-due call is **unproven** and needs the game; the fix restores the contract MiST held either way. **Landed 2026-09-02** in #908, merged on green CI (Sourcery's weekly budget was spent, so no third-party review — to be re-read later). Held at waiting-human for one observation that needs the game, item R12 in `DCS-SESSION-TODO.md`: does the scheduler floor actually make the smoke appear?

## Tickets, in full

## 01 — Step 5 edits the mission it already built

Status: ✅ done

Type: docs

### The problem

Step 5 tells the reader to create a mission in the DCS editor and save it as
`Mon-Premier-Vol.miz` — the name of the file step 4 has just built. Two files claim one name, and
the page contradicts its own call-out twenty lines further down: *"le fichier à rouvrir dans
l'éditeur … c'est toujours celui de la racine du dossier"*.

Paluche's words: *"pourquoi créer une nouvelle mission ? … Il suffit de l'éditer et d'ajouter les
éléments indiqués. L'instruction « créer » une nouvelle mission a généré une certaine incertitude
chez moi en tant que novice des outils."*

He is right, and it is also the loop the page teaches everywhere else: the build strips the VEAF
triggers before re-injecting them, so reopening its own output is safe and repeatable.

### The naming trap next door

`build` only leaves the filename alone when it is given one ending in `.miz`
([`build.py:76`](../../src/python/veaf-tools/veaf_tools/commands/build.py)):

| Typed | Written |
|---|---|
| `build Mon-Premier-Vol.miz` | `Mon-Premier-Vol.miz` |
| `build Mon-Premier-Vol` | `Mon-Premier-Vol_<YYYYMMDD>.miz` |
| `build` | `Mon-Premier-Vol_<YYYYMMDD>.miz` — name read from `mission.yaml` |

The tutorial always writes the `.miz` form, so it is correct as it stands. But a beginner dropping
the argument gets a dated file and can no longer find "the one at the root" the page keeps pointing
at. [`concepts/build.md`](../../doc/mission-maker/concepts/build.md) documents the rule; the
walkthrough never mentions it.

### Definition of done

- [x] Step 5 opens the `.miz` built at step 4 instead of creating a mission
- [x] Step 4 says, in one sentence, that the filename is only preserved when the `.miz` is spelled
      out, and links to the build card for the dated form
- [x] Both languages
- [x] `poetry run docs-check` passes

## 02 — Step 7 stops teaching git, and explains it instead

Status: ✅ done

Type: docs

### The problem

Step 7 has the reader replace `src/presets.yaml` with a minimal file, then restore it with
`git checkout src/presets.yaml`. Nothing in the walkthrough ever ran `git init` or committed
anything — step 0 merely calls the folder "your Git repository" — so the command cannot work.

Paluche's words: *"je n'ai pas réussi à utiliser la commande « git checkout… » … J'ai relancé alors
la commande « prepare » qui m'a alors demandé si je voulais garder, remplacer certains fichiers.
Ne sachant pas trop que faire, j'ai demandé de tout remplacer. J'ai alors remodifier le
mission.yaml."*

The fallback the page pushed him towards cost him his `mission.yaml` edits. That is ticket 06.

### The decision

Version control is an advanced tool and does not belong in the middle of a first walkthrough. The
step restores by **copy**, which needs nothing installed:

```powershell
Copy-Item src\presets.yaml src\presets.yaml.bak
# … experiment …
Copy-Item src\presets.yaml.bak src\presets.yaml -Force
```

Git keeps a place, but as a **concept worth knowing later**, in a call-out of its own rather than as
a command to type — with a link to Pro Git, which is official, free and translated:

- FR page → <https://git-scm.com/book/fr/v2>
- EN page → <https://git-scm.com/book/en/v2>

Step 0's "ce sera votre dépôt Git" is the other half of the confusion and goes with it: the folder
*can* become one, it is not one.

### Definition of done

- [x] No `git` command anywhere in the walkthrough
- [x] Step 7 restores by copy
- [x] A call-out explains what version control buys a mission maker, and links to Pro Git in the
      page's own language
- [x] Step 0 no longer asserts the folder is a git repository
- [x] Both languages
- [x] `poetry run docs-check` passes

## 03 — Step 8 gets a block it can actually uncomment

Status: ✅ done

Type: docs

### The problem

Step 8 says *"décommentez le bloc `COMBATZONE`"*. There is no such block. Step 1 selects
`--template minimal`, and COMBATZONE belongs to `standard`/`full`
([`mission_template.py:205`](../../src/python/veaf-tools/veaf_libs/mission_template.py)); the
generator's own header states that *"modules outside the set are omitted"*.

Paluche's words: *"Je ne pouvais dès lors pas la décommenter. J'ai alors copié le bloc Combatzone
présent dans le tuto et je ne savais pas trop à quel endroit l'insérer dans le mission.yaml. Un
grand moment de solitude !"*

He also had no confirmation at build time: *"je n'ai vu aucun message concernant la création de la
Combatzone"*. That is ticket 04; this ticket owes the step a "how you know" that is true today.

### The decision (David, 2026-09-02)

Step 1 switches to `--template standard`, so that "uncomment" describes reality. Measured on
2026-09-02 in a throwaway folder:

- `standard` writes the `COMBATZONE` block commented, under a `# ── Combat ──` heading
- `validate` reports **0 errors, 3 warnings** — the same three, word for word, as `minimal`, so
  step 3 stands unchanged
- the `pipeline:` block is identical in both files, so the build output does not change

Three consequences to carry through:

1. The shipped block says `training: false`; the step wants `true`. Say so.
2. `standard` also turns on STTS, CSAR and CTLD, so the F10 menu at step 6 holds more than the page
   promises. **STTS with no SRS installed is unverified** — no DCS on this machine; flag it rather
   than claim it is harmless.
3. Step 2 quotes the `modules:` block; the `standard` one is longer and the excerpt must be
   refreshed.

Uncommenting must be explained as *removing the `#` without touching the spaces* — the block is
written `#   COMBATZONE:` and lands at two spaces of indent.

### Step 9 rides along

Step 9 tells the reader to give an airfield to the blue coalition. Adding a blue client slot at
step 5 already does it, and the shipped `src/warehouses.yaml` enables dynamic slots on every
coalition-owned airbase — its own header says so. Paluche: *"Je n'ai donc rien eu à faire."* The
step becomes a check, not an action.

### Definition of done

- [x] Step 1 uses `--template standard`, and says what the tier buys
- [x] Step 2's `modules:` excerpt matches what `standard` writes
- [x] Step 8 uncomments a block that exists, states the `#`-only edit, and flips `training`
- [x] Step 8 has a "how you know" that holds before DCS is launched
- [x] Step 6 does not promise a menu smaller than the one `standard` produces
- [x] Step 9 reads as a verification
- [x] Both languages
- [x] `poetry run docs-check` passes

## 04 — The build says which modules it picked up

Status: ✅ done

Type: feat

### The problem

A mission maker who adds a module to `mission.yaml` has no way to tell from the build whether it was
read. The only line about the generated configuration is

> Generated 'veaf-config.lua' from mission.yaml

([`mission_builder_worker.py:2488`](../../src/python/veaf-tools/mission_builder/mission_builder_worker.py)).
Paluche added a combat zone and got no acknowledgement of it; the next thing that could have told him
anything was the F10 menu, in game, after a load.

`validate` is not the answer on its own: it is silent on success by design, so "0 errors" says the
YAML is coherent, not that COMBATZONE reached the mission.

### What to log

One `info` line after `veaf-config.lua` is written, naming the modules actually active, and for the
ones that carry a list, how many entries they carry — combat zones, QRA definitions, assets,
airwave zones, sanctuary zones. Counts are what catch the real mistake: a `combat_zones:` list that
resolved to nothing looks exactly like a healthy build today.

Rules:

- Report what was **resolved**, not what the file contains, so the line cannot drift from the Lua.
- No line per module; one line the eye can take in.
- Say nothing extra when nothing is configured — a message every build prints is a message nobody
  reads (the shape `reportGroupsExcludedByName` already uses).

### Definition of done

- [x] The build reports active modules, with entry counts for the list-shaped ones
- [x] The message is in both locale catalogues
- [x] Unit test on the reporting, including the "nothing configured" case
- [x] `--cov-fail-under` bumped per the ratchet policy in `CLAUDE.md`
- [x] Python gate clean (`ruff check`, `ruff format --check`, `mypy`)

## 05 — A task due now still runs

Status: ✅ done — verified in game 2026-10-03

Type: fix

### The report

Paluche activated a combat zone, asked for smoke, got the confirmation message and no smoke.
Illumination flares from the same menu worked.

*"l'activation de la smoke sur la zone n'a pas fonctionné. J'ai bien un message qui confirme
l'activation mais la fumée n'apparaît pas (contrairement aux fussées éclairantes)."*

### What the code says

`VeafCombatZone:popSmoke` → `veafSpawn.spawnSmoke`, and with the default `shells = 1` the one and
only shell is scheduled for **exactly `timer.getTime()`**
([`veafSpawnEffects.lua:68`](../../src/scripts/veaf/veafSpawnEffects.lua)). The confirmation he
saw (`combatzone.smoke_requested`) is emitted *after* `spawnSmoke` returns, so nothing raised: the
effect was scheduled and never appeared.

Every site in the framework that can schedule at or before "now" is in that one file:

| Site | Time |
|---|---|
| `spawnBomb`, first shell | `timer.getTime()` |
| `spawnSmoke`, single shell | `timer.getTime()` |
| `spawnSignalFlare`, single shell | `timer.getTime()` |
| `spawnSmoke`, the explosion under a multi-shell plume (`:66`) | `timer.getTime() - 1` — **in the past** |
| `spawnIlluminationFlare` | `timer.getTime() + 0.75` at the earliest |

The illumination flare — the one that worked — is the only one with a strictly positive delay.

Until #828 (2026-08-28, shipped in 6.18.0) this went through `mist.scheduleFunction`: MiST ran its
own task list from a 10 ms loop and executed anything overdue at the next tick, so a past-due task
was never lost. It now goes through one native `timer.scheduleFunction` per task
([`veafScheduler.lua:128`](../../src/scripts/veaf/veafScheduler.lua)).

### What is not proven

Whether DCS runs a function whose scheduled time has already elapsed. That is the hypothesis, and
settling it needs the game — there is no DCS on this machine and David had no mission running when
asked (2026-09-02). The fix is therefore **defensive on the cause and correct on the contract**: a
task due now or overdue must still run, which MiST guaranteed and this framework quietly stopped
guaranteeing. If DCS turns out to honour past times, the floor costs one tick and changes nothing.

### The fix

`veafScheduler.scheduleFunction` clamps the first run to no earlier than the next tick, restoring
MiST's behaviour for every caller instead of patching three call sites. `veafSpawnEffects.lua:66`
then means "just before the smoke" rather than "one second ago", which is what it was after.

### Definition of done

- [x] A task scheduled for `timer.getTime()`, or earlier, is armed for a time in the future
- [x] Repetition and stop time keep their current semantics
- [x] Unit tests: due-now, overdue, comfortably-future (unchanged), and one asserting `spawnSmoke`
      reaches `trigger.action.smoke` with a usable point — the wiring, not the handler
- [x] `luacheck` + `stylua --check` clean
- [x] Lua coverage floor bumped per the ratchet policy

## 06 — `prepare --template` asks before rewriting `mission.yaml`

Status: ✅ done

Type: fix

### The problem

`prepare` protects every existing file behind a four-way menu — replace this / keep this / replace
all / keep all ([`helpers.py:238`](../../src/python/veaf-tools/veaf_tools/helpers.py)) — and then
walks straight past its own answer:

```python
if enabled_modules is not None:
    (p_mission_folder / "mission.yaml").write_text(generate_mission_yaml(enabled_modules), ...)
```

([`prepare.py:281`](../../src/python/veaf-tools/veaf_tools/commands/prepare.py)) —
`enabled_modules` is set whenever `--template` is passed, and the write is unconditional. "Keep all"
does not save `mission.yaml`.

This is the most valuable file in the folder and the one a mission maker edits by hand: module
configuration, security block, build settings. Paluche lost his edits to it while trying to restore
an unrelated file, and only found out because he had to redo them.

### The fix

The template write goes through the same decision as every other existing file: on an existing
`mission.yaml`, ask (or honour a remembered "replace all" / "keep all", or `--force`). A fresh
folder is unaffected — there is nothing to lose and nothing to ask.

The prompt must say what is at stake; `mission.yaml` is not `spawnables.yaml`. It is also the one
file where the answer decides whether `--template` did anything at all, so a kept file deserves a
line saying the template was **not** applied.

### Definition of done

- [x] `prepare --template` on a folder with an existing `mission.yaml` does not overwrite it silently
- [x] `--force` still replaces, non-interactive runs still keep (the existing contract of
      `_ask_replace`)
- [x] Declining leaves the file byte-for-byte untouched, and the run says the template was not
      applied
- [x] A fresh folder still gets its generated `mission.yaml` with no prompt
- [x] Unit tests for all four paths
- [x] `--cov-fail-under` bumped per the ratchet policy
- [x] Python gate clean
