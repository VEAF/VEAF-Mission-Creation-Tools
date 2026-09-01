# FEAT-MISSION-RECIPES — scripted mission generation, no AI in the loop

Status: ⬜ ready

Origin: David's idea, 2026-08-31. Recorded for later; **not scoped for implementation yet** — the
open questions below decide what it even is.

## The idea

Describe, in a file, the sequence of tool operations that builds a kind of mission, and run it with
`veaf-tools` to produce that mission. A catalogue of such recipes would then generate fresh
missions on demand:

- **a demo mission**, always current, where every new VEAF feature drops an example of itself;
- **base missions**: a theatre, a few red and blue airfields, defences, some QRA, combat zones;
- **training missions**.

## Why the cost is lower than it looks

The engine exists. `veaf_mission_mcp` is an `ActionCatalog` with `list_catalog()` and
**`run_action(name, params)`** — and nothing about it involves a model. The LLM picks the calls; it
does not execute them. A recipe is an ordered list of `(action, params)`, so what is missing is a
file format and a runner, not a mission-editing engine.

The code already calls a mission folder a *recipe* in its own docstrings (`add_group.py:49`,
`actions.py:432`), which is a hint the shape was already half-imagined.

## The strongest case is the one that also tests the product

The demo mission is not merely "nice to have fresh". Regenerated in CI at each release, with every
feature contributing its own example, it becomes an **end-to-end integration test of the whole
product** — today nothing checks that all the features still work *together* on a real mission,
only that each works alone. It also solves the demo mission drifting out of date in its own
repository.

That argues for building it first, and for judging the format by what the demo needs.

## The real risk: sliding into a language

"A few red and blue airfields, defences, QRA" requires deciding **where**. Either the recipe
carries coordinates — and then it is theatre-specific, one per map — or it derives them ("three
blue airfields in the south, a QRA on each"), and the format grows variables, conditions and
loops. That is a project of its own, and it is how tools like this die.

**Recommendation: one real recipe first — the demo — with a deliberately dumb format.** A list of
actions and parameters, no logic, coordinates hard-coded. Extract a richer format only once three
recipes exist and the repetition is visible. The catalogue then falls out on its own, and it will
be the right one.

## Open questions, to answer before scoping

1. **Output: mission folder or built `.miz`?** A folder is versionable, replayable and can be
   picked up by hand afterwards; a `.miz` cannot. Recommendation: the folder.
2. **What does a recipe do that `src/defaults/mission-folder/` does not?** The scaffold already
   produces a working mission folder. The recipe's value starts where the scaffold stops — placing
   *content* (groups, zones, defences), which the scaffold never does. Worth stating explicitly, or
   the two overlap.
3. **Idempotence.** Running a recipe twice: same mission, or two? The MCP actions are explicitly
   not idempotent (`actions.py:543`: "twice creates two groups").
4. **Theatre coupling.** Is a recipe written for one map, or does it declare intent a runner
   resolves per map? The dumb version answers "one map"; that is fine to start.

## Not scoped yet

No tickets. This is a recorded idea with an analysis attached, so the next person starts from the
questions rather than from the enthusiasm. Turn it into work when David decides which of the three
mission kinds is worth the first recipe — the demo, on the reasoning above.
