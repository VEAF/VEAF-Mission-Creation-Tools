# FIX-CONVERT-OTHER-UPDATE-BLIND-SPOTS — what a Foothold refresh changes without saying so

Status: ✅ done · archived 2026-09-28

Origin: the 2026-08-25 refresh of the five VEAF Foothold missions onto Lekaa's 4.7.0
(GCW 5.7.0). Every defect below was met on that run, on real missions, and re-verified
against `develop` at `75aa264d` before being written down.

## The one sentence they share

`convert-other --update` is the command the whole Foothold moulinette rests on, and **it
reports nothing**: it collects what changed upstream into two lists the report never renders,
leaves behind a script the upstream release removed, and never reconciles the load staging.
Each failure is silent — `validate` stays green and the built `.miz` looks right.

Two of them were caught on 4.7.0 only because the archives were compared with the mission
folders **by hand**, before running anything. That is not a procedure anyone should have to
invent.

## What the 4.7.0 refresh actually did

| Claim | Verified |
|-------|----------|
| Syria's setup script was renamed upstream (`footholdSyriaSetup.lua` → `footholdSyriaSetupv2.lua`) | Compared the archive's `.miz` with `src/scripts/`: v2 present upstream, the old name absent |
| `--update` added v2 and **kept** the old file | `git status` after the run: `?? footholdSyriaSetupv2.lua`, the old file unmodified and still referenced by `mission.yaml` |
| So `validate` passed and the build would have loaded the **previous version's** setup over 4.7.0 data | `validate` returned 0 on the unfixed folder |
| The report mentions neither the added nor the removed script | `convert-other-report.md` says *"Aucun — la migration s'est terminée sans avertissement"*, and all five reports print the same `10 éléments`, Syria included |
| `report.actions` is never rendered | `grep -c "self\.actions"` over the markdown builder in `v5_converter.py`: **0** |
| `report.manual_review` is never rendered either | Used only at `v5_converter.py:310`, to count items for the summary line |
| The five missions carried **no** `delay_seconds` at all | Read from each `mission.yaml`: 12 scripts, all at delay 0 |
| Upstream stages them | Resolved through `l10n/DEFAULT/mapResource` from the loader triggers' `c_time_after`: 6 scripts at 0 s, 5 at 1–3 s per map, **AIEN at 12 s (15 s on Persian Gulf)** |
| `_delay_changes` *did* detect it | `declared` is non-empty (`_declared_delays` returns every script, `None` when it has no delay), so six lines per mission were produced — and appended to `manual_review`, which nothing prints |
| `Convert-FootholdBatch.ps1 -Update` cannot find an existing mission folder | The target is `<OutputFolder>\<archive base name>` (`Convert-FootholdBatch.ps1:363`) and the archive name carries the version, so `Foothold_CA_4.7.0_…` never matches `VEAF-Foothold-Caucasus` |

## Why the staging one is not cosmetic

`doc/mission-maker/FOOTHOLD.md` already explains it, under *Pourquoi l'étalement compte*:
**AIEN inventories ground groups once**, at load, and Foothold creates part of its groups from
scheduled tasks starting at 2 s. Loading AIEN at t=0 hands it a world those tasks have not
populated — and the symptom is nothing at all in the log, just ground AI that never manages
Foothold's groups.

`delay_seconds` landed on 2026-08-11 (`dc0d9970`); the five missions were adopted on 2026-07-28
and `--update` preserves a tuned `mission.yaml`. So the staging was **never** written into any of
them: they shipped flattened from the day they were adopted until 2026-08-25.

## Order, and why the report comes first

02 → 01 → 03 → 04.

Ticket 02 first because it is the instrument: it costs a rendering pass, and once the two lists
are printed, tickets 01 and 03 become visible failures instead of findings someone has to go
looking for. Fixing 01 without 02 would leave the *next* upstream rename silent again in every
other form (a script added and unused, a delay that moved).

Ticket 04 is the harness rather than the tool, and it is what makes the other three reachable
for the nine other maps.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [`--update` leaves behind a script the upstream release removed](FIX-CONVERT-OTHER-UPDATE-BLIND-SPOTS.md) | fix |
| 02 | [The conversion report renders neither `actions` nor `manual_review`](FIX-CONVERT-OTHER-UPDATE-BLIND-SPOTS.md) | fix |
| 03 | [Reconcile the load staging on update](FIX-CONVERT-OTHER-UPDATE-BLIND-SPOTS.md) | feat |
| 04 | [`Convert-FootholdBatch -Update` cannot address an existing mission folder](FIX-CONVERT-OTHER-UPDATE-BLIND-SPOTS.md) | fix |

