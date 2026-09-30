# FEAT-CLEAR-GROUND-AT-AUTHORING — when the tools place a group, they place it somewhere measured clear

Status: ✅ done — merged in #1019 on 2026-09-28; tickets 01 to 05 built and verified in game (see *What was
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
