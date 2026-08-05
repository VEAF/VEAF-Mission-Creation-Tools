# 01 — Probe `Disposition` in a running DCS

Status: 🧑 waiting-human
Type: chore
Files: throwaway probe script, then `docs/exploration/TUM-EXPLOIT.md`

## Deferred — no longer a gate (David, 2026-08-05)

**"On sondera plus tard, fais comme si c'était bon et code."** Tickets 02–05 proceed on the
assumption that `Disposition.getSimpleZones` behaves as TUM's call site implies. This ticket stays
open as the outstanding verification, and it needs a human at a DCS install.

The assumption is load-bearing in exactly one direction, which is why coding ahead is safe: if the
singleton is missing, malformed, or no better than `getSurfaceType`, the helper falls through to
tier 2 and ground spawns behave as they do today. What is *not* covered until this ticket runs is the
**per-call cost** and the claim that the returned points genuinely avoid buildings and forests — so
until then, ADR 0018 records the scenery avoidance as **asserted, not measured**.

## Why it was originally first

Everything below depends on a singleton we have **never called**. The whole evidence base is one
unguarded call site in TUM (`TheUniversalMission.lua:3060`) and a Reddit claim by its author. It is
absent from `dcs-world-schema`, so there is no reference to check the signature against. Building
the wrapper first and discovering in flight that the fourth argument is not a count, or that it
returns vec2 rather than vec3, is a wasted ticket.

This is the same shape as ticket 01 of `FEAT-ASSIST-CHECKLISTS`, which proved the cockpit-highlight
functions were reachable before the engine was written on top of them.

## What to measure

Run a probe inside a real DCS mission — the `veaf-tools inject-bridge` / `capture-map` path already
does exactly this kind of runtime interrogation and is the tool to reuse.

- [ ] **Existence.** Is `Disposition` a table in the mission scripting environment? Dump
      `type(Disposition)` and its keys — the author mentions "a few" other undocumented functions,
      so record the whole surface, not just `getSimpleZones`.
- [ ] **Signature.** Confirm `getSimpleZones(centerVec3, searchRadius, exclusionRadius, count)`:
      does it want a vec3 or a vec2? Does it return vec3 or vec2? What does `count` do when more
      points exist than asked for, and when fewer do?
- [ ] **Behaviour, the actual point of the exercise.** Call it centred on a **village** and on a
      **forest** with a known-clear area nearby, and confirm the returned points are genuinely
      clear of both. A function that only avoids water would be worthless here — that is what we
      already have.
- [ ] **Empty case.** Centre it on dense city with a small radius: does it return an empty table, a
      nil, or throw? The wrapper's fallback branch depends on this answer.
- [ ] **Cross-theatre.** At minimum one modern map and one WWII map (Normandy), since scenery data
      differs. Note any theatre where the singleton is missing.
- [ ] **Cost.** Rough timing for one call. Ground spawns can place a dozen groups at once; if a
      call costs tens of milliseconds the wrapper needs to be called once per *group*, not per unit.

## Outcome

Write the measurements into `docs/exploration/TUM-EXPLOIT.md`, replacing the inferred description
with an observed one — including anything that turns out **false**, as the hook-boundaries note did
for two of dcs-sms's claims. Update ADR 0018 to say measured instead of asserted.

Then, since the code already shipped:

- **Positive** → confirm the constants (`SPAWN_SEARCH_ATTEMPTS`, the 1852 m floor) against the
  measured cost, and tune if a call turns out expensive.
- **Negative or unreliable** (missing on common theatres, or avoidance no better than
  `getSurfaceType`) → tier 1 is dead weight, not a bug: delete the tier and the mock, keep tier 2
  (which is an improvement on its own — it validates where nothing validated before), and record the
  dead end in ADR 0018 so nobody re-explores it.

## Notes

No VEAF source changes in this ticket, so no version bump and no CHANGELOG entry.