## Out of scope, stated rather than assumed

- **Two duplicate `build:` keys** at the top level of all five Foothold `mission.yaml`, committed
  on 2026-07-28. No effect today (both say `dev_mode: false`, and the last one wins), but a
  `scripts_path` written into the first would be ignored. Belongs to the mission repositories,
  not to the tools.
- **Mojibake in those same files** (`â”€`, `â€”`) since July, and `mission.yaml` normalised to CRLF
  by the batch's rewrite pass — which turned a 6-line diff into 254 lines on the one mission whose
  file was LF. Cosmetic, recorded because it costs review time on every refresh.
- **The `MiG-15bis` preset warning** on Germany and Syria: every frequency of the preset plan is
  outside the aircraft's radio range, so the original radio is kept. Correct behaviour, new in
  4.7.0, no work here.
- **The `.miz` naming check** did not flag the previous build sitting beside the new one
  (`…_20260728.miz` next to `…_20260825.miz`). The base name is identical and only the date
  suffix differs, so the check matched. Whether it *should* flag it is a product question for
  the batch, deliberately left to David rather than assumed.

## Retrospective — closed 2026-08-31

Delivered in order 02 → 01 → 03 → 04, as planned. Three of this PRD's own claims did not survive
contact, and they are worth more than the ones that did.

**The counter was never wrong.** Ticket 02 suspected it was computed before the update section
appended to the lists ("the counter did not even move for Syria"). Measured on a reproduction of
the Syria rename: four review items, four counted. `_summary_lines()` runs inside `to_markdown()`,
after everything. The count was right the whole time — pointing at a list nobody could read, which
is exactly why the number looked stuck. The fix was never arithmetic.

**Ticket 01's deletion criterion would have eaten the mission maker's work.** It proposed "in
`before`, referenced by `custom_scripts:`, no longer upstream" as the distinction between a stale
script and one of the maker's own. A script somebody wrote themselves and declared meets all three.
Nothing recorded what the *previous* release shipped, so the converter now writes
`convert-other-state.yaml`; without it, nothing is deleted. That file is the only structural
addition of the lot, and it exists because the stated criterion did not hold.

**Every `--update` integration test was being skipped.** `TestOtherMissionConverterIntegration` is
gated on a real Lekaa archive at a hard-coded path on one machine, absent from the CI runners — so
the entire class skips, and has always skipped. A skipped test and a passing one look identical in
a summary line, which is a plainer explanation for these four defects than any of the reasoning
above. The lot ships `testlib/upstream_miz.py`: a synthetic release of the right *shape*, which
also expresses what no frozen fixture can — a release that drops a script between two versions.

**Also fixed on the way, unplanned:** the delay writer walked the whole file before a review of my
own draft caught that `strip_native_triggers:` is a list too, sitting directly under
`custom_scripts:` — editing an entry there would have corrupted the mission silently. Pinned by a
test. And `_delay_changes`/`_declared_delays` (66 lines) became unreachable once the reconciliation
landed; they were deleted rather than left as green tests over code nothing calls, and their six
cases now exercise `apply_upstream_delays`.

**Left open, deliberately:** the mission repositories' own READMEs still show the old batch command.
They live in other repositories, so they are David's to update — the tool-side docs
(`FOOTHOLD.md`, `CONVERT_OTHER.md`, both languages) are current. And the four "out of scope" items
above are untouched, including the duplicate `build:` keys, which remain a mission-repository
matter.

---

## Tickets, in full

## 01 — `--update` leaves behind a script the upstream release removed

Status: ✅ done

Type: fix · File: `src/python/veaf-tools/mission_builder/other_converter.py`

### The defect

`convert-other --update` refreshes `src/scripts/` from the fresh upstream `.miz` and computes a
diff (`diff_scripts`, `other_converter.py:128-131`) whose `removed` set is exactly "scripts in the
folder the upstream mission no longer produces". Nothing acts on that set: the file stays on disk.

Because it stays, `mission.yaml` keeps pointing at a script that still exists, so `validate` finds
it, passes, and the build injects **the previous release's version** of it.

### Reproduction — Foothold Syria 4.7.0, 2026-08-25

Lekaa renamed the Syria setup script between releases:

```
upstream 4.7.0 : footholdSyriaSetupv2.lua      (328.4 KB)
mission folder : footholdSyriaSetup.lua        (304.9 KB, from the previous release)
```

After `convert-other <archive> VEAF-Foothold-Syria --profile foothold --update`:

