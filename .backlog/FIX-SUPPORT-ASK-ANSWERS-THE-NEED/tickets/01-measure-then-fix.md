# 01 — Measure, then fix, on this thread as the case

Status: ✅ done

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

## The measurement

Taken 2026-09-22, against the **live** Worker (`veaf-docs-chatbot.veaf.workers.dev/chat`, client
mode `cli`), replaying Tripack's own questions verbatim out of the thread.

Two preconditions checked before reading anything into it:

- the live index was rebuilt at **18:12 UTC on `4b5f01ca`** (run `35765655534`, 1404 chunks, four
  KV writes, read-back verified) — that is `develop` HEAD, so the corpus measured **includes** the
  CSAR settings table that `FIX-CSAR-YAML-SETTINGS` (#986) added the same day. The corpus is not
  the one that existed during the thread, which is exactly what lets the two hypotheses separate;
- the similarity floor in force is `MIN_SIMILARITY = 0.6` (`wrangler.toml`).

### What comes back (the passages)

The Worker exposes no retrieval debug route, so the context was read the way the support bot reads
its sources: a prior instruction turn asking the model to enumerate the excerpts it was given, with
the question left untouched as the last user turn (the Worker embeds only that turn, so the
instruction does not poison the query). Two independent runs, in agreement:

| passage | present |
|---|---|
| `GUIDE.md` § *Configurer CSAR via mission.yaml (YAML-first)* `{#csar-yaml}` | **yes**, both runs |
| `GUIDE.md` § *Les réglages disponibles* `{#csar-settings}` — the table naming `csarOncrash`, `enableForAI`, `enableForRED` | **yes**, both runs |
| `GUIDE.md` § *Fallback Lua — CSAR dans mission-script.lua* `{#csar-lua-fallback}` | yes, both runs |
| `MISSION_YAML_REFERENCE.md` § *Modules tiers : `SKYNET` / `CTLD` / `CSAR`* `{#third-party-modules}` | yes, both runs |
| `MISSION_YAML_REFERENCE.md` § *Champs de `modules.CSAR`* / *`modules.SKYNET`* | yes (one run each) |
| `veafSkynetIadsHelper` — three sections | yes, both runs (the question's first paragraph is about Skynet) |

**So it is not retrieval.** The `mission.yaml` path, and the table naming his three exact settings,
are in the model's context.

### What the model answers

| question replayed | runs | answer |
|---|---|---|
| the 08:37 question, neutral: *"Comment simplifier le paragraphe suivant en sachant que le module CSAR est appelé dans le mission.yaml ?"* | 3 | **3/3 correct**: the YAML `settings:` block, and *"le bloc de code Lua que vous avez fourni n'est plus nécessaire"* |
| the 10:14 question, leading: *"…en intégrant `csar.initialize(configurationCallback)` comme conseillé par la documentation ?"* | 2 | **2/2 wrong**: Lua only, `mission.yaml` never mentioned — while *Configurer CSAR via mission.yaml* is in its own `SOURCES:` line |
| `aircraftType`: *"8 places pour le UH-1H et 16 pour le Mi-8MT"* | 1 | correct: not reachable in YAML, use the Lua callback |

Two things this settles, and the second is the one the lot could not have known:

1. **Hypothesis 2, confirmed.** The passages are there; the model follows the phrasing.
2. **The documentation gap was doing most of the work.** `FIX-CSAR-YAML-SETTINGS` (#986), merged
   hours after the thread, already turns the neutral question into the right answer three times out
   of three. What survives it is the **leading** question — and Tripack's own third message was
   exactly that, because the bot's previous answer had taught him the phrase to use. A wrong answer
   that teaches the wording of the next question is how a thread converges on the wrong thing while
   every single answer in it is defensible.

### After the fix

The rule was tried before it was written into the Worker, by sending it as a prior instruction turn
against the live assistant — an approximation of the system instruction, close enough to tell
whether the wording moves the answer:

| question | without the rule | with the rule |
|---|---|---|
| leading (`csar.initialize(configurationCallback)`) | Lua only, 2/2 | **YAML block + what it replaces**, then the callback framed as reserved for complex settings |
| `aircraftType` | callback | **still the callback** — *"une valeur à clés… doit être géré via le callback Lua"* |

One run each with the rule; the second confirmation run and the English variant hit the day's
**Gemini free allowance**, which is shared with the site widget and the Discord bot and refills
around 09:00 Paris. Fourteen questions were spent taking these measurements. That is why
`replay-answers.mjs` is not wired into the deploy workflow.

## Guardrails

- **Do not turn this into "always suggest YAML".** The Lua callback is right for complex settings,
  and the same thread contains a case where it is the only answer. A fix that trades one wrong
  default for the other has not fixed anything.
- The answer must stay grounded in the documentation. If the YAML path is not in the retrieved
  passages, the fix is to make it retrievable, not to let the model assert it from memory.

## What was done

The rule went into the **Worker's system instruction** (`poc/doc-chatbot/worker/src/index.js`,
`systemInstruction`), not into the support bot's protocol turn: the defect belongs to every caller
— the site widget, `veaf-tools ask` and Discord — and the instruction is the one place that tells
the model how to use the excerpts. It is conditional on an excerpt *stating* the simpler way, and
explicitly keeps the long route for settings the documentation says need it.

`emptyHandedInstruction` is untouched and asserted to stay untouched: with nothing retrieved there
is no excerpt to ground a simpler path in, and that instruction must stay a refusal.

## Acceptance

- ✅ The two cases as regression cases. A model's answer is not something a unit test reaches, so
  they live in `poc/doc-chatbot/worker/scripts/answer-cases.json` and are replayed against the live
  assistant by `scripts/replay-answers.mjs` (`node scripts/replay-answers.mjs`, no secret needed —
  it declares the `cli` client mode). A third case asks the same thing in English. The script's
  judgement — the verdict, the stream parsing, the exit code, the shape of the declared cases — is
  unit-tested in `test/unit.test.mjs`, as is the instruction itself; the two instruction tests were
  checked to fail with the fix reverted.

  Two things the review of this lot's own diff caught, both the same failure the repository has
  paid for before. The English case's markers were `mission.yaml` and `settings` in prose, which an
  English answer *recommending the callback* writes perfectly naturally — the check would have gone
  green on exactly the answer it exists to catch; the markers are now the YAML keys, colon
  included, and a test feeds both answers through to prove the two are separated. And a run where
  every case was unavailable exited **0** printing "all passed", so a spent-allowance day certified
  a fix nobody had observed; it now exits **2** and says nothing was measured. That path is not a
  hypothetical: it is what the script did when it was first run end to end, the day's allowance
  having been spent — fourteen of those questions on these measurements.
- ✅ The measurement recorded above.
