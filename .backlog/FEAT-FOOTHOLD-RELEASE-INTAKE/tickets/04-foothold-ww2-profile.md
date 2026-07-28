# 04 — `foothold-ww2` profile for Normandy

Status: ✅ done
Type: feat

## Why

`WWII_Normandy_Foothold_5.2.2` (by *sevenfifty777*) is a Foothold, but not the same family.
Adopting it with `--profile foothold` yields a scaffold that fails `validate`, and one wrong
incompatibility.

Measured against the shipped 5.2.2 `.miz`:

| | `foothold` profile says | Normandy actually is |
|---|---|---|
| config target | `Foothold Config.lua` | **`Foothold Config WW2.lua`** |
| `Era` | scaffolded (Modern/Coldwar) | **absent** — WW2 has no era switch |
| `StartNormal` | in the scaffold defaults | **absent** |
| `AutoRestart`, `CapDifficulty`, `FootholdLocale` | in the scaffold | present (l. 147, 209, 140) |
| Foothold CTLD | ships its own → VEAF `CTLD` incompatible | **ships none** → VEAF CTLD is usable |

Its loaded scripts: `Moose_2026-06-14.lua`, `Foothold_Localization.lua`,
`Foothold Config WW2.lua`, `zoneCommander.lua`, `Normandy_Zone_Setup.lua`,
`WelcomeMessage.lua`, `zeus_Full_v2.1.lua`, `EWRS.lua`, `Splash_Damage_3.4.1_leka.lua`,
`AIEN.lua` — no `Foothold CTLD.lua`, no `Foothold_CTLD_Red.lua`.

## Behaviour

A second bundled profile `foothold-ww2.yaml`:

- `config_override.target: "Foothold Config WW2.lua"`, defaults limited to keys that exist
  there (`AutoRestart`, `CapDifficulty`, `FootholdLocale`) — **no `Era`, no `StartNormal`**;
- `incompatible_modules:` empty — nothing forbids the VEAF CTLD on this mission;
- same `disabled_community_scripts` as `foothold` **minus `ctld`**: it ships Moose, AIEN,
  EWRS and Splash, so those stay off, but VEAF's CTLD may be enabled;
- same `name_normalization` rules (`Moose_*`, `Splash_Damage_*` from ticket 01);
- `modules:` as `foothold`, and whether `CTLD: true` becomes a default here is a judgement
  call — start with it **off** (adopting must not silently add a subsystem), and say in the
  profile comment that it is available.

## Tasks

- [x] Write `veaf_libs/data/convert-profiles/foothold-ww2.yaml` with the above, commented in
      the same style as `foothold.yaml` (data only, no code change expected).
- [x] Unit test: the profile loads, target is the WW2 config, `incompatible_modules` is
      empty, `ctld` is not in `disabled_community_scripts`.
- [x] Adopt `WWII_Normandy_Foothold_5.2.2` with it and run `validate` — must pass with the
      `config_override` block uncommented (every key lexically present in the WW2 config).
- [x] Build it and check the native loaders are stripped and the 10 scripts injected.
- [x] Document the profile in `FOOTHOLD.md` / `.en.md`: which profile for which map, and why
      Normandy needs its own (no era switch, no Foothold CTLD).
- [x] CHANGELOG + version bump.

## Notes

Do **not** try to make one profile cover both by making `Era` optional. The two missions
differ in what settings exist at all; a profile is meant to be the author-specific data for
one family, and forcing them together would put a conditional in generic code — which
[ADR 0007](../../docs/adr/0007-third-party-mission-adoption.md) exists to prevent.

`Foothold Config WW2.lua` carries the same external-config block as the modern config
(`Saved Games\Missions\Saves\Foothold Config WW2.lua`), so the ticket 03 warning applies
here too. It does **not** self-load from `l10n/DEFAULT` — no recursion risk.

Only worth doing if VEAF actually intends to run a Normandy Foothold. If not, park at
🚫 wontfix rather than half-shipping a profile nobody exercises.
