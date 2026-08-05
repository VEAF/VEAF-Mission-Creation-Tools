# 03 — A `dev_condition` test hatch for assistance steps

Status: ⬜ ready
Type: feat
Files: `src/scripts/veaf/veafAssist.lua`, the checklist YAML schema + its generator, `test/lua/`, docs

## The problem it solves

Verifying one guided-checklist step means putting the aircraft into the state that step waits for.
Testing step 30 of an engine start means performing steps 1 to 29 first, in a cockpit. That is why
`FEAT-ASSIST-CHECKLISTS` was signed off **by hand, in flight**, and why iterating on a checklist is
slow enough to discourage fixing small things.

`sms.rule` carries a `dev_condition` that fires the action immediately, bypassing the real gate, so an
author can see what the step *does* without staging the game state. Applied here: tick a step without
touching the switch.

## Behaviour

An optional per-step key that makes the step's check pass on demand:

```yaml
- label: MAIN PWR sur BATT
  control: bouton power sur main pwr
  element: PTR-ELEC-TMB-MPWR-510
  argument: 510
  equals: 1.0
  dev_condition: true    # absent in a shipped checklist
```

Non-negotiable properties, because this is a hatch that bypasses validation:

- **Off unless explicitly on.** Absent means today's behaviour, exactly.
- **It must not reach a built mission unnoticed.** A checklist carrying `dev_condition` should make the
  **build** warn loudly, or refuse under a strict flag. A shipped checklist that auto-ticks is worse
  than one that is hard to test: the pilot is told they did something they did not, in a training tool
  whose whole value is telling them the truth.
- **Visible in game when active.** If a step auto-passes, say so on screen. A silent bypass is how
  someone debugs the wrong thing for an hour.

## Tasks

- [ ] Schema gains the optional key; validation rejects a non-boolean.
- [ ] `veafAssist` honours it — the step's check short-circuits to satisfied.
- [ ] Build-time warning when any converted checklist carries it; decide with David whether strict mode
      refuses outright.
- [ ] On-screen marker while a step is auto-passed.
- [ ] Tests: absent → unchanged behaviour (the regression guard that matters); `true` → step passes with
      no state change; a non-boolean is rejected.
- [ ] Docs on the guided-checklist page, in the authoring section, framed as a **development** aid with
      the shipping warning attached.

## Note on the paused lot

`FEAT-ASSIST-AUTHORING` is ⏸ paused, which makes this look blocked. It is not: that lot is the
authoring side (resolver, instructor format, cockpit indexes), while this is an **engine and format**
feature belonging to `FEAT-ASSIST-CHECKLISTS`, which is ✅ done. Nothing here needs the resolver.

## Acceptance criteria

- [ ] `poetry run test-lua` green in CI (it cannot run on David's machine — no Lua 5.1).
- [ ] `luacheck` + `stylua --check` clean.
- [ ] A checklist with the key set cannot ship silently — proven by a test, not by a convention.
