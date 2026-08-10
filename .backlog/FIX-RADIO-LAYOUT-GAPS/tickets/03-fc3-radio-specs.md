# 03 — Cover Flaming Cliffs aircraft in the radio specs

Status: ✅ done — 2026-08-10
Type: fix

## Why

See the [PRD](../PRD.md), gap 3. `dcs-radio-specs.yaml` holds 87 types and **not one FC3
aircraft**. The packer projects onto physical radios read from that file, so `Su-27`, `Su-25T`,
`Su-25`, `Su-33`, `MiG-29A`, `MiG-29S`, `MiG-29G`, `J-11A`, `A-10A`, `F-15C` — and `F-14BU` —
receive **no presets at all** under the preset-plan model.

They are playable and VEAF missions put player slots on them. Measured on `Foothold_AF_2.4.1`:
converting to the plan model made **7 types lose their kneeboard plate** (F-14BU, J-11A,
MiG-29A/G/S, Su-25T, Su-27) until a legacy override layer was added back purely for them. Close
this gap and that layer disappears.

## Tasks

- [ ] Determine whether the pinned `dcs-lua-datamine` exposes FC3 radio definitions at all, or
      whether `veaf_build/radio_specs_updater.py` filters them out (e.g. on a flag separating
      full-fidelity modules).
- [ ] If the datamine has them: fix the generator, regenerate, confirm the 11 types appear.
- [ ] If it does not: add them as **hand-maintained entries** sourced from the aircraft manuals.
      The FC3 Russian fleet is mostly one `R-862` V/UHF plus an `ARK` ADF — which makes
      [ticket 01](01-adf-not-a-comm-radio.md) a prerequisite, or they all inherit the ADF bug.
- [ ] Document which entries are hand-maintained so the next regeneration does not silently drop
      them (the file is generated — a hand edit is at risk by default).
- [ ] Once covered: drop the corresponding overrides from `tools/foothold/presets.yaml` and
      rebuild.
- [ ] CHANGELOG + version bump.

## Verify

The acceptance test is the Foothold file **shrinking**: every type removed from its
`presets_assignments` must keep its kneeboard plate, with the same channels as the legacy override
produced.


## Measured 2026-08-08 — the datamine is not withholding them, it does not model them

The ticket asks "whether the datamine exposes FC3 radios at all, or whether the generator filters
them out". Measured against the pinned ref, cloning it and parsing directly:

| Type | File in datamine | Declares `panelRadio` |
|---|---|---|
| `Su-27`, `Su-25`, `Su-25T`, `Su-33` | yes | **no** |
| `MiG-29A`, `MiG-29S`, `MiG-29G` | yes | **no** |
| `J-11A`, `A-10A`, `F-15C` | yes | **no** |
| `F-14BU` | yes | **yes** (2 radios) |

So the generator is **not** at fault — there is nothing upstream to extract. FC3 modules have no
clickable cockpit, and the datamine only carries radios that are modelled as panel devices.

Two consequences:

- **`F-14BU` is no longer missing.** It arrived with the datamine pin bump of 2026-08-08 (#669) and
  is in the shipped specs now, so it should come off this ticket's list.
- **The remaining 10 need hand-written data**, exactly like ticket 02's AJS-37 FM radio (measured
  the same day: the datamine declares a *single* radio for the AJS-37, `103.0–400.0 MHz`, so its
  FR24 FM set is absent upstream too, not lost by us).

That is one shape of work, not two: a **VEAF-maintained overlay** for radios DCS has but the
datamine does not model, merged over the generated specs the way `dcs_rejects_on_load` already is.
Worth deciding before either ticket is picked up — and worth deciding *with* David, since the FC3
radio data has to come from somewhere authoritative.

## Measured 2026-08-10 — there is no radio hardware to describe

The ticket's fallback was *"add them as hand-maintained entries sourced from the aircraft manuals"*.
That premise does not hold. Across **40 real VEAF missions**:

| player slots | with a `Radio` preset table | without |
|---|---:|---:|
| **non-FC3** | **2105** | 74 |
| **FC3** | **0** | 110 |

37 of the 40 missions use presets, so this is not "these missions have none": **FC3 is excluded as a
category**. DCS exposes no settable radio for those airframes — which is what David had said all
along (no native radios, SRS simulates them). Writing specs for them would be inventing hardware.

The Foothold workaround carries the same illusion. Its comment says *"remove a type from
`presets_assignments` as soon as it appears in `dcs-radio-specs.yaml`"* — describing a future that
cannot arrive.

### What the workaround actually buys

A **kneeboard plate**. That is also precisely what the ticket measured as lost (*"7 types lost their
kneeboard plate"*) — not the in-game radio. The plate is the only thing that has ever reached an FC3
pilot, who dials the frequencies into SRS by hand.

## Decision — David, 2026-08-10

**The kneeboard is the deliverable, on all three bands (UHF, VHF, FM).**

So FC3 needs a declared **band assignment** — what the plate should list — not fake hardware. And a
second choice follows from it, taken here rather than left implicit:

> **The build must write no `Radio` table into an FC3 unit.** They have none; writing one would be
> data DCS ignores at best. That also removes the need to know whether the Mission Editor tolerates
> it — David is testing that separately, out of interest rather than as a blocker.

### Shape of the work

- The overlay (`dcs-radio-specs-overrides.yaml`, built for ticket 02) declares the three bands for
  the 10 types, marked **kneeboard-only**. The bands have to live where `get_radios` looks, because
  that is what lets the packer build a preset at all; the marker is what stops it being injected.
- `presets_injector_worker` records the resolved preset for the plate and skips the write for a
  kneeboard-only type — no `radioSet`, no `communication`, no `process_units`.
- Then `tools/foothold/presets.yaml` loses its FC3 override, and its comment loses the instruction
  that can never be followed.

### Acceptance

- [ ] The 10 FC3 types get a kneeboard plate from the shipped defaults, with no per-mission override.
- [ ] No FC3 unit in a built mission carries a `Radio` table — asserted on a real build, not only in
      a unit test.
- [ ] The Foothold file shrinks, and every type removed from it keeps its plate.

## Done

- The ten types declare all three bands in `dcs-radio-specs-overrides.yaml`, flagged
  `kneeboard_only`. The bands live in the specs because that is where `get_radios` looks; the flag is
  what keeps it honest.
- `presets_injector_worker.process_groups` records the plate and then **stops** for such a type — no
  `radioSet`, no `communication`, no `process_units`.
- `tools/foothold/presets.yaml` lost its legacy layer: eleven aircraft entries plus the
  `radios_collection` and `presets_collection` behind them, which nothing else referenced.

### Acceptance, checked on a real mission

Run against `VEAF-Missile-Training` (543 player slots) with the **Foothold** presets file:

```
FC3 types that got a plate: F-15C, MiG-29A, MiG-29G, Su-25, Su-25T, Su-27
FC3 slots with a Radio table after the build: 0
```

So the plate survives the override's removal, and nothing is written into an airframe that has
nowhere to read it. David's separate Mission Editor test is now informative rather than blocking.

### One thing worth remembering

The overlay entries first carried a `type: uhf` key per radio, by analogy with `radios_collection`.
`AircraftRadio` has no such field — the band is classified from the **ranges** — so the generator
would have dropped it in silence. Caught before regenerating, and the reason is written beside the
entries so nobody adds it back.
