# FEAT-MISSION-RECIPES — scripted mission generation, no AI in the loop

Status: 🚫 wontfix — 2026-10-05. David: the demo mission is what this lot was for, and it does not need it.

## Why it is closed

An always-current demo breaks down into three needs, and a recipe serves none of them:

- **Running the latest scripts** is a rebuild of the mission folder with the new release.
- **Showing each new feature** means someone writes the example; the MCP and the generation prompts edit the folder directly, so a recipe would only move where it is written.
- **The end-to-end test** is a CI job that builds the versioned demo folder and runs the produced scripts against the DCS mocks — it reads the folder, not a recipe.

The versioned mission folder already is the declarative, replayable source. A list of actions only adds regeneration from scratch (another theatre), which the demo does not need and which is the risk this PRD named. David will build a new demo mission instead.

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

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**scripted mission generation, no AI in the loop.** David's idea, recorded with an analysis rather than scoped: describe in a file the sequence of tool operations that builds a kind of mission, run it with `veaf-tools`, and keep a catalogue of them (a demo mission always current, base missions, training missions). The engine already exists — `run_action(name, params)` over the MCP catalogue involves no model, the LLM picks the calls rather than executing them — so what is missing is a file format and a runner. Strongest case is the demo, and not for freshness: regenerated in CI with every feature dropping its own example, it becomes the end-to-end integration test the product does not have. Main risk, stated up front: “a few red and blue airfields” requires deciding *where*, and deriving positions grows variables, conditions and loops — a project of its own. Recommendation is one dumb recipe first, extract a format only at the third
