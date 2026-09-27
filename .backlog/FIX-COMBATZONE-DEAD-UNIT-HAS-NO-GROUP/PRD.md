# FIX-COMBATZONE-DEAD-UNIT-HAS-NO-GROUP — a combat zone loses track of what it has lost

Status: ⬜ ready — **field report, not yet investigated.** Observed by David on 2026-09-26 evening,
flying `combatZone_WahnerHeide` as a two-ship of A-10s on GermanyCW-v6. Written down while it was
fresh; nothing below has been reproduced or measured yet.

## What was observed

Four symptoms, reported together. Three of them look like one defect and its consequences, and the
fourth is probably unrelated — but that is a hypothesis, stated as such, not a finding.

1. **The log fills with `onUnitDead: no group found for unit '2622423206' — skipping`.** Many of
   them.
2. **The kill count in the zone's info panel was far below reality** — about fifteen vehicles
   destroyed, a much smaller number shown.
3. **The zone never deactivated**, although every vehicle in it had been destroyed.
4. **The vehicles were cold**, which made them very hard to find on the TGP.

## Analysed 2026-09-27 from the run's `dcs.log` — and the first hypothesis was wrong

The hypothesis written here first was that one failed group lookup starved both the count and the
completion check, explaining symptoms 1, 2 and 3 at once. **It does not survive the log.**

### Symptom 1 is not a defect. It is a log level.

The message does not come from `veafCombatZone` at all — it comes from
[`CTLD.lua`](../../src/scripts/community/CTLD.lua), in `CTLDTroopManager:onUnitDead`, which looks up
CTLD **troop** groups. Of the 1264 occurrences in the run, **1248 carry a purely numeric id** —
unnamed objects, scenery and debris, which DCS reports through `S_EVENT_DEAD` like anything else —
and the remaining 16 are VEAF dynamic spawns (`[r]-India Division`, `[r]-Bravo Fighters`) that are
not CTLD troops either. The handler succeeded **zero** times, because no CTLD troop died all game.

So "no group found" is the **normal** outcome for almost every death in a mission, and the line
announces it at `INFO` while the two failure branches above it log at `DEBUG`. One inconsistent
level produced 1264 lines of noise and a bug report.

**The fix is one word** — `INFO` to `DEBUG` — but the file is community code that VEAF already
patches (the function carries a `FIX-FIELD-EXTRACT-CASUALTIES` note), so check how vendored changes
are carried before editing it.

### Symptoms 2 and 3 are still unexplained, and this log cannot explain them

Two leads were followed and both were closed:

- **The zone excludes groups it contains.** The log says so plainly: *"Zone de combat
  [combatZone_WahnerHeide_Easy] : 4 groupe(s) présents dans la zone ont été ignorés :
  combatZone_WahnerHeide_Hard-cmd-2, … Pour faire partie de la zone, le nom d'un groupe doit
  commencer par le nom de la zone"*. This is the documented prefix convention working as intended
  (`DOC-COMBATZONE-PREFIX-RULE`): the Wahner Heide zones overlap, so each sees the others' groups
  and drops them. Not a defect.
- **The watchdog never ran.** `CompletionCheck` appears **zero** times in the log — but that proves
  nothing: it logs at `trace` and the server runs at `info` (1716 `I` lines, 36 `W`, no `D` or `T`).
  Do not quote this as evidence.

**What the overlap does suggest, and it is the best lead left:** the three Wahner Heide zones cover
each other, and a flight attacking "Wahner Heide" destroys vehicles belonging to whichever zone owns
them. A zone counts only its own, so a low count and a zone that never completes are both what you
would see if part of the fifteen kills belonged to a *neighbouring* zone. That would make both
symptoms correct behaviour badly presented, rather than a bug.

**How to settle it, cheaply:** ask David which of Easy / Medium / Hard was activated, then list what
that zone actually owns. No DCS needed for the second half.

**If it has to be reproduced:** rerun with `veaf.ForcedLogLevel = "debug"`, since everything
`veafCombatZone` says about completion is below `info`.

### A second lead, not yet checked

`VeafCombatZone:isCompletable()` returns false when the zone is not completable **or** its trigger
zone could not be read, and it gates the watchdog itself — a zone that fails it never schedules a
completion check at all, which is exactly symptom 3. Worth one look at Wahner Heide's own
configuration before assuming anything more complicated.

Symptom 4 is a different question: whether groups spawned into a combat zone should start with their
engines running, and it is arguably a design choice rather than a defect. Worth asking David what he
expects rather than deciding here — a cold vehicle is realistic and a fair challenge, up to a point.

## Also from the same sortie, and it belongs elsewhere

**The tankers fly unescorted.** Reported by David in the same breath, kept here so it is not lost,
but it is a different subject and should be reclassified rather than fixed under this lot.

One thing was checked before writing it down: **nothing in the mission's `mission.yaml` configures
an escort for the tankers** — the only occurrences of "escorte" in that file are red convoy
briefings. So this reads as configuration that was never written, not as an escort mechanism that
fails. VMCT already carries [`FEAT-AWACS-ESCORT-COMMANDS`](../FEAT-AWACS-ESCORT-COMMANDS/PRD.md),
so the capability side is a lot of its own.

What is *not* established: whether tankers on this mission are meant to be escorted at all. Texaco
and Arco orbit well behind the line. Ask David what he expects before building anything.

## Where to start

- `veafCombatZone.CompletionCheck` for symptom 3, and whatever feeds the zone's info panel for 2.
- The `onUnitDead` handler that emits the message for 1 — the log line quoted above is the exact
  string to grep for.
- Reproduce on `combatZone_WahnerHeide` specifically, since that is where it was seen.
