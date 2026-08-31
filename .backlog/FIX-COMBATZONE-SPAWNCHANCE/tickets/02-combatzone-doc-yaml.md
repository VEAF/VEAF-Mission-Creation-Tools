# 02 — Teach combat zones as YAML, not Lua

Status: ⬜ ready

Type: docs · Files: `doc/mission-maker/GUIDE.md` + `.en.md`,
`doc/mission-maker/scripts/veafCombatZone.md` + `.en.md`

## The gap

`GUIDE.md` teaches combat zones by showing Lua (`VeafCombatZone:new():addZoneElement(...)`), around
line 646. A mission maker on v6 writes YAML:

```yaml
modules:
  COMBATZONE:
    enabled: true
    combat_zones:
      - type: zone
        zone_name: CZ-Alpha
        friendly_name: Alpha Zone
        training: false
```

(from `veaf_libs/mission_template.py:69`, which is what `convert-v5` and the scaffold emit).

## Definition of done

- [ ] The `GUIDE` shows the YAML form first; Lua appears only where it is genuinely the answer
      (a maker function called from `mission-script.lua`), clearly labelled as such
- [ ] Both languages, in step
- [ ] The MANPADS example in `veafCombatZone.md` is corrected to match ticket 01's behaviour —
      today it claims "around two will be active", which was never true and will become true
- [ ] `poetry run docs-check` passes
