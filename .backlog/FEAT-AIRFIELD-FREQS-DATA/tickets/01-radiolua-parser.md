# 01 — Radio.lua parser → airfield-frequencies.yaml

Status: ⬜ ready
Type: feat

## Context

`Mods/terrains/<Theatre>/Radio.lua` holds each airfield's ATC radios. Format (per
airfield entry in the `radio = { … }` list):

```lua
radio = {
  { radioId = ..., role = {"ground","tower","approach"},
    callsign = { {["nato"]={...}}, {["ussr"]={...}} },
    frequency = { [HF]={AM,val}, [UHF]={AM,val}, [VHF_HI]={AM,val}, [VHF_LOW]={AM,val} } },
  ...
}
```

Band mapping to VEAF: `UHF → uhf`, `VHF_HI → vhf`, `VHF_LOW → fm` (HF ignored).

## Tasks (TDD)

- [ ] Failing test first: parse a fixture `Radio.lua` (a couple of airfields incl.
      Batumi) → `{airfield_name: {uhf, vhf, fm}}`, verifying Batumi = 260 / 131 / 40.4.
- [ ] Parser resolves the airfield display name (via the callsign / the existing
      `airdromes.yaml` name↔id mapping) and picks the tower/primary radio's freqs.
- [ ] Emit a canonical `airfield-frequencies.yaml` fragment for one theatre
      (`theatre → airfield → {uhf, vhf, fm}`); MHz as numbers, missing band omitted.

## Definition of Done

- Parser + emitter unit-tested against a fixture; Batumi values verified.
- `ruff`/`mypy`/`pytest` green; coverage gate respected.
