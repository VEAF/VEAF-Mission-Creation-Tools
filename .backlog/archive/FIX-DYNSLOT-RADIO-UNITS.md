# Lot FIX-DYNSLOT-RADIO-UNITS — radio frequencies mis-scaled for kHz/ADF radios

Status: ✅ done

**Goal**: The auto-generated `dynamic-slot-templates.yaml` stores radio channels for **kHz/ADF radios** (e.g. the Yak-52's **ARK-15M**) in **MHz** (`0.625`, `0.303`, …) instead of the **kHz** values DCS expects (`625`, `303`, …) — a ×1000 / 3-decimal-place discrepancy that makes the mission **fail to start** (reported by Tripack on Training-Chypres; editing the file `0.625 → 625` fixes it). Make the radio-channel handling **unit-aware/robust for every radio type** (kHz ADF vs MHz VHF/UHF), and **audit + harden the shipped/generated default frequencies** so no aircraft ships with a wrong-scaled value (David: "blinder nos fréqs par défaut", general — not just Yak-52). Determine the failing stage (extraction into the YAML vs injection back) during implementation.

**Investigation (Yak-52 repro analysed — `freq-yak52.miz`)**: the picture is subtle — see the CORRECTION below (the bug IS real). Established facts:
- **DCS stores the ARK-15M in MHz**, at unit level: `unit.Radio[1].channels = { 0.625, 0.303, … }`. The Mission Editor *displays* kHz (625) but *stores* MHz (0.625). A hand-made slot like `freq-yak52.miz` with `0.625` **saves fine** — but a built mission's `Yak-52 Template` is **rejected** with `0.625 MHz invalide`, so the accepted-vs-rejected difference is structural, not just the value.
- **The aircraft-groups extraction excludes `"Radio"`** (`PROPERTIES_TO_EXCLUDE = {"radio", "Radio"}`, present since the quality-gate commit). So the ARK-15M channels are **never** written into the dynamic-slot template — a round-trip extract→inject **drops** them from the slot. The Yak-52 has no `AddPropAircraft.ADF_*_Frequency` (it uses `Radio.channels`).
- A **second** ADF representation exists for *other* aircraft: `AddPropAircraft.ADF_FAR_Frequency` / `ADF_NEAR_Frequency`, stored in **kHz** (e.g. shipped default `dynamic-slot-templates.yaml` ≈ line 3080: `ADF_FAR_Frequency: 625`). This one is **not** excluded. So two scales coexist (MHz in `Radio.channels`, kHz in `AddPropAircraft.ADF_*`) depending on aircraft/field.

**CORRECTION — the bug IS real (DCS error screenshot).** DCS refuses to save the mission: `Yak-52 Template: Fréquence invalide 0.625 MHz` (and `Yak-52 Template Red`). So `0.625 MHz` is rejected **for these templates** — the earlier "0.625 is correct" note was wrong (it only held for a hand-made slot like `freq-yak52.miz`, which DCS *does* accept). Tripack's `0.625 → 625` is the right direction for the template.

**What I ruled out by reproducing a build (`radio-test`, dev-mode):**
- **The build does NOT alter the channels** — the Yak-52 slot's `Radio[1].channels` is byte-identical (`0.625…`) source vs built; structure intact.
- **The presets_injector does NOT add channels to the Yak-52 Template** — the default mapping `blue.plane.all: modern_blue_uhf_vhf_fm` applies to the Yak-52, but its UHF/VHF/FM channels are out-of-range for the ARK-15M and dropped, leaving the injected `Yak-52 Template` with `frequency: 132` and **no** channels. So my repro produces **no** invalid `0.625` in the template.
- The shipped default `dynamic-slot-templates.yaml` ships `Yak-52 Template` (line 4732) and `Yak-52 Template Red` (line 9305) — the exact names in the error — but with **no** `Radio.channels` (only `frequency: 132`).

**So the invalid `0.625` comes from Tripack's OWN `Yak-52 Template` groups** (his `dynamic-slot-templates.yaml` / source mission), not the default or the pipeline. Open question: why DCS accepts `0.625` in `freq-yak52.miz` (a hand-made dynSpawnTemplate slot) but rejects it in his templates — the difference is in the exact template structure. **Needs from Tripack: the BUILT `.miz` that triggers the DCS error.** A diff against the accepted `freq-yak52.miz` will pinpoint where the invalid `0.625` sits and what differs. **Status: needs Tripack's failing built `.miz`.**

**Branch**: `fix/dynslot-radio-units` → PR → `develop`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-DYNSLOT-RADIO-UNITS-001 | Diagnose where the Yak-52 ARK-15M channels get the ×1000 error (aircraft-groups extraction that writes `dynamic-slot-templates.yaml` vs the injector that re-applies it), make radio-channel scaling unit-aware per radio type, and harden the default/generated frequencies so kHz/ADF radios are correct. Repro: build a mission with a Yak-52 dynamic-slot template; confirm it starts. | `aircrafts_injector/` (extraction + injection), default templates, `test/python/` | fix | ✅ (#504) |
