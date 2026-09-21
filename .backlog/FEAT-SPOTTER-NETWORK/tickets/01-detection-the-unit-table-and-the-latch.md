# 01 — Detection: the unit table, the latch, and line of sight

Status: ⬜ ready

The first half of the mechanism: **who sees what**. A spotter that acquires an aircraft records the
acquisition and nothing else — no message leaves the unit until ticket 03 gives it somewhere to go.
That split is deliberate: detection is testable on its own, and it is where the unit table and the
two anti-chatter guards live.

Everything here goes in `src/scripts/veaf/veafSkynetIadsHelper.lua`, per the decision of 2026-09-20.
No separate module.

## Groundwork the mocks do not have yet

Checked on 2026-09-21: `test/lua/dcs_mocks.lua` has **neither `land.isVisible` nor `hasAttribute`**
on its unit doubles. Both are load-bearing here, so both have to be added before a single assertion
can be written.

| What | Where | Shape |
|---|---|---|
| `land.isVisible(from, to)` | the `land` table, `dcs_mocks.lua:458` | returns true by default; a test that cares overrides it, the way `getHeight` is overridden today |
| `unit:hasAttribute(name)` | the unit doubles built in the test files | reads a per-unit attribute set; `AIEN.lua:4500` is the reference for how the real API is called |

Give `land.isVisible` a **recording** double, not a silent one — the design's whole claim is that
the ray is traced only on transitions, and a test cannot check "never per beat per pair" against a
stub that forgets it was called.

## The unit table

One table, three columns, keyed on DCS attributes and **tested most specific first**, the way AIEN
does it. Attribute names verified against `AIEN.lua`, which runs in game.

| Attribute | Detection | Relays | Speed class |
|---|---|---|---|
| `AWACS`, `EWR` | — | yes | fast / mobile |
| `SAM elements` | — | yes | mobile |
| `Air` minus the above (aeroplanes) | 30 km | yes | fast |
| `Helicopters` | 15 km | yes | fast |
| `Ships` | 12 km | yes | mobile |
| `MANPADS` | 10 km | yes | slow |
| `AAA` | 8 km | yes | mobile |
| `Air Defence vehicles` | 8 km | yes | mobile |
| `Infantry` | 4 km | yes | slow |
| `Artillery`, `MLRS` | 3 km | yes | mobile |
| `Tanks`, `IFV`, `APC`, `Armored vehicles` | 3 km | yes | mobile |
| `Unarmed vehicles`, `Trucks` | 3 km | yes | mobile |
| anything else, statics, buildings | — | no | slow |

Detection and relaying are **two independent properties**, because they genuinely are: a command
vehicle sees little and relays perfectly, an ammunition dump does neither. A dash in the detection
column means the unit never sees anything, not that it sees a little.

**A SAM site relays and never spots.** Its own detection is the last line of defence's job, with a
radius already drawn once between 10 and 15 km; a second competing radius would mean the larger one
always wins and the other setting is dead weight — the exact failure mode of the `ewr` spawn option,
inert for four years because nothing ever applied it. `AWACS` and `EWR` are excluded for the same
reason: `veafSkynetIadsHelper.lua:1814` already enrols them as EW radars.

The exclusion stops there. An earlier draft excluded the whole `Air` attribute, which was wrong — a
fighter or a transport belongs to no Skynet network. A consequence worth knowing and judged
desirable on 2026-09-21: **a player flying for the network's coalition becomes a spotter.**

The numbers are reasoned, not sourced, and they were put to David on 2026-09-21 and drew no
objection. They are not to be reopened without a reason from play. Their *shape* is the argument:
aircraft see furthest and by a wide margin; air-defence units see furthest on the ground because
watching the sky is their job; armour sees least, a closed-down tank having a poor view of anything
above the horizon. Ground ranges stay well under the 20 km radio range on purpose, so what limits
the network is the sensing and not the plumbing — **aeroplanes are the deliberate exception**, at
30 km against a 20 km radio, so an aircraft has to close on the ground network to pass the word.

**Each unit draws its own range once for the mission**, ±20 % around the table value. Drawing per
attempt would make the limit flicker, which is why Skynet draws its last-line radius once per site
too.

`DCS exposes no JTAC attribute`, so the first version does not distinguish them. If it ever matters
the way in is a list of unit names from the mission maker — noted, not designed, and out of scope
here.

## The latch

Per aircraft, each spotter is **armed** or **triggered**.

- Armed, aircraft comes into range **with line of sight** → reports once, becomes triggered. Silent
  from then on while it keeps seeing that aircraft.
- Triggered, loses the aircraft → after **3 consecutive beats** without contact it returns to armed,
  and will report that aircraft again on reacquisition.

Two guards, covering different causes, and **both are needed**:

- **A 10 % distance margin.** Acquired at the unit's range, lost only beyond range × 1.1. An
  aircraft orbiting exactly on the limit stays held instead of flickering. One extra comparison on a
  distance already computed.
- **The 3-beat tolerance**, for terrain masking — an aircraft dropping behind a ridge for a few
  seconds is not lost.

The tolerance alone lets an aircraft orbiting on the limit re-trigger every time it stays out for
four beats; the margin alone does nothing about ridges.

## Line of sight, both ways

`land.isVisible` gates **acquisition and loss alike**, traced from **2 m above the spotter** — the
offset CTLD uses, so a spotter looks from its eyes rather than from the mud. An aircraft following a
valley is not seen by the spotter behind the crest, which is the profile that started this whole
investigation.

The ray is traced **only on transitions**, never per beat per pair. That is what makes it
affordable, so it is a property to assert, not a comment to write.

## The detection loop

One loop at **5 s**, aligned on Skynet's own cycle — an aircraft at 900 km/h covers 1.2 km between
passes. It does not depend on the graph, which is ticket 02: a freshly spawned unit therefore sees
immediately even though it cannot yet relay.

## Tests

- Latch: reports once on acquisition; silent while held; re-arms after **3** beats, not 2.
- Distance margin: an aircraft orbiting between range and range × 1.1 produces **one** report.
- Line of sight: masked at acquisition → no report; masked at loss → contact lost.
- The ray is traced on transitions only: hold a contact over several beats and assert the recorded
  `isVisible` call count does not grow per beat.
- The table resolves most-specific-first: a `SAM elements` unit relays and never detects; `AWACS`
  and `EWR` likewise; an aeroplane detects at 30 km; an unknown type neither detects nor relays.
- The range is drawn **once per unit**: read it twice across several beats and assert the same
  value, and that two units of the same type can differ.
- **Wiring**: the 5 s loop is actually scheduled. This is the defect class that shipped green in
  August — tests that called the handler and never what branches it.

## Definition of done

- `land.isVisible` and `hasAttribute` available in the mocks, the first one recording its calls.
- Detection, the table, the latch and the line-of-sight gate written and covered by the tests above.
- Nothing propagates yet, and nothing is scheduled unless the feature is on — the setting itself
  arrives in ticket 04, so until then guard on an internal flag defaulting to off.
- `poetry run test-lua` green, `stylua --check src/scripts/veaf/ test/lua/` clean, and the Lua
  coverage floor in `.github/workflows/lua-ci.yml` bumped so it sits no more than ~2 points under
  the measured figure.
- `CHANGELOG.md` updated under `[Unreleased]`, appended at the end of the section.
