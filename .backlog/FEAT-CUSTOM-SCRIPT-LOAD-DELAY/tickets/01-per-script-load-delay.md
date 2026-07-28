# 01 — Per-script load delay in `custom_scripts`

Status: ⬜ ready
Type: feat

## Why

See the [PRD](../PRD.md). A third-party mission can stagger its script loading (Foothold: +3 s
and +12 s), and adopting it collapses everything into one `triggerStart`. `custom_scripts` cannot
express a delay, so the fidelity is lost silently — nothing in `validate` or the build mentions
it.

## Proposed shape

```yaml
custom_scripts:
  scripts:
    - path: src/scripts/Moose.lua
    - path: src/scripts/AIEN.lua
      delay_seconds: 12        # loaded by its own triggerOnce + c_time_after
```

- absent (the default) → today's behaviour exactly, in the shared `triggerStart`;
- present → the script moves to its **own** `triggerOnce` with a `c_time_after` condition;
- scripts sharing the same delay should share one trigger, so a five-script stage costs one
  trigger, not five — and their declared order must hold inside it;
- the ordering guarantee must stay intelligible: a delayed script loads after every
  non-delayed one regardless of where it sits in the list. Rejecting a list where a delayed
  script precedes a non-delayed one is one option; documenting the rule is another. Pick one and
  say so.

## Then close the loop with `convert-other`

Detection already reads the trigrules — it can read the delay too:

- [ ] `detect_native_script_loaders` records each loader trigger's `c_time_after` seconds, when
      present.
- [ ] The scaffold emits `delay_seconds:` on the affected scripts, so an adopted mission
      **reproduces the upstream staging by default** instead of silently flattening it.
- [ ] `--update` reports a delay that changed upstream, like it reports added/removed scripts.

That is the real prize: the adoption becomes faithful without the mission-maker having to notice
the difference.

## Tasks

- [ ] `mission.yaml` schema + validation for `delay_seconds` (positive number).
- [ ] Trigger generation: group by delay, one `triggerOnce` + `c_time_after` per group, order
      preserved.
- [ ] Same behaviour in **dynamic** builds (`veafDynamicConfig.lua`), or an explicit, documented
      refusal — `generate_load_trigger` governs both modes, this must not silently differ.
- [ ] `convert-other`: detect and scaffold the delays (above).
- [ ] Unit tests: no delay = today's single trigger; two delays = two extra triggers with the
      right seconds; order within a group.
- [ ] Document in `MISSION_YAML_REFERENCE` (FR + EN) and mention it in `FOOTHOLD.md` as what
      reproduces Lekaa's staging.
- [ ] CHANGELOG + version bump.

## Notes

Check first whether the flattening actually breaks Foothold (PRD, "Open question") — the answer
sets the priority, not the design.
