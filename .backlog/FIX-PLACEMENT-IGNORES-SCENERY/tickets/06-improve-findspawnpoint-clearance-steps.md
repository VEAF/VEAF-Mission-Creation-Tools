# 06 — `findSpawnPoint`: descending clearance steps and closest candidate

Status: 🔄 in-progress
Type: fix

## Problem

`findSpawnPoint` tier 1 requests `DEFAULT_SPAWN_CLEARANCE = 100 m` of clearance and immediately falls
through to the blind random tier when nothing qualifies. On Germany-CW-v6 (2026-09-25), 100 m bubbles
are rarely available in wooded terrain: the Disposition singleton returned **no usable point 38 times
out of 106 commands**, including on open-ground zones such as Letzlingen, because the `_spawn`
commands default to `radius = 1` — a 1 m search radius with a 100 m clearance request will always
fail. The group centre therefore stays wherever tier 2's random draw lands it, often under trees.

Additionally, when tier 1 did find a candidate, it returned the **first acceptable one**, not the
closest. Measured 2026-08-06: Disposition asked for 800 m returned points 2035-2258 m out, so the
group could appear kilometres from the marker.

## What this ticket does

1. **Descending clearance steps.** After failing at `safeRadius`, retry at each step in
   `veaf.SPAWN_CLEARANCE_STEPS = { 50, 25, 10 }` that is strictly smaller. The search stops at the
   first step that produces a usable candidate; only then falls through to the random tier.
2. **Closest candidate wins.** Within each Disposition call, iterate all candidates and keep the one
   whose distance to the centre is smallest (and still <= radius). The distance guard was already
   there; this makes it a minimiser rather than a pass/fail.
3. **`noRandomFallback` parameter (5th, optional).** When `true`, the random tier (tier 2) is
   skipped and `nil` is returned instead. Used by ticket 07 so editor-placed elements never get
   a random placement as a consolation prize.

## Definition of done

- [ ] `veaf.SPAWN_CLEARANCE_STEPS` constant defined and documented
- [ ] `findSpawnPoint` retries at each step < safeRadius before dropping to tier 2
- [ ] The closest candidate within the radius wins, not the first
- [ ] `noRandomFallback = true` skips tier 2 and returns nil
- [ ] Debug log on each clearance step failure; trace log names the winning clearance
- [ ] Tests: all tier-1-exhausted-at-100m-but-found-at-50m, closest-wins,
      noRandomFallback-returns-nil, existing tests still green
- [ ] `stylua --check` and `luacheck` clean