```
?? src/scripts/footholdSyriaSetupv2.lua     <- added
   src/scripts/footholdSyriaSetup.lua       <- still there, unmodified, still in mission.yaml
```

`veaf-tools validate VEAF-Foothold-Syria` → exit 0. The build produced a `.miz` carrying the old
setup script and none of 4.7.0's. Caught only because the archive had been compared with the
folder beforehand.

### Why not simply delete

A `removed` script is not always stale: a mission maker may have added a script of their own to
`src/scripts/`, and `upstream` only ever describes what the loader triggers of the upstream `.miz`
reference. Deleting on that basis would eat somebody's work.

The distinction the code already has: `before` is what the folder held, `upstream` what the fresh
release loads. A file that was in `before` **and** referenced by the previous run's
`custom_scripts:` and is no longer upstream is stale; anything else is the mission maker's.

### Definition of done

- [ ] A script the upstream release no longer loads, and that the mission's own `custom_scripts:`
      referenced, is removed from `src/scripts/` — or kept and **named in the report** as needing a
      decision, if the safer half is preferred
- [ ] A script present in the folder but never referenced upstream nor by `custom_scripts:` is left
      strictly alone (test: a hand-added script survives an update)
- [ ] `validate` fails, rather than passes, when `custom_scripts:` names a script the upstream
      release stopped shipping — the green run is what made this expensive
- [ ] Regression test built on the real shape: same mission, one script renamed between two
      archives

---

## 02 — The conversion report renders neither `actions` nor `manual_review`

Status: ✅ done

Type: fix · Files: `src/python/veaf-tools/mission_builder/v5_converter.py`,
`src/python/veaf-tools/mission_builder/other_converter.py`

### The defect

`ConversionReport` carries two summary lists, documented as what the run has to say:

```python
actions: list[str]        # "High-level descriptions of actions taken (shown in the summary)"
manual_review: list[str]  # actionable items
```

Neither reaches the markdown. `self.actions` occurs **zero** times in the report builder;
`self.manual_review` occurs once, at `v5_converter.py:310`, only to count items for the
`⚠️ N éléments nécessitent une action manuelle` line. The `## Actions effectuées` section is built
from hard-coded steps, and `### ⚠️ Avertissements de conversion` renders `warnings`, a third list.

So everything `convert-other --update` is written to report goes into the void:

| Collected at | Content | Rendered |
|---|---|---|
| `other_converter.py:609` | scripts added upstream | no |
| `other_converter.py:611` | scripts updated upstream | no |
| `other_converter.py:613` | scripts removed upstream | no |
| `other_converter.py:620` | a load delay that no longer matches `mission.yaml` | no |

### Measured on the 2026-08-25 Foothold refresh

Five missions refreshed, one of them (Syria) with a renamed setup script and all five with six
mismatched delays each. Every report printed the same two lines:

```
- ⚠️ 10 éléments nécessitent une action manuelle
### ⚠️ Avertissements de conversion
*Aucun — la migration s'est terminée sans avertissement.*
```

The counter did not even move for Syria, which had one extra `removed` item — worth checking while
fixing this, since it suggests the counter is computed before the update section appends to the
lists.

### Why this is the first ticket of the lot

Both other defects of this lot were **detected by the code** and lost at the rendering step. The
delay mismatch in particular: `_delay_changes` produced its six lines per mission and appended them
to `manual_review`. The tool knew. It just had no way to say so.

### Definition of done

- [ ] `actions` and `manual_review` are rendered as their own sections in the markdown report
- [ ] `convert-other --update` on a release with an added, an updated and a removed script names all
      three in the written report
- [ ] The summary counter includes the update items (check the ordering between appending and
      counting)
- [ ] `doc/mission-maker/FOOTHOLD.md` and the mission-repository README stop promising a report the
      tool does not produce — or keep the promise because it now holds
- [ ] Test asserting the rendered text, not the list contents: a report whose `manual_review` is
      populated must print those lines

---

## 03 — Reconcile the load staging on update

Status: ✅ done

Type: feat · File: `src/python/veaf-tools/mission_builder/other_converter.py`

### The gap

`--update` preserves the tuned `mission.yaml` on purpose, and `_delay_changes`
(`other_converter.py:217`) exists precisely because of it: a delay that moved upstream would
otherwise stay silently wrong. But detecting is all it does — nothing writes the reconciled value,
and with ticket 02 unfixed nothing even printed it.

Meanwhile the *first* adoption of a mission does write the staging: the scaffold emits
`delay_seconds:` beside each loader it detected (`other_converter.py:431-434`). So the two paths
disagree — a mission adopted today is staged, a mission adopted before 2026-08-11 and updated ten
times since never will be.

