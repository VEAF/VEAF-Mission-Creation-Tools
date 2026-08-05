# Lot FIX-PRIMARY-FREQ-HUMANRADIO — a promoted preset frequency can fall outside the aircraft's tunable range

Status: ✅ done
Branch: fix/FIX-PRIMARY-FREQ-HUMANRADIO → PR #639 → merged into develop

## Problem Statement

Reported by Tripack. The DCS Mission Editor refuses to save a built mission
(`Snowfox_20260728.miz`, Persian Gulf, WWII asset pack aircraft):

```
FW-190D9 Template: Fréquence invalide 134 MHz
FW-190A8 Template: Fréquence invalide 134 MHz
```

Only the **blue** templates are flagged. In the built `.miz`:

- blue `FW-190A8 Template` / `FW-190D9 Template`: `radioSet = true`, `frequency = 134.0`
- red `FW-190A8 Template Red` / `FW-190D9 Template Red`: `radioSet = false`, `frequency = 38.4`

The red groups match no preset, so the injector leaves them alone and they keep DCS's own
default. The blue groups get a preset injected — and the primary frequency the injector
writes is the one DCS rejects.

## Root cause

`PresetsInjectorWorker.process_units` promotes the first channel of the first radio to the
group's primary `frequency` (so the group's ME "frequency" field matches channel 1). The
promotion is gated on two checks only: the radio must not be FM, and the frequency must sit
at or above the 30 MHz floor (`_MIN_PRIMARY_RADIO_MHZ`, FIX-DYNSLOT-RADIO-UNITS).

Neither check is per-aircraft: the guard has no idea what the airframe can actually tune.
The injected preset's channel 1 is `134.0` ("Tact. Victor"), which passes both checks.

But a DCS aircraft has **two** distinct frequency constraints, and only one of them is in
`dcs-radio-specs.yaml`:

| datamine key | meaning | FW-190A8/D9 | in our specs |
|---|---|---|---|
| `panelRadio[].range` | what the radio set can be tuned to across all its channels | 38–156 MHz | ✅ extracted |
| `HumanRadio.minFrequency` / `maxFrequency` | what the ME accepts in the group's **primary frequency** field | 38.4–42.4 MHz | ❌ absent |

134 MHz is inside `panelRadio.range` (so `_drop_out_of_range_channels` keeps it, correctly —
the ME does accept it as a *preset channel*) but far outside `HumanRadio`, which is the range
the ME validates the group's primary frequency against. Hence one single invalid value per
group, and hence a mission that cannot be saved.

The existing code already half-knew this: the FM-primary carve-out in `process_units` is
commented *"FM-primary radios (Gazelle, Ka-50…) have HumanRadio in VHF/UHF range"* — the
concept was understood but never modelled as data.

## Solution

Model `HumanRadio` as data and gate the promotion on it.

1. **Extraction** (`veaf_build/radio_specs_updater.py`): parse the `HumanRadio` block and
   emit a `human_radio: {default_mhz, min_mhz, max_mhz, modulation}` entry per aircraft.
   Regenerate `dcs-radio-specs.yaml` and `doc/mission-maker/dcs-radio-specs.md` against the
   pinned `DATAMINE_REF` (the CI consistency guard re-generates and diffs).
2. **Validator** (`radio_frequency_validator.py`): `get_human_radio(unit_type)` plus
   `fits_human_radio(unit_type, freq_mhz)`, which returns `True` when the aircraft has no
   `human_radio` data (unknown → don't block).
3. **Promotion guard** (`presets_injector_worker.py`): promote channel 1 only when it also
   fits the aircraft's `human_radio` range. When it does not, leave the group's `frequency`
   untouched — which is exactly what makes the red FW-190 groups saveable today.

Not writing the key is the whole fix: the aircraft keeps DCS's own valid default. No
clamping, no substitute channel — those would silently retune the group to something the
mission maker never asked for.

## Verification against the reported mission

Auditing `Snowfox_20260728.miz` through `mission_tools.iter_groups` + the new
`get_human_radio` — 104 human/player groups — returns exactly two offenders:

```
FW-190A8 Template   FW-190A8   frequency=134.0   allowed 38.4-42.4   radioSet=True   blue
FW-190D9 Template   FW-190D9   frequency=134.0   allowed 38.4-42.4   radioSet=True   blue
```

The same two groups DCS names, and no other aircraft in that mission — so the new range data
matches the Mission Editor's own verdict, with no false positive over a 104-group fleet. (The
`.miz` already built still carries 134; it needs a rebuild on ≥ 6.11.6, or the frequency field
set back to 38.4 by hand before saving.)

## Testing Decisions

- Unit tests on the new extraction (`HumanRadio` present / absent / malformed).
- Unit tests on `fits_human_radio` (in range, out of range, unknown type, no data).
- `process_units` with a FW-190A8 and a preset whose channel 1 is 134 MHz → no `frequency`
  key written; with channel 1 at 40 MHz → written.
- Regression: an F-16C (`HumanRadio` 225–399.975) still gets its UHF channel 1 promoted.
- The MiG-15bis HF case (FIX-MIG15-PRIMARY-FREQ) must stay green.

## Out of Scope

- `_drop_out_of_range_channels` and the preset channels themselves — 134 MHz is a legitimate
  *preset* frequency for the FuG 16 and the ME accepts it. Only the primary is wrong.
- The blanket 30 MHz floor and the build-time safety net, both unchanged.
- Picking a *different* channel to promote when channel 1 does not fit (deliberately not
  done, see above).

---

## 01 — Gate the primary-frequency promotion on the aircraft's HumanRadio range

Status: ✅ done

### Goal

Stop the presets injector from writing a group primary `frequency` the DCS Mission Editor
refuses, by extracting the `HumanRadio` min/max range into the radio specs and checking the
promoted channel against it.

### Definition of Done

- [x] `radio_specs_updater.py` parses `HumanRadio` and emits `human_radio:` per aircraft
- [x] `dcs-radio-specs.yaml` + `doc/mission-maker/dcs-radio-specs.md` regenerated at the
      pinned `DATAMINE_REF` (CI consistency guard passes)
- [x] `radio_frequency_validator.get_human_radio()` / `fits_human_radio()` added
- [x] `process_units` promotes channel 1 only when it fits `human_radio`
- [x] Unit tests for extraction, validator and the promotion guard; FW-190A8 @ 134 MHz no
      longer promoted, F-16C and MiG-15bis unaffected
- [x] `doc/mission-maker/scripts/` / presets doc mention the primary-frequency rule
- [x] `CHANGELOG.md` entry, PATCH version bumped in `pyproject.toml` + `plugin.json`
- [x] mypy exclusion for `presets_injector_worker` dropped if listed (ratchet policy)
