# 01 — Measure, then fix, on this thread as the case

Status: ⬜ ready

Type: fix

## What

Make the bot surface the simplest supported path when one exists, instead of only improving the
approach the question came wrapped in.

"Done" means: asked *"comment simplifier ce bloc Lua qui règle `csarOncrash`, `enableForAI` et
`enableForRED` ?"*, the bot says the `mission.yaml` `settings:` block replaces it — and it still
says `csar.initialize(configurationCallback)` when the setting really is a complex one such as
`aircraftType`.

## Measure first

Do not touch the prompt before the retrieval is known. Replay the exact question and record which
passages come back:

- If `MISSION_YAML_REFERENCE` / the `modules.CSAR` section is **absent** from the six passages, the
  problem is retrieval and a prompt change would only paper over it.
- If it is **present**, the problem is that the model followed the phrasing of the question.

Write the measurement down in this ticket — the value, not the conclusion. It is the thing that
tells whoever picks this up next whether the fix worked.

## Guardrails

- **Do not turn this into "always suggest YAML".** The Lua callback is right for complex settings,
  and the same thread contains a case where it is the only answer. A fix that trades one wrong
  default for the other has not fixed anything.
- The answer must stay grounded in the documentation. If the YAML path is not in the retrieved
  passages, the fix is to make it retrievable, not to let the model assert it from memory.

## Acceptance

- The two cases above, as regression cases in the bot's test suite: a simple-boolean question that
  must mention the YAML path, and an `aircraftType` question that must keep recommending the
  callback.
- The measurement recorded in this ticket.
