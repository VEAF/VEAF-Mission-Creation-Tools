# 03 — Reconcile the load staging on update

Status: ✅ done

Type: feat · File: `src/python/veaf-tools/mission_builder/other_converter.py`

## The gap

`--update` preserves the tuned `mission.yaml` on purpose, and `_delay_changes`
(`other_converter.py:217`) exists precisely because of it: a delay that moved upstream would
otherwise stay silently wrong. But detecting is all it does — nothing writes the reconciled value,
and with ticket 02 unfixed nothing even printed it.

Meanwhile the *first* adoption of a mission does write the staging: the scaffold emits
`delay_seconds:` beside each loader it detected (`other_converter.py:431-434`). So the two paths
disagree — a mission adopted today is staged, a mission adopted before 2026-08-11 and updated ten
times since never will be.

## Measured on the five VEAF Foothold missions, 2026-08-25

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

## The design question this ticket has to answer

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

## Definition of done

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