### Measured on the five VEAF Foothold missions, 2026-08-25

None of them carried a single `delay_seconds`. Resolved from the upstream loader triggers
(`c_time_after`, mapped through `l10n/DEFAULT/mapResource`):

| Mission | CTLD, CTLD_Red, Zeus, EWRS, Splash_Damage | AIEN |
|---|---|---|
| Caucasus | 3 s | **12 s** |
| Germany | 1 s | **12 s** |
| PersianGulf | 2 s | **15 s** |
| Sinai | 2 s | **12 s** |
| Syria | 1 s | **12 s** |

Written by hand for this refresh (6 lines per mission), which is what this ticket removes the need
for — nine other maps are waiting behind these five.

The consequence of leaving it flattened is in `doc/mission-maker/FOOTHOLD.md` already: AIEN
inventories ground groups **once**, at load, while Foothold creates part of them from tasks
starting at 2 s. At t=0 it sees a world that is not there yet, and says nothing.

### The design question this ticket has to answer

Rewriting a preserved `mission.yaml` is exactly what `--update` promises not to do. Three shapes,
in increasing order of nerve:

1. **Report only** (today, once ticket 02 lands): print the mismatch, leave the edit to a human.
   Honest, and nine maps × six lines per release.
2. **An explicit flag** (`--sync-delays`): opt-in, so the promise holds by default.
3. **Reconcile by default**, on the grounds that a delay is upstream's decision and not the mission
   maker's tuning — with the exception of a delay a human deliberately overrode, which the file
   cannot currently express.

Recommendation: **2**, and state in the report that the flag exists. It keeps `--update`'s promise
literal while making the fix one gesture.

### Definition of done

- [ ] A mission whose `mission.yaml` carries no `delay_seconds` at all, refreshed against an
      upstream release that stages its loaders, ends up with the staging — through whichever of the
      three shapes David picks
- [ ] An edit is never lost silently: whatever the mode, the report names every delay it wrote or
      would write
- [ ] Line endings and byte content of the preserved `mission.yaml` are untouched apart from the
      inserted lines (the batch already normalises the file to CRLF; a second rewriter doing the
      same turns a 6-line diff into a whole-file one)
- [ ] Test on the real shape: a `mission.yaml` with no delays at all, which is the case
      `_declared_delays` returns as "every script, `None`" and the one that mattered here

---

## 04 — `Convert-FootholdBatch -Update` cannot address an existing mission folder

Status: ✅ done

Type: fix · File: `tools/Convert-FootholdBatch.ps1`

### The defect

The batch derives each target folder from the archive's file name:

```powershell
$name = [System.IO.Path]::GetFileNameWithoutExtension($archive.Name)
$target = Join-Path $OutputFolder $name        # Convert-FootholdBatch.ps1:362-363
```

Lekaa's archive names carry the version (`Foothold_CA_4.7.0_Multi_Language_Coldwar-Modern-Vietnam.zip`),
and the VEAF mission folders are named after the map (`VEAF-Foothold-Caucasus`). So:

- `-Update` tests `Test-Path <target>\mission.yaml` (`:376`), finds nothing, and drops back to a
  **fresh adoption** — scaffolding a new `mission.yaml` beside a new folder instead of refreshing
  the tuned one;
- even against its own previous output, the next release has a different archive name, so a folder
  is created per release and `-Update` never engages.

### Why this bites rather than merely annoys

Every VEAF Foothold repository's README recommends exactly this command for a new Lekaa release:

```
.\tools\Convert-FootholdBatch.ps1 -InputFolder <download folder> -OutputFolder <missions folder> -Update -Build
```

Followed literally, it produces ten new folders and touches none of the ten missions.

The 2026-08-25 refresh worked around it by copying the five archives under the repository names
(`VEAF-Foothold-Caucasus.zip`, …) into a staging folder — profile detection reads the archive's
contents, not its name (`Get-ConversionProfile`), so the rename is safe. That workaround should not
be the procedure.

### Definition of done

- [ ] The batch can target mission folders whose names are not the archive names — a mapping
      (archive → folder), or matching an existing folder by theatre read from the archive, or an
      explicit pairs file; the theatre is already read for profile detection
- [ ] `-Update` engages on an existing mission folder in the same run that adopted a new one
- [ ] A folder is never created next to one it should have refreshed (the failure mode that is
      indistinguishable from success until someone reads `mission.yaml`)
- [ ] The mission repositories' README and `doc/mission-maker/FOOTHOLD.md` show a command that
      works as written

---
