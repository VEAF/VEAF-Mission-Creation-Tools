# FIX-SUPPORT-ASK-ANSWERS-THE-NEED — answer the need, not only the question

Status: ✅ done

Origin: David, 2026-09-22, after reading the `/ask` thread on CSAR configuration
([1551871856972271616](https://discord.com/channels/471061487662792715/1551871856972271616)) end to
end.

## What happened

Tripack asked, three times over two hours, how to **simplify a Lua block** configuring CSAR in
`mission-script.lua`. The bot answered the question each time, and its final answer was **correct**:
`csar.initialize(configurationCallback)` is the right call, because `veaf.lua` replaces
`csar.initialize` with a wrapper that takes a configuration callback, and re-initialising is the
documented mechanism for applying one.

Nobody was wrong, and the exchange still failed. The three settings he wanted —
`csarOncrash`, `enableForAI`, `enableForRED` — are plain booleans, so they belong in `mission.yaml`:

```yaml
modules:
  CSAR:
    enabled: true
    settings:
      csarOncrash: false
      enableForAI: false
      enableForRED: false
```

His Lua block did not need simplifying. It needed deleting. The bot spent two hours refining an
answer to *"how do I write this Lua better"* while the answer to *"how do I configure CSAR"* was one
YAML block and no Lua at all. And the documentation says so, in the very page the bot cited:
*"Pour les paramètres complexes comme `aircraftType` (une table par appareil), continuez à utiliser
le pattern callback Lua"* — **complex** settings, which his are not.

## Why it matters more than a wrong answer would

A wrong answer gets contradicted. This one is right, so it stands, and the user walks away with
working code that should not exist — carried in a mission file, re-read by whoever maintains it
later. The bot is the place where a mission maker learns what the simple path is; answering only the
question asked is how the simple path stays unknown.

## What to investigate

The fix is not obvious, and the lot starts by finding out which of these it is:

1. **Retrieval** — the YAML reference page was never in the retrieved passages, so the model could
   not know. Measurable: replay the question and look at what comes back.
2. **Prompt** — the passages were there and the model stayed on the phrasing of the question.
3. **Both**, which is likely, since the thread shows the *Fallback Lua* section being cited by name.

Note a related measurement already on file: retrieval has **no similarity floor** and always returns
six passages. A question whose answer is not in the documentation still gets six passages of
something.

## Tickets

| # | Title | Status |
|---|---|---|
| 01 | [Measure, then fix, on this thread as the case](tickets/01-measure-then-fix.md) | ✅ |

## What the measurement found

Both, but not in the proportions the section above guessed — and the answer moved under the lot's
feet while it was being written.

**Retrieval was never the problem.** Replaying Tripack's question against the live Worker returns
`{#csar-yaml}`, `{#csar-settings}` — the table naming his three settings — and `modules.CSAR`,
twice out of two. The model had the simple path in front of it and cited it in its own sources.

**The documentation gap was doing most of the work.** `FIX-CSAR-YAML-SETTINGS` (#986) merged hours
after the thread and rebuilt the index the same evening. Against that corpus the neutral question
— *"comment simplifier ce paragraphe ?"* — already gets the right answer, three times out of three:
the YAML block, and the Lua block declared unnecessary.

**What survives it is the leading question.** Tripack's third message asked to simplify *"en
intégrant `csar.initialize(configurationCallback)` comme conseillé par la documentation"*, and there
the assistant stays inside the framing, twice out of two, never mentioning `mission.yaml`. He did
not invent that phrasing: the bot's own earlier answer taught it to him. **A wrong answer that
teaches the wording of the next question is how a thread converges on the wrong thing while every
answer in it stays defensible** — which is the mechanism this lot exists to break, and it is worse
than the plain phrasing problem the PRD expected.

The fix is one paragraph in the Worker's system instruction, conditional on an excerpt *stating* the
simpler way and explicitly keeping the long route for settings the documentation says need it. The
numbers are in the ticket.
