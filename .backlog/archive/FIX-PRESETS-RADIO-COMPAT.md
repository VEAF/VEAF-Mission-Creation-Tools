# Lot FIX-PRESETS-RADIO-COMPAT — skip presets incompatible with an aircraft's radio

Status: ✅ done

**Goal**: `inject-presets` replaces each player aircraft's `Radio` with the preset resolved from `presets.yaml` (often via an `all` fallback). When that preset's frequencies are entirely out of range for the aircraft's radio hardware — e.g. a UHF/VHF/FM preset resolved for a **Yak-52**, whose only radio is the sub-MHz ARK-15M (0.1–1.795 MHz) — the build overwrites the correct radio with frequencies the DCS Mission Editor refuses to save (*"Invalid frequency 243 MHz"*). The radio-frequency validator already knows each aircraft's valid ranges (`dcs-radio-specs.yaml`). Fix: before injecting, if **every** preset frequency is invalid for a *known* aircraft, skip the injection and keep the original radio (a clear warning is logged). Partially-valid presets are still injected (the existing per-frequency warning/report covers their stray channels). Verified end-to-end on the demo mission: the Yak-52 keeps its ARK-15M radio (no 243); only the Yak-52 is skipped, F18/A-10/M-2000C presets are untouched. Note: 243 MHz is the legitimate UHF guard channel and is valid for the F18/A-10 — the bug was applying it to the Yak-52, not the channel itself.

**Branch**: `fix/PRESETS-RADIO-COMPAT` → PR → `develop`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-PRESETS-RADIO-001 | `_preset_radio_compatible` in the presets worker: skip injection when every preset frequency is out of range for a known aircraft (keep its radio); inject otherwise. Regression tests (Yak-52 skipped, FA-18C kept, unknown aircraft kept, partially-valid kept). | `presets_injector/presets_injector_worker.py`, `test/python/` | fix | ✅ |
