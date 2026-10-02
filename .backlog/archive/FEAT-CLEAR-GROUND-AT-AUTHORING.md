# FEAT-CLEAR-GROUND-AT-AUTHORING — when the tools place a group, they place it somewhere measured clear

Status: ✅ done — merged in #1019 on 2026-09-28; tickets 01 to 05 built and verified in game (see *What was · archived 2026-10-02
built*).
David asked for the lot on 2026-09-26 evening, after
[`FIX-PLACEMENT-IGNORES-SCENERY`](../FIX-PLACEMENT-IGNORES-SCENERY/PRD.md) ticket 11 reached its
ceiling.

Origin: ticket 11 fixed `veafUnits.settleGroup` at runtime and measured the result — 19 group alerts
and 76 blocked vehicles become 15 and 69 on GermanyCW-v6. Good, and nowhere near the target, for a
reason that is measured rather than guessed: **62 % of the vehicles still standing in trees belong
to groups `settleGroup` is never given**, and the ones it does see and cannot solve are places where
`Disposition` returns nothing at any clearance at all, down to 5 m.

## The rule this lot exists to enforce

David's arbitration, 2026-09-26, and it has two halves that must not be confused:

- **A position the mission maker drew stays where they drew it.** Unchanged since the arbitration of
  2026-08-27. Editor content is not this lot's business and must never be moved behind their back.
- **A position *the tools* chose is the tools' responsibility.** When a mission is authored through
  the MCP server and the VEAF tooling — not by a human placing a unit in the editor — putting a
  15-vehicle S-300 in a wood is a defect of ours, and it must be placed on ground measured clear,
  **at authoring time**.

The point of moving this to authoring time is that runtime is the worst possible place to ask.
`Disposition.getSimpleZones` is non-deterministic there, it ignores the search radius it is given,
and it returns **zero candidates** exactly where a group most needs help. At authoring time there is
no frame budget and no hurry.

**What makes this tractable:** the *small* probe — "is there a patch of 5 m free within 20 m of this
point?" — is the one use of the singleton measured **reliable and deterministic**: 12 repetitions on
the same points gave 0/12 against 12/12, with identical candidate counts
([`known-limitations.yaml`](../../src/python/veaf-tools/veaf_libs/data/known-limitations.yaml),
`disposition-getsimplezones-is-a-lottery`). A catalogue built by sweeping with that probe rests on
the only thing DCS does dependably here. The large query, which asks for a whole clearing at once,
is the lottery — and it is what this lot must avoid, not imitate.

## The two halves, and how they fit

**A — the MCP offers to launch DCS and check what it just generated.** The server produces the
`.miz`, DCS loads it, the blocked units are read back, and the result is reported or corrected. It
is the **only** way to validate the end result for real. It costs a DCS instance and a mission load
measured in minutes, it never runs in CI, and it *observes* rather than places.

**B — a catalogue of clear positions, swept once with DCS and served to the MCP.** Each retained
point carries **the radius actually clear around it**, so the server can ask for "somewhere near
Wittstock that holds 15 vehicles" and get candidates with no DCS running, instantly, offline and in
CI. It places correctly the first time instead of repairing at spawn. It costs the sweep, the
storage, and it ages when ED retouches a map.

**B is the foundation, A is the gate, and B comes first** — B attacks the cause where A only
observes, and B is the half that works without DCS.

## What was learned after this PRD was first written

Three things, all from the evening of 2026-09-26 and the morning after. They change the design, so
they come before the decisions.

**1. The probe counts vehicles, not just scenery.** `Disposition.getSimpleZones` answers "is there
room here", and a tank occupies room: the same points read 12 of 14 blocked with a group standing on
them and 0 of 14 once it was destroyed
([`known-limitations.yaml`](../../src/python/veaf-tools/veaf_libs/data/known-limitations.yaml),
`disposition-getsimplezones-is-a-lottery`). A catalogue swept while units are on the map would
record those units as permanent obstacles and rot the moment they move or die. **The sweep has to
happen on an empty map.**

**2. Sweeping with the probe works where the singleton refuses to answer.** `combatZone_Wittstock`'s
S-300 was on record as having no way out at any clearance; a ring sweep found it a clearing at
**200 m**. The dead end was a property of the query, not of the terrain. This is the same insight
that opened [`FIX-PLACEMENT-IGNORES-SCENERY` ticket 12](../FIX-PLACEMENT-IGNORES-SCENERY/tickets/12-settle-sweeps-with-the-probe.md),
and it is what makes this lot buildable at all.

