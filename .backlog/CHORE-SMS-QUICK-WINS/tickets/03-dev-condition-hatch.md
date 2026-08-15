# 03 — A `dev_condition` test hatch for assistance steps

Status: ✅ done
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

- [x] Schema gains the optional key; validation rejects a non-boolean.
- [x] `veafAssist` honours it — the step's check short-circuits to satisfied.
- [x] Build-time warning when any converted checklist carries it; decide with David whether strict mode
      refuses outright.
- [x] On-screen marker while a step is auto-passed.
- [x] Tests: absent → unchanged behaviour (the regression guard that matters); `true` → step passes with
      no state change; a non-boolean is rejected.
- [x] Docs on the guided-checklist page, in the authoring section, framed as a **development** aid with
      the shipping warning attached.

## Note on the paused lot

`FEAT-ASSIST-AUTHORING` is ⏸ paused, which makes this look blocked. It is not: that lot is the
authoring side (resolver, instructor format, cockpit indexes), while this is an **engine and format**
feature belonging to `FEAT-ASSIST-CHECKLISTS`, which is ✅ done. Nothing here needs the resolver.

## Acceptance criteria

- [x] `poetry run test-lua` green — locally too: Lua 5.1.5 **is** installed here (`C:\Program Files (x86)\Lua.1`), contrary to what this line assumed. All 36 suites pass.
- [x] `luacheck` + `stylua --check` clean.
- [x] A checklist with the key set cannot ship silently — proven by a test, not by a convention.

## Delivered — 2026-08-11

`dev_condition: true` on a step, `devCondition = true` in the emitted Lua, and one short-circuit at the
single place a step is evaluated:

```lua
-- veafAssist.lua, in stepIsSatisfied
if step.devCondition == true then
  return true
end
```

**`== true` rather than a truth test, deliberately.** In Lua every non-nil value is truthy — the string
`"false"` included — and a hand-edited generated file is exactly where such a value comes from. A test
pins it: `devCondition = "false"` does **not** open the hatch. This is the same `""`-is-truthy family
that `SECREV-010` and `REFACTOR-MARKER-PARSER` each had to fix, so it was worth writing down rather than
rediscovering.

**The short-circuit sits before the check, not instead of it.** A hatched step keeps its
`argument`/`param`/`confirm`, so removing the key restores the real gate with nothing else to rewrite —
and a test asserts a hatched step still emits its `cockpit_param` check.

The use case falls out of the existing session mechanics with no extra code:
`tickAlreadySatisfiedSteps` already ticks everything satisfied when a session opens, so hatching steps 1
to 29 opens the session **on step 30**. That is exactly what the ticket wanted, and it is why the hatch
belongs in `stepIsSatisfied` rather than anywhere else.

### The decision the ticket left to David, taken and explained

The ticket said to *"decide with David whether strict mode refuses outright"*. **Warn, never refuse, and
no strict flag** — with the reasoning recorded in `_warn_about_dev_conditions` so it can be argued with:

- **Refusing would make the feature unusable.** The hatch exists to iterate on a mission you are about
  to fly; a build that refused it could never produce the `.miz` you wanted to test.
- **The risk is not building with it, it is forgetting it.** Two things cover that and neither depends on
  anyone reading a log: the build warning names the checklist and the exact step numbers, and the engine
  tells the pilot on screen at session start (`⚠ N step(s) tick themselves (devCondition)`).
- **A strict flag protects nobody**, because it has to be remembered by the same person who forgot to
  remove the key. Reopen this if a release ever ships a hatched checklist despite both guards.

The on-screen notice is said **once per session**, not per tick: it is a property of the checklist being
walked, and repeating it would bury the step texts. The technical word `devCondition` is kept in the
message on purpose — it is what a pilot can quote back to whoever built the mission, and what an author
greps for.

### Tests

7 Lua (hatch off by default, passes with the cockpit untouched, does not leak to the next step, works on
a `confirm` step — the one an author cannot fake with a parameter, the on-screen notice present and
absent, and the non-boolean guard) and 9 Python (absent and `false` emit nothing, `true` reaches the
engine, the validation mode survives, a non-boolean is refused across six values, the step numbers are
reported 1-based, and the build warning fires for a hatched checklist and stays quiet for a clean one).

Documented in both languages under the authoring section, framed as a development aid with the shipping
warning attached (`{#dev-condition}`).
