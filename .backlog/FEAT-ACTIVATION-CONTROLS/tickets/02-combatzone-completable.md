# 02 — Combat zone `completable`

Status: ✅ done
Type: feat

## Behaviour

New optional key on a `modules.COMBATZONE.combat_zones[]` entry:

```yaml
- zone_name: BLUE_DEFENCE
  completable: false   # default true — never auto-completes/deactivates
```

- `true` / absent → unchanged (the zone completes when no red unit remains).
- `false` → emit `:setCompletable(false)`; the runtime then never schedules its watchdog,
  so the zone stays active until something stops it explicitly.

This is what a blue-only zone needs today, since completion is hardcoded on the red count.

## Tasks

- [x] Generator: emit `:setCompletable(false)` when the key is `false` (nothing when true).
- [x] Tests: absent → no line; `false` → line emitted; `true` → no line.
- [x] Docs: `doc/mission-maker/scripts/veafCombatZone.{md,en.md}` key table, stating the
      blue-only symptom this addresses.
- [x] Default `src/defaults/mission-folder/mission.yaml`: document the key.