**3. The probe's throughput is measured: 0.38 ms per call, ~2600/s.** The PRD used to say this was
unknown. It is not, and it reframes the first decision — see below.

## Decided

Questions 1 and 2 were put to David on 2026-09-27 and answered, along with two more that the three
findings above raised.

1. **Perimeter — revised on 2026-09-28 by ticket 01's measurement: fine where groups are placed,
   nothing elsewhere.** David chose option *a*: sweep at **25 m** around the airfields and combat
   zones, answer "not covered" everywhere else and place as requested (decision 4), and sweep a zone
   on demand when DCS is at hand — about ten seconds a zone on Caucasus. The coarse pass was
   affordable (7.1 M cells, about 20 min on Caucasus) and **wrong in the dangerous direction**: at
   200 m it promised clearings of 240 m where a ring probe stopped at 40 m. The original text of the
   decision follows, for the record.

   *As first decided:* **coarse everywhere, fine where it matters.** One pass at a wide spacing (200 m) over
   the whole map, and a second at a fine spacing (50 m) around the combat zones, airfields and road
   axes. The catalogue then answers anywhere, precisely where things are actually placed, and
   placement outside the fine perimeter still works with less precision.

   The throughput measurement is what made this affordable: a 200 m pass over a 500x500 km map is
   roughly 6 million points, and the fine pass over 25 combat zones roughly 280 000. **Caveat that
   the first ticket must resolve:** those durations assume *one* probe per point, and decision 2
   asks for a radius, which costs several. The sweep will cost more than the estimate above — how
   much is a measurement, not a guess.

2. **Granularity: store the clear radius per point.** Not a free/occupied flag. One catalogue then
   serves a lone Ural and a 15-vehicle S-300 from the same data — ask for "somewhere that holds
   150 m" and filter. The large groups are the ones this lot exists for, and a flag cannot answer
   the only question they raise. Read it with a margin rather than exactly: **a group's footprint
   moves by up to 38.8 m between draws**
   ([ticket 11](../FIX-PLACEMENT-IGNORES-SCENERY/tickets/11-settle-verifies-the-candidate-it-trusts.md)).

3. **Sweep from a dedicated empty mission.** A `.miz` holding no units at all, loaded only to sweep,
   so the probe sees vegetation and buildings and never a vehicle. It is reusable as-is for every
   map. The alternative — sweeping from whatever mission is at hand — would bake that mission's
   vehicles into the catalogue, which is exactly the mistake that cost two days this week.

4. **Out of coverage: place anyway, and say so plainly.** When nothing large enough is found, the
   group goes where it was asked to go and the tool reports it — *"no clear position for 15 vehicles
   within 1 km, placed as requested"*. The mission still builds and the mission maker knows what
   they have. This is ADR 0018: an undocumented dependency may improve quality, it must never be
   what refuses a placement.

5. **Both distribution modes.** A catalogue per map, versioned in VMCT so everyone benefits without
   owning the terrain, **and** generation on demand on the workstation of whoever authors a mission,
   for a map or an area the versioned catalogue does not cover. David, 2026-09-26.

## What was built, 2026-09-28

Everything measured in game on David's DCS, the same day.

- **The catalogue** (`veaf_libs/clear_ground_catalogue.py`): one probe per cell on a 25 m grid, the
  clear radius derived offline by an exact distance transform (1.4 s per million cells), less one
  spacing for what lies between samples. Stored per theatre under `veaf_libs/data/clear-ground/`,
  a locally swept one winning over the shipped one. **Deterministic in fact**: two sweeps of the 21
  Caucasus airfields — one interrupted by a DCS crash, resumed, replayed with a map drawing; the other
  clean and batched differently — wrote the same 258 038 bytes. Shipped: Caucasus (21 airfields,
  1.22 M cells, 4 min) and GermanyCW (the 25 combat zones of GermanyCW-v6, 1.45 M cells, 8 min).
- **The query** answers in **3 ms** for a 1 km search, the catalogue loading in 6 ms, and keeps
  *not covered* apart from *nothing large enough*.
- **The footprint of a marker** (`veaf_libs/group_footprint.py`), which the PRD did not foresee: the
  runtime never reads a unit's real size — the block of `processUnit` that did is commented out — so
  the worst case of `veafUnits.placeGroup` is computable from `veaf-units.yaml` and the command's
  `spacing`. `-sa10` needs 214 m. Held to 400 replayed draws of eight real groups at two spacings:
  no draw exceeds the bound. Groups assembled from dice rolls (`-armor`…) stay unknown and are left
  to `settleGroup`.
