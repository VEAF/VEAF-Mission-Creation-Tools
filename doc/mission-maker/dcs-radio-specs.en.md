# DCS radio frequency specifications

Reference table of the valid radio frequency ranges for every player-flyable DCS aircraft. Used by
`inject-presets` to check that the frequencies declared in `presets.yaml` are compatible with the
target aircraft's radio hardware.

<!-- BEGIN generated: source note -->
> **Source**: [dcs-lua-datamine](https://github.com/Quaggles/dcs-lua-datamine)  
> Source ref: `d75d7ac540ab5683b07d6a7c0f59b48528e8ff1a`  
> Re-generate with `veaf-build update-dcs-data --radio` after a pin bump.
<!-- END generated: source note -->

---

## Per-type quirks — handled for you

With the recommended `channel_lists` format (see
[the `presets.yaml` formats](../PIPELINE_REFERENCE.en.md#two-authoring-formats)), you declare your
channel lists **once per coalition**, per radio role (primary UHF, primary VHF, FM…). The build
then projects them onto **each** aircraft's physical radios, handling that airframe's hardware
quirks on its own: the Mi-24P and CH-47 channel 0, the OH-58D's reserved "M"/"C" slots, the
Viggen's (AJS-37) single radio with its hard-coded FR22/FR24 special channels, and so on. You have
**nothing** to configure for those aircraft: a frequency change propagates to the whole fleet.

> The per-type projection rules (which aircraft has which quirk, and how they are encoded) are
> documented on the developer side:
> [Per-type radio preset projection](../developer/radio-preset-projection.en.md).

---

## Critical aircraft (`dcs_rejects_on_load`)

Some aircraft make DCS raise a blocking error when the mission loads if a preset frequency falls
outside their valid radio range. They carry `dcs_rejects_on_load: true` in `dcs-radio-specs.yaml`
and always emit a `WARNING` during `veaf-tools mission build`.

Currently known critical aircraft:

| Aircraft | DCS ID | Valid range |
|----------|--------|-------------|
| MiG-15bis | `MiG-15bis` | 3.75–5 MHz (AM, RSI-6K HF set) |
| MiG-15bis (FC) | `MiG-15bis_FC` | 3.75–5 MHz (AM, RSI-6K HF set) |
| MiG-19P | `MiG-19P` | 100–150 MHz |
| Gazelle SA342M | `SA342M` | 30–87.975 MHz (FM only) |

Every other aircraft stores the frequencies silently without crashing. Such problems are still
reported in the `presets-validation-report.md` generated after each build.

If you find another aircraft that makes DCS reject the mission, add `dcs_rejects_on_load: true` to
its entry in `src/python/veaf-tools/presets_injector/data/dcs-radio-specs-overrides.yaml` and open
a pull request. Do not edit `dcs-radio-specs.yaml`: it is regenerated from the datamine, and any
correction written there is lost on the next run.

---

## Flaming Cliffs aircraft: kneeboard only (`kneeboard_only`) {#kneeboard-only}

**If you fly FC3 and your radio presets are empty, that is expected.** Ten Flaming Cliffs aircraft
have **no settable radio at all**: DCS gives them no `Radio` table, so there is nothing for a channel
list to be written into. This is not a VEAF MCT limitation, it is the airframe.

The measurement that settled it: across 40 real missions, the 110 player slots of these types carry
**no** `Radio` table, against 2105 non-FC3 slots that do. Inventing hardware specifications for them
would have produced frequencies DCS ignores.

What the build does instead: it **renders the kneeboard**
(`KNEEBOARD/<type>/IMAGES/presets.png`) with all three bands, and writes **nothing** into the
mission. You set your frequencies by hand in the cockpit, or use them in SRS, reading them off the
kneeboard.

| Aircraft | DCS ID |
|----------|--------|
| A-10A | `A-10A` |
| F-15C | `F-15C` |
| J-11A | `J-11A` |
| MiG-29A | `MiG-29A` |
| MiG-29G | `MiG-29G` |
| MiG-29S | `MiG-29S` |
| Su-25 | `Su-25` |
| Su-25T | `Su-25T` |
| Su-27 | `Su-27` |
| Su-33 | `Su-33` |

**For the mission maker**: these types are declared `kneeboard_only: true` in
`dcs-radio-specs-overrides.yaml`. A preset targeting one of them is not an error — it produces a
kneeboard and nothing else, with no warning, because that is the intended behaviour.

---

## The group's primary frequency (`human_radio`) {#primary-frequency}

A DCS aircraft enforces **two** different frequency constraints, and they are easy to confuse:

| Constraint | What it bounds | Where it shows up |
|------------|----------------|-------------------|
| `radios` ranges (tables below) | the radio's **preset channels** | the slot's radio tab |
| `human_radio` | the **group's primary frequency** | the group's "frequency" field in the editor |

For most modern aircraft the second is as wide as the first and the distinction is invisible. But
for 27 aircraft it is **narrower** — sometimes radically. The FW-190A8 accepts preset channels from
38 to 156 MHz, while its primary frequency is confined between 38.4 and 42.4 MHz.

If the primary frequency falls outside the `human_radio` range, the Mission Editor **refuses to
save the mission**, with a message such as:

```
FW-190A8 Template: Invalid frequency 134 MHz
```

`inject-presets` normally promotes channel 1 of the first radio to the group's primary frequency, so
that the editor's field matches channel 1. When that channel falls outside the aircraft's
`human_radio` range, the promotion is **skipped**: the group keeps its own frequency (the one from
the source mission, or DCS's own default), which keeps the mission saveable. The build reports it in
detailed mode; the presets themselves are injected as usual.

The `human_radio` ranges are extracted from the datamine along with the rest of the specs and live
in `dcs-radio-specs.yaml`, under each aircraft:

```yaml
FW-190A8:
  human_radio:
    min_mhz: 38.4
    max_mhz: 42.4
    default_mhz: 38.4      # DCS's own default
    modulation: AM
```

An aircraft with no `human_radio` block enforces no bound: the promotion happens as before.

<!-- BEGIN generated: primary frequency -->
### Aircraft whose primary frequency is restricted

| Aircraft | DCS ID | Primary min (MHz) | Primary max (MHz) | Default (MHz) | Modulation |
|----------|--------|------------------:|------------------:|--------------:|------------|
| **A-6E** | `A6E` | 225.000 | 399.950 | 305.000 | AM |
| **AJS37** | `AJS37` | 103.000 | 399.950 | 305.000 | AM |
| **AV-8B N/A** | `AV8BNA` | 30.000 | 399.975 | 243.000 | AM |
| **F4U-1D** | `F4U-1D` | 118.000 | 390.000 | 124.000 | AM |
| **F4U-1D Mk.IV** | `F4U-1D_CW` | 118.000 | 390.000 | 124.000 | AM |
| **Fw 190 A-8** | `FW-190A8` | 38.400 | 42.400 | 38.400 | AM |
| **Fw 190 D-9** | `FW-190D9` | 38.400 | 42.400 | 38.400 | AM |
| **Hawk** | `Hawk` | 100.000 | 156.000 | 127.500 | AM |
| **JF-17** | `JF-17` | 30.000 | 399.975 | 243.000 | AM |
| **Ka-50** | `Ka-50` | 100.000 | 400.000 | 124.000 | AM |
| **Ka-50 III** | `Ka-50_3` | 100.000 | 400.000 | 124.000 | AM |
| **M-2000C** | `M-2000C` | 225.000 | 399.975 | 251.000 | AM |
| **Mi-24P** | `Mi-24P` | 100.000 | 400.000 | 127.500 | AM |
| **Mi-8MTV2** | `Mi-8MT` | 100.000 | 400.000 | 127.500 | AM |
| **MiG-29A  Fulcrum** | `MiG-29 Fulcrum` | 100.000 | 399.975 | 124.000 | AM |
| **Mosquito FB Mk. VI** | `MosquitoFBMkVI` | 0.200 | 156.000 | 124.000 | AM |
| **P-47D-30** | `P-47D-30` | 100.000 | 156.000 | 124.000 | AM |
| **P-47D-30 (Early)** | `P-47D-30bl1` | 100.000 | 156.000 | 124.000 | AM |
| **P-47D-40** | `P-47D-40` | 100.000 | 156.000 | 124.000 | AM |
| **P-51D-25-NA** | `P-51D` | 100.000 | 156.000 | 124.000 | AM |
| **P-51D-30-NA** | `P-51D-30-NA` | 100.000 | 156.000 | 124.000 | AM |
| **SA342L** | `SA342L` | 118.000 | 143.975 | 124.000 | AM |
| **SA342M** | `SA342M` | 118.000 | 143.975 | 124.000 | AM |
| **SA342Minigun** | `SA342Minigun` | 118.000 | 143.975 | 124.000 | AM |
| **SA342Mistral** | `SA342Mistral` | 118.000 | 143.975 | 124.000 | AM |
| **TF-51D** | `TF-51D` | 100.000 | 156.000 | 124.000 | AM |
| **Yak-52** | `Yak-52` | 118.000 | 136.975 | 132.000 | AM |
<!-- END generated: primary frequency -->

---

<!-- BEGIN generated: aircraft tables -->
## Fixed-wing aircraft

| Aircraft | DCS ID | Radio | Min (MHz) | Max (MHz) | Modulation |
|----------|--------|-------|----------:|----------:|------------|
| **A-10C** | `A-10C` | VHF AM: ARC-186 | 116.000 | 151.975 | AM / FM |
|  |  | UHF AM: ARC-164 | 225.000 | 399.975 | AM / FM |
|  |  | VHF FM: ARC-186 | 30.000 | 87.995 | AM / FM |
| **A-10C II** | `A-10C_2` | UHF/VHF: ARC-210 | 30.000 | 87.975 | FM |
|  |  |  | 108.000 | 135.995 | AM |
|  |  |  | 136.000 | 155.995 | AM / FM |
|  |  |  | 156.000 | 173.975 | FM |
|  |  |  | 225.000 | 399.975 | AM / FM |
|  |  | UHF AM: ARC-164 | 225.000 | 399.975 | AM / FM |
|  |  | VHF FM: ARC-186 | 30.000 | 87.995 | AM / FM |
| **A-6E** | `A6E` | UHF AN/ARC-159 #1 | 225.000 | 399.975 | AM / FM |
|  |  | UHF AN/ARC-159 #2 | 225.000 | 399.975 | AM / FM |
| **AJS37** | `AJS37` | Radio frequencies | 103.000 | 400.000 | AM / FM |
|  |  |  | 30.000 | 34.000 | FM |
| **AV-8B N/A** | `AV8BNA` | V/UHF Radio 1 | 30.000 | 400.000 | AM / FM |
|  |  | V/UHF Radio 2 | 30.000 | 400.000 | AM / FM |
|  |  | V/UHF RCS Presets | 30.000 | 400.000 | AM / FM |
| **Bf 109 K-4** | `Bf-109K-4` | FuG 16 ZY | 38.000 | 156.000 | AM / FM |
| **C-101CC** | `C-101CC` | V/TVU-740 | 118.000 | 399.975 | AM / FM |
| **C-101EB** | `C-101EB` | AN/ARC-164 | 225.000 | 399.975 | AM / FM |
| **C-130J-30** | `C-130J-30` | UHF-1/2 | 225.000 | 399.975 | AM |
|  |  | VHF-1/2 | 30.000 | 200.975 | AM |
| **Christen Eagle II** | `Christen Eagle II` | KY 197A | 118.000 | 140.000 | AM / FM |
|  |  |  | 220.000 | 390.000 | AM / FM |
| **F-100D** | `F-100D` | AN/ARC-34 | 225.000 | 399.900 | AM / FM |
| **F-14A Late** | `F-14A-135-GR` | UHF AN/ARC-159 | 225.000 | 399.975 | AM / FM |
|  |  | VHF/UHF AN/ARC-182 | 30.000 | 87.975 | AM / FM |
|  |  |  | 108.000 | 173.975 | AM / FM |
|  |  |  | 225.000 | 399.975 | AM / FM |
| **F-14A** | `F-14A-135-GR-Early` | UHF AN/ARC-159 | 225.000 | 399.975 | AM / FM |
|  |  | VHF/UHF AN/ARC-182 | 30.000 | 87.975 | AM / FM |
|  |  |  | 108.000 | 173.975 | AM / FM |
|  |  |  | 225.000 | 399.975 | AM / FM |
| **F-14A Export** | `F-14A-95-GR` | UHF AN/ARC-159 | 225.000 | 399.975 | AM / FM |
|  |  | VHF/UHF AN/ARC-182 | 30.000 | 87.975 | AM / FM |
|  |  |  | 108.000 | 173.975 | AM / FM |
|  |  |  | 225.000 | 399.975 | AM / FM |
| **F-14B** | `F-14B` | UHF AN/ARC-159 | 225.000 | 399.975 | AM / FM |
|  |  | VHF/UHF AN/ARC-182 | 30.000 | 87.975 | AM / FM |
|  |  |  | 108.000 | 173.975 | AM / FM |
|  |  |  | 225.000 | 399.975 | AM / FM |
| **F-14B(U)** | `F-14BU` | UHF AN/ARC-159 | 225.000 | 399.975 | AM / FM |
|  |  | VHF/UHF AN/ARC-182 | 30.000 | 87.975 | AM / FM |
|  |  |  | 108.000 | 173.975 | AM / FM |
|  |  |  | 225.000 | 399.975 | AM / FM |
| **F-15E S4+** | `F-15ESE` | UHF Radio 1 | 225.000 | 399.975 | AM / FM |
|  |  | V/UHF Radio 2 | 30.000 | 87.975 | AM / FM |
|  |  |  | 108.000 | 117.975 | AM / FM |
|  |  |  | 118.000 | 173.975 | AM / FM |
|  |  |  | 225.000 | 399.975 | AM / FM |
| **F-16CM bl.50** | `F-16C_50` | COMM 1 (UHF) AN/ARC-164 | 225.000 | 399.975 | AM |
|  |  | COMM 2 (VHF) AN/ARC-222 | 30.000 | 87.975 | FM |
|  |  |  | 116.000 | 155.975 | AM |
| **F-4E-45MC** | `F-4E-45MC` | UHF AN/ARC-164 COMM channels | 225.000 | 399.950 | AM / FM |
|  |  | UHF AN/ARC-164 AUX channels | 265.000 | 284.900 | AM / FM |
| **F-5E-3** | `F-5E-3` | UHF Radio AN/ARC-164 | 225.000 | 399.999 | AM / FM |
| **F-86F** | `F-86F Sabre` | AN/ARC-27 | 225.000 | 399.900 | AM / FM |
| **F-86F FC** | `F-86F_FC` | AN/ARC-27 | 225.000 | 399.900 | AM / FM |
| **F4U-1D** | `F4U-1D` | ARC-5 | 100.000 | 150.000 | AM / FM |
|  |  |  | 220.000 | 390.000 | AM / FM |
|  |  | ARR-2 | 100.000 | 150.000 | AM / FM |
|  |  |  | 220.000 | 390.000 | AM / FM |
| **F4U-1D Mk.IV** | `F4U-1D_CW` | ARC-5 | 100.000 | 150.000 | AM / FM |
|  |  |  | 220.000 | 390.000 | AM / FM |
|  |  | ARR-2 | 100.000 | 150.000 | AM / FM |
|  |  |  | 220.000 | 390.000 | AM / FM |
| **F/A-18C** | `FA-18C` | COMM 1: ARC-210 | 30.000 | 87.995 | FM |
|  |  |  | 118.000 | 135.995 | AM |
|  |  |  | 136.000 | 155.995 | AM / FM |
|  |  |  | 156.000 | 173.995 | FM |
|  |  |  | 225.000 | 399.975 | AM / FM |
|  |  | COMM 2: ARC-210 | 30.000 | 87.995 | FM |
|  |  |  | 118.000 | 135.995 | AM |
|  |  |  | 136.000 | 155.995 | AM / FM |
|  |  |  | 156.000 | 173.995 | FM |
|  |  |  | 225.000 | 399.975 | AM / FM |
| **F/A-18C Lot 20** | `FA-18C_hornet` | COMM 1: ARC-210 | 30.000 | 87.995 | FM |
|  |  |  | 118.000 | 135.995 | AM |
|  |  |  | 136.000 | 155.995 | AM / FM |
|  |  |  | 156.000 | 173.995 | FM |
|  |  |  | 225.000 | 399.975 | AM / FM |
|  |  | COMM 2: ARC-210 | 30.000 | 87.995 | FM |
|  |  |  | 118.000 | 135.995 | AM |
|  |  |  | 136.000 | 155.995 | AM / FM |
|  |  |  | 156.000 | 173.995 | FM |
|  |  |  | 225.000 | 399.975 | AM / FM |
| **Fw 190 A-8** | `FW-190A8` | FuG 16 Z | 38.000 | 156.000 | AM / FM |
| **Fw 190 D-9** | `FW-190D9` | FuG 16 Z | 38.000 | 156.000 | AM / FM |
| **Hawk** | `Hawk` | Radio 1 | 225.000 | 399.900 | AM / FM |
| **I-16** | `I-16` | SCR522 | 100.000 | 156.000 | AM / FM |
| **JF-17** | `JF-17` | COMM 1/2 Preset | 30.000 | 399.995 | AM / FM |
| **L-39C** | `L-39C` | R-832M | 118.000 | 140.000 | AM / FM |
|  |  |  | 220.000 | 390.000 | AM / FM |
| **L-39ZA** | `L-39ZA` | R-832M | 118.000 | 140.000 | AM / FM |
|  |  |  | 220.000 | 390.000 | AM / FM |
| **La-7** | `La-7` | SCR522 | 100.000 | 156.000 | AM / FM |
| **M-2000C** | `M-2000C` | UHF Radio | 225.000 | 400.000 | AM / FM |
|  |  | V/UHF Radio | 118.000 | 140.000 | AM / FM |
|  |  |  | 225.000 | 400.000 | AM / FM |
| **MB-339A** | `MB-339A` | AN/ARC-150(V)-2 | 225.000 | 399.975 | AM / FM |
|  |  | SRT-651/N | 30.000 | 87.975 | AM / FM |
|  |  |  | 108.000 | 117.975 | AM / FM |
|  |  |  | 118.000 | 136.992 | AM / FM |
|  |  |  | 137.000 | 155.975 | AM / FM |
|  |  |  | 225.000 | 399.975 | AM / FM |
| **MB-339A/PAN** | `MB-339APAN` | AN/ARC-150(V)-2 | 225.000 | 399.975 | AM / FM |
|  |  | SRT-651/N | 30.000 | 87.975 | AM / FM |
|  |  |  | 108.000 | 117.975 | AM / FM |
|  |  |  | 118.000 | 136.992 | AM / FM |
|  |  |  | 137.000 | 155.975 | AM / FM |
|  |  |  | 225.000 | 399.975 | AM / FM |
| **MiG-19P** | `MiG-19P` | RSIU-4V Radio | 100.000 | 150.000 | AM / FM |
| **MiG-21Bis** | `MiG-21Bis` | R-832 | 118.000 | 140.000 | AM / FM |
|  |  |  | 220.000 | 390.000 | AM / FM |
| **MiG-29A  Fulcrum** | `MiG-29 Fulcrum` | VHF/UHF Radio R-862 | 100.000 | 149.975 | AM / FM |
|  |  |  | 220.000 | 399.975 | AM / FM |
|  |  | ARK-19 | 0.150 | 1.300 | AM / FM |
| **Mirage F1AD** | `Mirage-F1AD` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **Mirage F1AZ** | `Mirage-F1AZ` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **Mirage F1B** | `Mirage-F1B` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **Mirage F1BD** | `Mirage-F1BD` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **Mirage F1BE** | `Mirage-F1BE` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **Mirage F1BQ** | `Mirage-F1BQ` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **Mirage F1C** | `Mirage-F1C` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **Mirage F1C-200** | `Mirage-F1C-200` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **Mirage F1CE** | `Mirage-F1CE` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **Mirage F1CG** | `Mirage-F1CG` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **Mirage F1CH** | `Mirage-F1CH` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **Mirage F1CJ** | `Mirage-F1CJ` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **Mirage F1CK** | `Mirage-F1CK` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **Mirage F1CR** | `Mirage-F1CR` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **Mirage F1CT** | `Mirage-F1CT` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **Mirage F1CZ** | `Mirage-F1CZ` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **Mirage F1DDA** | `Mirage-F1DDA` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **Mirage F1ED** | `Mirage-F1ED` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **Mirage F1EDA** | `Mirage-F1EDA` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **Mirage F1EE** | `Mirage-F1EE` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **Mirage F1EH** | `Mirage-F1EH` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **Mirage F1EQ** | `Mirage-F1EQ` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **Mirage F1JA** | `Mirage-F1JA` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **Mirage F1M (C.14 1-25/32-51)** | `Mirage-F1M-CE` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **Mirage F1M (C.14 52-73)** | `Mirage-F1M-EE` | TRAP-136 | 118.000 | 399.975 | AM / FM |
|  |  | TRAP-137B | 225.000 | 399.975 | AM / FM |
| **Mosquito FB Mk. VI** | `MosquitoFBMkVI` | TR.1143 | 38.000 | 156.000 | AM / FM |
|  |  | T.1154N Range 1 | 5.500 | 10.000 | AM / FM |
|  |  | T.1154N Range 2 | 3.000 | 5.500 | AM / FM |
|  |  | T.1154N Range 3 | 200.000 | 500.000 | AM / FM |
| **P-47D-30** | `P-47D-30` | SCR-522 | 38.000 | 156.000 | AM / FM |
|  |  | BC-1206 | 100.000 | 200.000 | AM / FM |
| **P-47D-30 (Early)** | `P-47D-30bl1` | SCR-522 | 38.000 | 156.000 | AM / FM |
|  |  | BC-1206 | 100.000 | 200.000 | AM / FM |
| **P-47D-40** | `P-47D-40` | SCR-522 | 38.000 | 156.000 | AM / FM |
|  |  | BC-1206 | 100.000 | 200.000 | AM / FM |
| **P-51D-25-NA** | `P-51D` | SCR-522 | 38.000 | 156.000 | AM / FM |
|  |  | BC-1206 | 100.000 | 200.000 | AM / FM |
| **P-51D-30-NA** | `P-51D-30-NA` | SCR-522 | 38.000 | 156.000 | AM / FM |
|  |  | BC-1206 | 100.000 | 200.000 | AM / FM |
| **QF-4E** | `QF-4E` | UHF AN/ARC-164 COMM channels | 225.000 | 399.950 | AM / FM |
|  |  | UHF AN/ARC-164 AUX channels | 265.000 | 284.900 | AM / FM |
| **Spitfire LF Mk. IX** | `SpitfireLFMkIX` | TR.1143 | 38.000 | 156.000 | AM / FM |
| **Spitfire LF Mk. IX CW** | `SpitfireLFMkIXCW` | TR.1143 | 38.000 | 156.000 | AM / FM |
| **TF-51D** | `TF-51D` | SCR-522 | 38.000 | 156.000 | AM / FM |
|  |  | BC-1206 | 100.000 | 200.000 | AM / FM |
| **Yak-52** | `Yak-52` | ARK-15M | 0.100 | 1.795 | AM / FM |
| **RSI-6K** | `MiG-15bis` | RSI-6K | 3.750 | 5.000 | AM |
| **RSI-6K** | `MiG-15bis_FC` | RSI-6K | 3.750 | 5.000 | AM |
| **Su-27** | `Su-27` | UHF (SRS) | 225.000 | 399.975 | AM |
|  |  | VHF (SRS) | 108.000 | 155.995 | AM |
|  |  | FM (SRS) | 30.000 | 87.975 | FM |
| **Su-25** | `Su-25` | UHF (SRS) | 225.000 | 399.975 | AM |
|  |  | VHF (SRS) | 108.000 | 155.995 | AM |
|  |  | FM (SRS) | 30.000 | 87.975 | FM |
| **Su-25T** | `Su-25T` | UHF (SRS) | 225.000 | 399.975 | AM |
|  |  | VHF (SRS) | 108.000 | 155.995 | AM |
|  |  | FM (SRS) | 30.000 | 87.975 | FM |
| **Su-33** | `Su-33` | UHF (SRS) | 225.000 | 399.975 | AM |
|  |  | VHF (SRS) | 108.000 | 155.995 | AM |
|  |  | FM (SRS) | 30.000 | 87.975 | FM |
| **MiG-29A** | `MiG-29A` | UHF (SRS) | 225.000 | 399.975 | AM |
|  |  | VHF (SRS) | 108.000 | 155.995 | AM |
|  |  | FM (SRS) | 30.000 | 87.975 | FM |
| **MiG-29S** | `MiG-29S` | UHF (SRS) | 225.000 | 399.975 | AM |
|  |  | VHF (SRS) | 108.000 | 155.995 | AM |
|  |  | FM (SRS) | 30.000 | 87.975 | FM |
| **MiG-29G** | `MiG-29G` | UHF (SRS) | 225.000 | 399.975 | AM |
|  |  | VHF (SRS) | 108.000 | 155.995 | AM |
|  |  | FM (SRS) | 30.000 | 87.975 | FM |
| **J-11A** | `J-11A` | UHF (SRS) | 225.000 | 399.975 | AM |
|  |  | VHF (SRS) | 108.000 | 155.995 | AM |
|  |  | FM (SRS) | 30.000 | 87.975 | FM |
| **A-10A** | `A-10A` | UHF (SRS) | 225.000 | 399.975 | AM |
|  |  | VHF (SRS) | 108.000 | 155.995 | AM |
|  |  | FM (SRS) | 30.000 | 87.975 | FM |
| **F-15C** | `F-15C` | UHF (SRS) | 225.000 | 399.975 | AM |
|  |  | VHF (SRS) | 108.000 | 155.995 | AM |
|  |  | FM (SRS) | 30.000 | 87.975 | FM |

## Helicopters

| Aircraft | DCS ID | Radio | Min (MHz) | Max (MHz) | Modulation |
|----------|--------|-------|----------:|----------:|------------|
| **AH-64D BLK.II** | `AH-64D_BLK_II` | ARC-186 | 108.000 | 151.975 | AM / FM |
|  |  | ARC-164 | 225.000 | 399.975 | AM / FM |
|  |  | FM 1: ARC-201D | 30.000 | 87.975 | FM |
|  |  | FM 2: ARC-201D | 30.000 | 87.975 | FM |
| **CH-47F** | `CH-47Fbl1` | VHF FM: ARC-186 | 30.000 | 87.975 | FM |
|  |  |  | 108.000 | 115.975 | AM |
|  |  |  | 116.000 | 151.975 | AM |
|  |  | UHF AM: ARC-164 | 225.000 | 399.975 | AM / FM |
|  |  | VHF FM: ARC-201D | 30.000 | 87.975 | FM |
| **Ka-50** | `Ka-50` | R-828 | 20.000 | 59.900 | AM / FM |
|  |  | ARK-22 | 0.150 | 1.750 | AM / FM |
| **Ka-50 III** | `Ka-50_3` | R-828 | 20.000 | 59.900 | AM / FM |
|  |  | ARK-22 | 0.150 | 1.750 | AM / FM |
| **Mi-24P** | `Mi-24P` | R-863 | 100.000 | 399.900 | AM / FM |
|  |  | R-828 | 20.000 | 59.900 | AM / FM |
| **Mi-8MTV2** | `Mi-8MT` | R-863 | 100.000 | 399.900 | AM / FM |
|  |  | R-828 | 20.000 | 59.900 | AM / FM |
| **OH-58D(R)** | `OH58D` | UHF AM | 225.000 | 399.975 | AM / FM |
|  |  | VHF AM | 116.000 | 151.975 | AM / FM |
|  |  | VHF FM1 | 30.000 | 87.975 | AM / FM |
|  |  | VHF FM2 | 30.000 | 87.975 | AM / FM |
| **SA342L** | `SA342L` | FM Radio | 30.000 | 87.975 | AM / FM |
| **SA342M** | `SA342M` | FM Radio | 30.000 | 87.975 | AM / FM |
| **SA342Minigun** | `SA342Minigun` | FM Radio | 30.000 | 87.975 | AM / FM |
| **SA342Mistral** | `SA342Mistral` | FM Radio | 30.000 | 87.975 | AM / FM |
| **UH-1H** | `UH-1H` | UHF AN/ARC-51 | 225.000 | 399.975 | AM / FM |
<!-- END generated: aircraft tables -->
