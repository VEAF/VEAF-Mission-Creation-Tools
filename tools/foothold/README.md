# `tools/foothold/`

Assets shared by the **VEAF Foothold missions** — the ten maps adopted from Lekaa's releases
(see [FOOTHOLD](../../doc/mission-maker/FOOTHOLD.md)). Not part of the shipped product: these
are copied into mission folders by hand, or by
[`../Convert-FootholdBatch.ps1`](../Convert-FootholdBatch.ps1).

## `presets.yaml`

The radio presets used by all ten Foothold missions. Copy it to
`<mission-folder>/src/presets.yaml`.

**Deliberately map-agnostic**: the channel lists reference callsigns
(`Archer`, `Arctic`, …) and literal frequencies, never airfields — which is why one file serves
Caucasus, Syria, Normandy and the rest. `channels_collection` still carries the per-map airfield
tables, unused by the lists but kept as the frequency reference.

### Why it is written as a preset plan

Written as a **preset plan** ([ADR 0010](../../docs/adr/0010-per-type-radio-preset-projection.md)):
three channel lists (`primary_1` UHF, `primary_2` VHF, `fm_supplement`/`fm_substitute` FM) that
the build projects onto each aircraft's physical radios.

Measured on `Foothold_AF_2.4.1` against the previous hand-written version:

| | Before | After |
|---|---|---|
| Types given channels outside their radios' bands | **10** | **2** |
| Kneeboard plates | 30 | **32** |
| Types losing coverage | — | **none** |

The two gains are `Mi-24P` and `Mi-8MT`, which the old file gave up on (`empty`) because their
channel-0 rotation needed a bespoke collection; the packer handles it. The six hand-written
collections (inverted A-10, Apache, Gazelle, CH-47, OH-58D) are gone — the projection covers
them.

### The legacy override layer, and why it is still there

`radios_collection` / `presets_collection` / `presets_assignments` are **not leftovers**. The
projection needs each type's physical radios from `dcs-radio-specs.yaml`, and that file covers
87 types but **no Flaming Cliffs aircraft** — `Su-27`, `Su-25T`, `Su-25`, `Su-33`, `MiG-29A/S/G`,
`J-11A`, `A-10A`, `F-15C` are all absent, as is `F-14BU`. Without an override they would ship
with no presets at all.

ADR 0010 keeps the old layers as the manual-override path for exactly this. The three lists are
reused there through **YAML anchors**, so a frequency is edited in one place only.

**Drop a type from `presets_assignments` as soon as it appears in `dcs-radio-specs.yaml`** — the
projection then handles it properly, ADF radios included.

### Known upstream gaps (not this file's doing)

Two entries still appear in the build's `presets-validation-report.md`; both are VEAF data
issues tracked separately, not authoring mistakes:

- **`MiG-29 Fulcrum`** — its radio 2 is an `ARK-19` **radio-compass** (0.15–1.2995 MHz), which
  the default role classification treats as an FM radio, so the FM list lands on an ADF. Also
  affects `Ka-50`, `Ka-50_3` and `Yak-52`.
- **`AJS37`** — channels 44/45 are `trailing_specials` **hard-coded in the VEAF layout** at 33
  and 34 MHz, below the FR22's 103 MHz floor.