- **The placement** (`veaf_libs/clear_ground_placement.py`) in `add_group` and `create_combat_zone`:
  a stationary vehicle group moves up to 1 km as one body; `keep_position` keeps the user's position;
  every outcome is a `warning`. Wittstock's S-300, the case that opened this lot: moved 408 m onto a
  clearing that holds 214 m.
- **The guided sweep**, `veaf-tools dcs clear-ground-sweep`: writes the survey mission where DCS
  looks (the Saved Games folder asked of Windows, so a moved one is found), starts `dcs-serve` with a
  generated key and stops its whole process tree, explains the bridge and the `MissionScripting.lua`
  prerequisite, waits, resumes. David ran it on both theatres.
- **The check**, `veaf-tools dcs clear-ground-check`, offered by the MCP (`offer_clear_ground_check`)
  and never launched by it. It probes each vehicle's **declared position on the empty survey mission**,
  rather than spawning the mission and reading positions back as ticket 05 first wrote: the check has
  to run where no vehicle exists, and a spawned group is exactly that. Run on a mission built through
  `add_group` — 8 groups asked into woods, 4 control groups kept there: **the 8 controls' vehicles
  found in the woods, every vehicle the tools placed found clear, 0 disagreement with the catalogue
  over 48 vehicles.**

Found and fixed on the way: `dcs-serve.exe` is a PyInstaller one-file build, and stopping it stopped
the bootloader only — the server kept running with its key, and the next run, finding it, read a key
from a stray `dcs-serve.yaml` and waited on 401s.

## Tickets, in full

## 01 — measure what one catalogued point costs, before sweeping anything

Status: ✅ done — measured in game on Caucasus, 2026-09-28; **decision 1 reopened** (see *Verdict*)
Type: chore

### Why this comes first

The perimeter decision rests on an estimate that is **known to be wrong in one direction**. It
assumed one probe per point; decision 2 asks for the **clear radius** at each point, which costs
several. Nobody knows how many, so nobody knows whether the coarse pass takes forty minutes or six
hours — and that difference decides whether the whole-map pass survives at all.

This is deliberately its own ticket: a measurement that could change the design must not be buried
inside the work it would change.

### What to measure

1. **The cost of one point with its radius**, for whatever method obtains it — expanding rings until
   the first obstacle, bisection between two bounds, or a fixed ladder of radii. Compare at least
   two; the cheapest that is accurate enough wins.
2. **The accuracy that costs the least.** A radius good to 10 m is probably as useful as one good to
   1 m, since a group's footprint moves by up to 38.8 m between draws. Find the coarsest answer that
   still discriminates.
3. **The real duration of both passes**, extrapolated from the above and given as a range rather
   than a single figure.

Baseline already in hand: one probe is **0.38 ms** (~2600/s), measured in game on 2026-09-26. The
large-clearance query is 12.0 ms and must not be used here at all.

### What was measured, 2026-09-28

Caucasus, on the empty survey mission (`veaf-tools` `clear_ground_survey.build_survey_mission`, no
unit at all), over `dcs-serve`. Twelve sample points 3 km from twelve airfields drawn at random with
a fixed seed. Raw figures in the session log; method in `clear_ground_survey.measure_cost`.

**Two methods compared.**

- **Rings** (the reference): one probe at the point, then rings every 20 m, one probe every 20 m of
  arc, until one holds a sample that is not clear. The radius is the last clear ring.
- **Grid + distance transform**: one probe per grid cell, and the radius of a cell is its distance
  to the nearest cell that is not clear, less one spacing — computed offline, 1.4 s per million
  cells in pure Python. The grid is centred on the sample itself for the comparison: a snapped grid
  put the nearest cell up to 140 m away, and the first run compared two different places.

**Cost.**

| | measured |
|---|---|
| one probe, on an empty mission | **0.15 to 0.17 ms** (0.38 ms on 2026-09-26 was taken on a loaded mission) |
| one call across `dcs-serve`, empty chunk | **190 ms** — the bridge's cadence, not DCS |
| rings, per point, to 500 m | 1 to 2 055 probes, 0.2 to 0.8 s — dominated by the call |
| grid, per point | **one probe**; the radius costs nothing more |

So the call is what costs, not the probe: a batch must carry whole rows, several at a time (10 000
cells per call spends 1.5 s probing for 0.19 s crossing).

