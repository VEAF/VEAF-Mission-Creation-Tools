# 01 — a radar that reports no range is asked again

Status: ✅ done

## The defect

`SkynetIADSSAMSearchRadar:setupRangeData` is called once per radar, from `buildSingleUnit`, while the
element is being built (`skynet-iads-compiled.lua:3013`). It reads `getSensors()` and writes
`maximumRange`. If the answer is `nil`, `maximumRange` keeps its constructor value — `0` — and no
code path ever reads the sensors again.

A site in that state:

- detects nothing (`isInRadarDetectionRangeOf` compares against `maximumRange`), so it never goes
  live, even when a player flies over it;
- is counted under `Raddest` on every status page, because `isRadarWorking()` also goes through
  `getSensors()`, and a search radar carrying no ammunition gets nothing from the `getAmmo()`
  fallback either.

That is both of Tripack's symptoms out of one unread field.

## Hypotheses eliminated — do not re-run these

1. **"the radar unit was not born yet"** — no. `addSAMSite` rejects a group whose `natoName` stays
   `UNKNOWN`, and the match in `setupElements` requires at least one search radar. The site is in the
   network as `TYPE: SA-6`, so the 1S91 was there.
2. **"DCS had not finished initialising the unit"** — no. The marker-spawned SA-6 was enrolled 2 ms
   after its birth event and its radar works (`Raddest: 0`).
3. **"a corpse was enrolled, #947 did not hold"** — no. The guard is at both levels
   (`veafSkynetIadsHelper.lua:1263` and `:1009`) and no `ADD GROUP REFUSED` line appears in the log.
4. **"the zone leaves its SAMs on alarm state green, radar down"** — no.
   `veafCombatZone.DefaultAlarmStateStatic` is `ALARM_STATE_RED`.

What remains — why DCS answers `nil` on a live handle — cannot be measured without the game, which
is why this ticket both repairs and instruments.

## What to build

- `veafSkynet.measureRadarRange(element)` → widest range reported, number of radars, number of them
  DCS still holds. One place that knows how to ask, used by the check and by the tests.
- `veafSkynet.checkRadarRange(networkName, element)`, called for every element joining a network:
  logs at **`info`** when the range is zero while the element holds a live radar — with the counts,
  so the line is a diagnosis and not a complaint — and schedules a re-read.
- `veafSkynet.recheckRadarRange(...)`: calls `setupRangeData()` again on each radar, up to
  `veafSkynet.MaxRangeRechecks` times, `veafSkynet.DelayForRangeRecheck` seconds apart, and rebuilds
  the coverage as soon as one radar answers with a range.

`info` rather than `debug`, for the reason ticket 02 of the previous lot recorded: the default level
is `info` and no shipped mission raises it, so a `debug` line is invisible exactly where it is needed.
Silent on the normal case — one line per *faulty* site, not per site.

## Done when

- a site whose radars report zero is re-read, and its range is picked up when the second reading
  answers
- a site whose radars report a range is never re-read, and logs nothing at `info`
- the re-read stops after `MaxRangeRechecks`, and never runs on an element DCS no longer holds
- reverting the production change makes the new tests fail
