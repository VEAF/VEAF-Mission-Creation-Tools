# FIX-WHAT-THE-MISSION-MAKER-CAN-ACT-ON — a dead-end error message, and a bot that fills the gap by inventing

Status: ✅ done — merged as #966

Opened 2026-09-19 from a real support exchange. **Tripack** hit this on a build (named here
2026-09-20, when the 6.23.1 release notes credited him — the repository had only ever said
"a mission maker"):

> Camp 'red' : les pays **[68]** possèdent des unités mais ne figurent pas dans coalitions.red
> ([0, 18, 19, 24, 27, 34, 37, 38, 43, 47, 81]) […]

He could not tell what country `68` was, guessed it might be his neutral static objects, and asked
the documentation assistant. The assistant told him to "modify the structure of your mission.yaml" —
a file that has no `coalitions` key. Two separate failures, one for each half of this lot.

## Ticket 01 — the message names no country

`68` is USSR. Nothing in the product tells the reader that: the Mission Editor shows country
**names**, the message prints **ids**, and no documentation page carries the mapping. The reader is
handed a number and asked to act on it.

Both lists have to be named, not only the missing one: deciding between *add the country to the side*
and *re-assign the objects to a country already there* means comparing the two.

The message is also the one place where the repository shows raw country ids — measured across the
locale file, it is the **only** one of the 5 country-mentioning messages that does so.

## Ticket 02 — the assistant cannot tell that it does not know

Measured while diagnosing the exchange:

- **98** `validate.*` / `builder.*` messages the tools can print; **2** whose text appears anywhere
  under `doc/`. Not one page mentions `coalitions.red`, the coalition assignment screen, or a country
  table. The only `68` in the whole documentation is a *parking terminal type* — a false friend the
  retrieval can happily rank first.
- The retrieval (`poc/doc-chatbot/worker/src/index.js`) ranks by cosine and keeps the top 6 **with no
  floor**. Whatever is asked, the model receives six passages presented as the relevant
  documentation, under an instruction that says to answer only from them.

So the standing instruction — *"if the answer is not in the excerpts, say so"* — is inert **by
construction**: nothing ever tells the model the excerpts are bad. It did exactly what it was asked,
on noise.

Two halves to the remedy, deliberately:

1. A **similarity floor**, against the plainly off-topic. Configurable through `MIN_SIMILARITY`
   rather than hard-coded, because the right value cannot be guessed from here — see below.
2. **Telling the model what the excerpts are**: the best matches of an automatic search, which may
   share the question's vocabulary while covering something else. A passage can clear any floor and
   still not answer the question, so the judgement has to happen in the model too. This half needs no
   number and is what actually addresses the reported case.

## The floor is not calibrated, and is shipped saying so

`DEFAULT_MIN_SIMILARITY = 0.35` is a guard against the plainly unrelated, **not a measured value**.
Calibrating it means embedding real questions against the live index, which needs the Gemini key this
workstation does not hold. It is therefore deliberately low — a floor that filters nothing is a
no-op, while one set too high gags the assistant, and of the two failures the second is far worse.

`MIN_SIMILARITY` is read from the Worker environment so the value can be tuned without touching this
code, and a value out of `(0, 1)` or unparseable falls back to the default rather than disabling or
gagging anything.

**This is the open question to settle after the fact**, with the key in hand: ask a dozen questions
the docs answer and a dozen they do not, record the top score of each, and set the floor between the
two clouds. Until then the second half of the remedy is what carries the fix.

## The review caught a silent failure introduced by ticket 02

Making an empty retrieval an ordinary outcome removed the one signal that distinguished *the
question is outside the documentation* from *the index is broken*. `retrieveContext` used to throw
when it came back with nothing, which surfaced as a 502. With the floor in place, a half-finished
index upload — vectors pushed, texts not — would have produced an empty context on **every** question
and the assistant would have answered, politely and in good French, that the documentation does not
cover it. Nothing would have alerted anyone; the site would simply have stopped being useful.

The two cases are now separated explicitly: no passage clears the floor returns empty (the caller
explains it), while vectors that rank with no text behind them, or an index that ranks nothing at
all, still throw. Both directions are covered by tests, since this is exactly the kind of defect that
passes every gate.

## Out of scope, and it is the real fix

Neither ticket puts the missing documentation there. **96 of the 98 messages remain undocumented**,
so the assistant stays blind to the whole family of "what does this build message mean?" — likely the
most common question a mission maker has. That is [DOC-VALIDATION-MESSAGES](../DOC-VALIDATION-MESSAGES/PRD.md).

## Definition of done

- [x] 01 — both lists name their countries; an id DCS does not know is still shown rather than hidden
- [x] 01 — `country_name_for_id` / `describe_country_id` added, with a round-trip test over every id
- [x] 01 — both locales say to write the number alone, and name the second way out (re-assign)
- [x] 02 — similarity floor, configurable, with a fallback that cannot gag or disable it
- [x] 02 — the instruction frames the excerpts as search results and forbids inventing
- [x] 02 — an empty retrieval gets its own instruction instead of an empty context
- [x] 02 — a broken index still fails loudly instead of reading as "not documented" (found in review)
- [x] Documentation updated, quality gates green
- [x] Coverage gate bumped on the CI's measurement: 86.70 % measured, gate 86.5 → **86.6**. Left a
      tenth of margin rather than pinned to the measurement — a gate flush against it fails the next
      pull request that merely deletes a covered line, which teaches people to lower it.

## Carried forward — two things this lot cannot do itself

**The Worker is deployed by hand.** Merging changes what the *next* `npx wrangler deploy` will ship,
not what visitors get today; the CI job only gates the code. Until someone deploys, the assistant in
production still answers from six unfiltered passages.

**The floor wants calibrating**, with the Gemini key this workstation does not hold: a dozen
questions the documentation answers, a dozen it does not, record the top similarity of each, set the
floor between the two clouds. `MIN_SIMILARITY` takes the value without touching the code, so this
needs no lot of its own — and until it happens, the second half of the remedy (the model judging the
excerpts) is what carries the fix. Raise it carefully: too high is worse than none.