**Accuracy, grid radius against rings, same 12 points.**

| spacing | worst error | in the unsafe direction (grid promises more than there is) |
|---|---|---|
| **25 m** | −20 / +10 m | +10 m, twice — within the 40 m margin |
| 50 m | **+130 m** | once: a copse between two cells, 60 m from the point (grid said 170 m, rings 40 m) |
| 100 m | +80 m | several |
| 200 m | **+200 m** | several (240 m promised where rings stop at 40 m) |

Where the rings reach their 500 m ceiling the grid reads 550 to 1 000 m: that is the ceiling of
the reference, not an error of the grid.

**Durations**, Caucasus (409 × 699 km over its airfields plus 20 km; 21 airfields), at the measured
0.15 ms a probe and 10 000 cells per call:

| pass | cells | duration |
|---|---|---|
| fine around the 21 airfields, 6 km squares at 25 m | 1.2 M | **~4 min** |
| fine, one combat zone, 6 km square at 25 m | 58 k | **~10 s** |
| whole map at 200 m | 7.1 M | ~20 min — but its radius is not usable |
| whole map at 50 m | 114 M | ~5 h — and wrong once in twelve |
| whole map at 25 m | 457 M | ~20 h |

### Verdict

- **The method is the grid, at 25 m.** One probe per point, the radius from a distance transform.
  The rings are exact but pay a call per point; the grid pays one probe per point and is within the
  margin at 25 m.
- **The coarse pass cannot carry a radius.** At 200 m it promises clearings that are not there, in
  the direction that puts a battery in a wood. Cost was never the issue; accuracy is.
- **Decision 1 is reopened** — the ticket's own rule. What the numbers suggest, for David to decide:
  sweep finely (25 m) where groups are placed, answer "not covered" everywhere else and place as
  requested (decision 4), and since a combat zone sweeps in ten seconds, sweep a zone on demand
  when DCS is at hand rather than the whole map ahead of time.

### Definition of done

- [x] The per-point cost is measured, not estimated, for at least two radius methods
- [x] The duration of the coarse and fine passes is stated as a range, with the method that produced
      it
- [x] If the whole-map coarse pass turns out to cost hours rather than minutes, **say so and reopen
      decision 1** rather than quietly shrinking the perimeter — reopened on accuracy rather than
      cost: the 200 m pass is affordable and wrong
- [x] The numbers land in the PRD, replacing the estimates it currently carries — once David has
      decided what replaces decision 1

## 02 — an empty survey mission, and the sweep that fills the catalogue

Status: ✅ done — 2026-09-28, verified in game; see the PRD, *What was built*
Type: feat

### What this builds

**The survey mission.** A `.miz` holding no units at all, generated for a given map and loaded only
to be swept. Empty is the whole point: the probe answers "is there room here" and counts vehicles as
obstacles, so anything standing on the map would be baked into the catalogue as permanent scenery
(PRD, *What was learned*). Sweeping from whatever mission is at hand is exactly the mistake that
cost two days this week.

**The sweep.** Two passes, per decision 1: a coarse one at 200 m over the whole map, a fine one at
50 m around the combat zones, airfields and road axes. Each retained point carries the **clear
radius** measured around it, by whichever method ticket 01 found cheapest.

**Resumability is not optional.** A pass measured in tens of minutes will be interrupted — DCS
dropped its connection three times in one evening while this lot was being investigated. The sweep
must stop and continue rather than start over.

### What has to be decided while building

- The file format, and where a map's catalogue lives when versioned in VMCT (decision 5, first
  half).
- What "around the airfields and road axes" means concretely — a radius around each, or a corridor
  along them. Combat zones are easy: they already have a radius.

### Definition of done

- [x] A survey mission can be generated for a map, and holds no units
- [x] The sweep produces a catalogue carrying a clear radius per point, at both spacings
- [x] The sweep can be interrupted and resumed without losing what it has done
- [x] Sweeping the same map twice produces the same catalogue. The small probe is deterministic
      (12 repetitions, 0/12 against 12/12, identical counts), so this is a real assertion rather
      than a formality
- [x] A catalogue is produced for GermanyCW and committed
- [x] Python tests green, and `stylua --check` plus `luacheck` clean wherever Lua is touched

## 03 — the catalogue answers "where does a group this size fit, near here?"

Status: ✅ done — 2026-09-28, verified in game; see the PRD, *What was built*
Type: feat

### What this builds

