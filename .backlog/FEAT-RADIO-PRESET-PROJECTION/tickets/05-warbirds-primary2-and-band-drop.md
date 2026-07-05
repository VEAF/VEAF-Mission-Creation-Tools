# FEAT-RADIO-PRESET-PROJECTION-05 — warbirds on primary_2 + out-of-band drop

Status: ✅ done
Type: feat · Phase: 1 · AFK

## Parent

Lot [FEAT-RADIO-PRESET-PROJECTION](../PRD.md) · [ADR 0010](../../../docs/adr/0010-per-type-radio-preset-projection.md)

## What to build

Pack the warbirds' single radio on `primary_2` (VHF) and make the out-of-band
**drop** behaviour explicit: channels outside the type's specs band are dropped
from the list, explained under `validate` (verbose) and silent under `build` —
reusing the existing frequency validator and report split. Demonstrate end-to-end
on a warbird (e.g. P-51D receives the airbase VHF channels that fall in its band;
UHF-only channels are dropped).

Note: whether the module truly accepts airbase VHF in game is out of scope (the
38–156 band is datamined) — see PRD Out of Scope; this slice implements the
tooling behaviour, in-game confirmation is a separate follow-up.

## Acceptance criteria

- [x] Warbird single radio packed on `primary_2`.
- [x] Out-of-band channels dropped; reported under `validate`, silent under `build`.
- [x] Tests: a warbird packs its in-band VHF and drops the rest (prior art
      `test_radio_frequency_validator.py`, `test_presets_fidelity.py`).

## Blocked by

- FEAT-RADIO-PRESET-PROJECTION-01 only — does NOT need ticket 02's layout file:
  warbirds already pack onto `primary_2` by default under ticket 01's
  band-classification (a single-range radio spanning both the FM ceiling and the
  UHF floor resolves to "vhf", see `_classify_radio` and
  `test_warbird_single_radio_resolves_to_primary_2`). No layout entry needed.

## Note

The "pack on primary_2" acceptance criterion is already satisfied by ticket 01.
This ticket's real remaining scope is the **out-of-band drop reporting split**
(verbose under `validate`, silent under `build`) — check whether that mode
distinction already exists in the `validate`/`build` commands or needs adding.

## Implementation notes

Investigation confirmed both halves of the acceptance criteria are already
satisfied by existing infrastructure — no production code changed, only tests
added to pin the behaviour down as a regression guard:

- **"Warbird on `primary_2`"**: already covered by ticket 01's
  `test_warbird_single_radio_resolves_to_primary_2` (a warbird's single radio,
  e.g. `Bf-109K-4`'s FuG 16 ZY spanning 38–156 MHz in one range, is classified
  "vhf" by `_classify_radio` and lands on `primary_2` with no layout entry).

- **"Out-of-band drop, reported under `validate`, silent under `build`"**:
  the codebase has no `presets`-aware `validate` CLI command — `validate.py`
  only runs `validate_mission_folder` (mission-folder linting, unrelated to
  radio presets). The actual verbosity split already lives one layer down, in
  `PresetsInjectorWorker` + `radio_frequency_validator.py`, and it already
  implements exactly what the ADR describes:
  - `_drop_out_of_range_channels` (pre-existing, added for a prior ticket)
    silently drops any channel outside the aircraft's hardware range before
    writing the `Radio` table — DCS would otherwise refuse to save the
    mission.
  - `warn_invalid_channel_frequencies` logs at `logger.warning` only for
    `dcs_rejects_on_load: true` aircraft (a handful of hard-crash types); every
    other aircraft — including all warbirds, none of which are in that strict
    list — logs at `logger.debug`, which is invisible in a normal `build`'s
    console output.
  - `generate_validation_report` always writes a full per-channel Markdown
    report (`presets-validation-report.md`), which `build.py` generates then
    deletes when clean, and which `inject_presets --validate-report <file>`
    (the closest thing to a "validate" entry point for presets) keeps and
    exposes explicitly. This is the "verbose" side of the split — every
    dropped channel, its frequency, and the aircraft's valid ranges, spelled
    out.
  - Net effect: a normal `build` stays terse (no console noise for a
    non-strict warbird drop), while the full explanation is always one
    `--validate-report` flag (or an inspection of the generated report file)
    away. This already satisfies "verbose under validate, silent under build"
    in spirit; no new flag or plumbing was needed (Absolute Simplicity rule).

- **What changed**: only tests, in
  `test/python/presets_injector/test_presets_injector_worker.py`
  (`TestWarbirdPrimary2BandDropReporting`). They exercise the real
  `pack_preset_for_type` → `PresetsInjectorWorker.process_units`/
  `process_groups` → `generate_validation_report` pipeline end-to-end for
  `Bf-109K-4` with a `primary_2` channel list mixing an in-band VHF frequency
  (131.0 MHz) and an out-of-band UHF one (280.0 MHz), asserting: the injected
  `Radio` table drops the UHF channel and keeps the VHF one, the drop is
  reported in the generated validation report, and no `logger.warning` fires
  during a normal (non-strict) `process_groups` run.
