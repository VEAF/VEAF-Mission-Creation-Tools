# FIX-COMBATZONE-DEAD-UNIT-HAS-NO-GROUP — a combat zone loses track of what it has lost

Status: 📋 open — **field report, not yet investigated.** Observed by David on 2026-09-26 evening,
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

## The hypothesis worth testing first

Symptoms 1, 2 and 3 are consistent with a single cause: if the death handler cannot map a dead unit
back to its group, then nothing downstream can happen — the zone does not decrement, so the count
stays low, and the completion check never sees an empty zone, so it never deactivates. One lookup
failing would explain all three.

**What has to be established before believing it:** why the lookup fails. The message carries a
numeric id rather than a unit name, which is a lead — whether the handler is being given an object
id where it expects a name, or whether the unit is already gone by the time it looks. Both are
guesses. Reproduce it first.

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