The read side. Given a point, a search radius and a required clear radius, return the candidate
positions that satisfy them, nearest first. No DCS running, no `Disposition`, no lottery — the
terrain was measured once and is now just data.

**Read the stored radius with a margin, never exactly.** A group's footprint moves by up to
**38.8 m** between draws
([ticket 11](../FIX-PLACEMENT-IGNORES-SCENERY/tickets/11-settle-verifies-the-candidate-it-trusts.md)),
so a group asking for 150 m must be served points comfortably above it, and the size asked for
should be the group's **worst-case** footprint rather than a drawn one.

**On-demand generation** (decision 5, second half): when the versioned catalogue does not cover a
map or an area, this path must say so, and the tooling must offer to sweep it locally rather than
silently returning nothing.

### Definition of done

- [x] A query returns candidates ordered by distance, filtered on the required clear radius
- [x] The margin applied over the stored radius is justified by the 38.8 m measurement rather than
      chosen by feel
- [x] A query outside the catalogue's coverage is **distinguishable** from a query that searched and
      found nothing. They are different answers, and ticket 04 acts on them differently
- [x] Querying is fast enough to run per group while a mission is being built, measured rather than
      assumed
- [x] Python tests green

## 04 — the authoring tools place on clear ground, and say when they cannot

Status: ✅ done — 2026-09-28, verified in game; see the PRD, *What was built*
Type: feat

### What this builds

The rule this whole lot exists for, finally applied: **when the tools choose a position, they choose
a clear one.** The MCP actions that create ground groups consult the catalogue and place the group
where its worst-case footprint fits.

**And a position the mission maker drew stays where they drew it.** Unchanged since David's
arbitration of 2026-08-27, and this ticket must not weaken it. The test is *who chose the position*,
never whether the position is good.

### Out of coverage: place anyway, and say so (decision 4)

When nothing large enough is found — or the catalogue does not cover the area — the group goes where
it was asked to go, and the tool reports it plainly:

> no clear position for 15 vehicles within 1 km, placed as requested

That is ADR 0018: an undocumented dependency may improve quality, it must never be what refuses a
placement. A refusal turns a quality problem into a broken tool.

### Definition of done

- [x] A test: a group the tools place lands on a catalogued clear position — written **with** the
      code, not before it; it fails against the code without the placement
- [x] A position the mission maker declared is **never** moved — the existing arbitration tests stay
      green
- [x] Out of coverage and nothing-found both place as requested and report it in terms a mission
      maker can act on, naming the size asked for and the radius searched
- [x] Verified on a real authoring run: a mission built through `add_group` — the MCP action's own
      function, called directly rather than over the MCP transport — holds no group standing in a
      wood the catalogue could have avoided (8 of 8 clear in DCS, 2026-09-28)
- [x] Python tests green, and the docs updated wherever the behaviour is visible to a mission maker

## 05 — the MCP offers to check its own work in DCS

Status: ✅ done — 2026-09-28, verified in game; see the PRD, *What was built*
Type: feat

### What this builds

The other half of David's original idea, and deliberately last: the server produces a `.miz`, offers
to launch DCS, loads it, reads back which ground units stand in scenery, and reports.

It is the **only** way to validate the end result for real. Everything upstream — the catalogue, the
query, the placement — is a model of the terrain, and a model gets checked against the thing itself.

### What it must measure, and where

**Probe before the units exist, or the numbers are worthless.** This is the mistake that cost two
days: measured after a spawn, a tight SAM battery fails its own test wherever it stands, because the
probe counts vehicles as obstacles. Three published figures were wrong that way — 81, 76 and 69.

So this check must either probe the intended positions **before** spawning, or account for the
group's own vehicles — and it must state which of the two it did, in the report it produces. A
report that does not say how it counted is how this went wrong the first time.

### Definition of done

- [x] ~~The MCP can launch DCS on a generated mission and read ground unit positions back~~ —
      **replaced**: the positions are read from the `.miz` and probed in DCS on the empty survey
      mission. Reading them back from a spawned mission is the measurement this ticket itself warns
      against (vehicles block each other), and launching DCS is the user's to do; the MCP offers the
      command (`offer_clear_ground_check`)
- [x] The report counts vehicles in scenery with a criterion that does not count their own
      neighbours, and names the criterion it used
- [x] The offer is an offer: nothing launches DCS without being asked
- [x] A mission built through ticket 04 is verified this way, and the result is compared with what
      the catalogue predicted. A disagreement is a finding about the catalogue, not noise to smooth
      over
- [x] Python tests green
