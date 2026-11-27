# FIX-CHATBOT-DAILY-QUOTA — the website chatbot has a ceiling nobody has looked at

Status: ✅ done · archived 2026-11-24

Origin: measured on 2026-09-05 while sizing the support programme's lot 4. Google's free tier for
`gemini-2.5-flash-lite` is **20 requests per day** and 10 per minute — read off AI Studio's *Rate
limits* page, not from documentation. The documentation chatbot in production spends one generation
call per question, so its ceiling is on the order of **twenty questions a day, for every visitor of
the site combined**.

## What is measured, and what is not

**Measured:** the free-tier limit itself. 20 RPD / 10 RPM for `gemini-2.5-flash-lite`, 20 RPD /
5 RPM for `gemini-2.5-flash`, on the free tier, per Google project.

**Not measured:** whether the chatbot ever reaches it. The AI Studio screen consulted was showing
the *VEAF NodeBB community* project, not the one holding the Worker's `GEMINI_API_KEY`. The peak
usage over 28 days for the right project has not been read. It may be three questions a day, in
which case this lot is a message and a documentation line rather than a defect.

That measurement is ticket 01, and it decides how much of the rest is worth doing.

## Why it matters either way

The ceiling is low enough that a single link posted on the VEAF Discord could exhaust it in an
afternoon. And the failure is invisible from the outside: the widget answers, then stops answering,
with no explanation a visitor can act on. Someone hitting it concludes the chatbot is broken, which
is worse than knowing it is rationed.

David decided on 2026-09-05 **not to enable billing** on the Google project — 50 analyses a day for
the support bot would have cost about $6 a month at the paid rate, and the choice was to stay free
rather than engage a payment method. So the ceiling stays; what changes is that it stops being a
silent failure.

## Constraints

- The Worker already maps an upstream 429 to a user-facing message
  ([`src/index.js`](../../poc/doc-chatbot/worker/src/index.js)) — this lot makes that message say
  the right thing, it does not invent a mechanism.
- Daily quotas reset at **midnight Pacific time**, which is **around 09:00 in Paris** all year
  (UTC-7 or UTC-8 against CEST or CET). So "try again tomorrow" is *correct* in a European evening
  and **wrong in the early morning**, when the allowance returns in a couple of hours on the same
  day. The wording has to hold at both ends of the day.
- The Worker ships on a push to `develop` or `master` through `chatbot-worker.yml` (since
  2026-09-19); it used to be deployed by hand.
- Both documentation languages, in lockstep.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Read the real usage before fixing anything](FIX-CHATBOT-DAILY-QUOTA.md) | chore |
| 02 | [An exhausted quota says so, and says when it comes back](FIX-CHATBOT-DAILY-QUOTA.md) | fix |
| 03 | [The page tells visitors the assistant is rationed](FIX-CHATBOT-DAILY-QUOTA.md) | docs |
| 04 | [When the day's allowance is spent, answer with another model](FIX-CHATBOT-DAILY-QUOTA.md) | feat |

Tickets 01–03 are done: 02 and 03 shipped in #916 on 2026-09-05, and 01 found the ceiling hit — 23 generation requests against 20 on 2026-09-22.
Ticket 04 was added on 2026-10-04 because of that reading: the free tier counts per model, so a chain of models raises the ceiling without enabling billing.

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**the website chatbot has a ceiling nobody has looked at**. Measured on 2026-09-05 while sizing the support programme: Google's free tier is **20 requests per day** for `gemini-2.5-flash-lite` (10 RPM) and for `gemini-2.5-flash` (5 RPM), per project — read off AI Studio, not from documentation. The production chatbot spends one generation call per question, so its ceiling is on the order of twenty questions a day for every visitor of the site combined, low enough that one link posted on Discord could exhaust it in an afternoon. **What is not measured** is whether it ever gets there: the screen consulted was showing the wrong Google project, so ticket 01 is to read the real peak before anything else — it may be three a day, in which case this lot is a message and a documentation line. Either way the failure is invisible from outside: the widget answers, then stops, and a visitor concludes it is broken rather than rationed. David decided the same day **not to enable billing** (50 analyses a day for the support bot would have run about $6 a month at the paid rate), so the ceiling stays; what changes is that it stops being silent

## Tickets, in full

## 01 — Read the real usage before fixing anything

Status: ✅ done

Type: chore

### The problem

The ceiling is known — 20 requests per day on the free tier — but not whether the chatbot reaches
it. The AI Studio screen consulted on 2026-09-05 was showing the *VEAF NodeBB community* project,
not the one holding the Worker's `GEMINI_API_KEY`, so the peak usage of the chatbot itself was never
read.

Everything else in this lot depends on that number. If the site serves three questions a day, the
rest is one sentence of documentation. If it clips 20 regularly, visitors are meeting a wall with no
explanation.

### What to do

1. Find which Google project holds the Worker's key. The secret is set with `npx wrangler secret`,
   so the project is not in the repository — it is visible in AI Studio, or by the key's own listing.
2. On that project's **Rate limits** page, read the 28-day peak for `gemini-2.5-flash-lite`, both
   RPD and RPM.
3. Record both figures, with the date, in this ticket. They are the input to tickets 02 and 03.

While there, note the same figures for `gemini-embedding-001`: the Worker spends one embedding call
per question on top of the generation call, and that quota is separate.

### Reading — 2026-10-04 (28-day window, read by David in AI Studio)

| Model | Peak RPD | Free-tier limit | Day of the peak |
|-------|----------|-----------------|-----------------|
| `gemini-2.5-flash-lite` (generation) | 23 | 20 | 2026-09-22 |
| `gemini-embedding-001` | 257 | 1000 | 2026-09-21 |

The peak RPM was not read.
The project holding the Worker's key is **VEAF documentation assistant** (`gen-lang-client-0120610618`).
The peak counted above the limit (23 against 20).
The likeliest reason is that refused calls are counted too, but that is not verified.

The embedding peak includes the reindex runs, which share the key.
`build-index.mjs` only embeds chunks that changed, so a reindex costs little.

**Verdict: the ceiling is being hit.** The generation quota was spent at least once in 28 days, so ticket 02's message was needed and has already been shown to visitors.
The embedding quota is far away.

### Definition of done

- [x] The project holding the Worker's key is identified and written down
- [x] 28-day peak RPD recorded for the generation model, with the date of the reading (RPM not read)
- [x] Embedding model quota and peak recorded too
- [x] A one-line verdict: is the ceiling being hit, near, or far away

## 02 — An exhausted quota says so, and says when it comes back

Status: ✅ done

Type: fix

### The problem

When the daily quota is spent, Gemini answers 429 and the Worker maps it to a user-facing message.
That mapping was written for a *rate* limit — something that clears in a minute — not for a **daily**
one that clears at midnight Pacific time. A visitor told to retry shortly will retry all evening.

The failure is also indistinguishable from a breakage: the widget answered a minute ago and does not
any more, with nothing saying why.

### What to build

- Tell the daily case apart from the per-minute case, and word them differently.
- For the daily case, say when it comes back **in the reader's terms**. Quotas reset at midnight
  Pacific, which is around 09:00 in Paris all year — so "midnight Pacific" means nothing to a
  mission maker, and "try again tomorrow" is right in the evening but **wrong at seven in the
  morning**, when the service returns two hours later on the same day. Naming the morning holds at
  both ends.
- Same treatment in both languages, and in the CLI client (`veaf-tools ask`) which hits the same
  Worker.
- The message must not read as a defect. Being rationed is a choice; sounding broken is a bug.

### Notes

- The Worker is deployed by hand; this reaches production only when `npx wrangler deploy` runs.
- Ticket 01's measurement decides whether this is urgent or precautionary. Write it either way — the
  cost is small and the failure mode is silent.

### Definition of done

- [x] Daily exhaustion distinguished from per-minute throttling — `isDailyQuotaFailure` reads the
      upstream body, where a `QuotaFailure` violation names its own period (`…PerDay…`); a long
      `retryDelay` is the fallback signal. An unreadable body keeps the per-minute wording.
- [x] Message states when service returns, in local terms rather than Pacific midnight — « repart
      chaque matin vers 9 h (heure de Paris) » / "refills each morning around 09:00 Central
      European time".
- [x] Both languages, widget and CLI — and both clients were **discarding** the Worker's message:
      each bailed on the HTTP status alone, so the 429 body never reached anyone. Both now read it.
- [x] Unit tests on both mappings, plus an end-to-end test that the daily body survives the whole
      path to the SSE payload (the mapping was never the part that was broken).
- [x] Worker README notes that deployment is manual and this is not live until it runs — it already
      did; a line was added spelling out that the user-facing strings are Worker-side too.

### What was left alone, and why

The Worker's **own** per-subject daily counter (`rl:day:…`) still answers with the per-minute
wording. It is a rolling 24 h TTL, not a midnight rollover, so the "back around 9 h" sentence would
be wrong for it — and its ceilings (100/day for the widget, 60 for the CLI, per IP) all sit above
the project-wide free-tier allowance, so it cannot fire before the upstream one does. Changing it
would have churned a dozen assertions to fix a message nobody can reach.

## 03 — The page tells visitors the assistant is rationed

Status: ✅ done

Type: docs

### What to write

One short passage, where the chatbot lives and on the support page, saying that the assistant runs
on a free allowance shared by every visitor, that it can run out on a busy day, and that it comes
back the next day. Nothing more — no numbers that will age, no apology.

The point is that someone who meets the limit understands they met a limit, rather than concluding
the tool is broken and never coming back.

### Notes

- Both languages in lockstep, and `poetry run docs-check` passes.
- No hand-written version numbers, no quota figures in prose: the numbers move, and the deploy
  workflow does not stamp them.
- If ticket 01 finds the ceiling is never approached, this stays worth writing — it costs three
  sentences and covers the day someone links the chatbot on Discord.

### Definition of done

- [x] The passage exists in both languages: in the widget's own welcome message (where the chatbot
      lives), in a `{#assistant}` section of `doc/SUPPORT.md` / `.en.md`, and beside
      `veaf-tools ask` in the CLI reference — the CLI spends the same allowance, and its readers
      never see the widget.
- [x] It explains the ration and the reset without naming figures
- [x] `poetry run docs-check` passes

## 04 — When the day's allowance is spent, answer with another model

Status: ✅ done

Type: feat

### The problem

Ticket 01 measured the ceiling being hit: 23 generation requests against 20 on 2026-09-22.
That allowance is shared by every caller of the Worker — the documentation widget, `veaf-tools ask`, the Discord bot on `/chat` and `/analyze` — since they all go through the single generation call in `streamGemini` ([`src/index.js`](../../poc/doc-chatbot/worker/src/index.js)).
Ticket 02 made the failure honest; it did not make it rarer.

Billing stays off (David, 2026-09-05).
But the free tier counts **per model**: a model that has not been called today still has its whole allowance.
So when the primary model answers that the daily quota is spent, the Worker can ask the same question to the next model in a chain.

### The chain

| Rank | Model | Why |
|------|-------|-----|
| 1 | `gemini-2.5-flash-lite` | The current model |
| 2 | `gemini-2.5-flash` | Same family, the system instruction works unchanged; 20 more a day |
| 3 | Gemma 4 — 26B **or** 31B, chosen by measurement | Its own, much larger allowance |

AI Studio lists both Gemma 4 models with a figure of 14.4K (David, 2026-10-04).
Which column it sits in — requests per day or tokens per minute — was not read; the historical Gemma free tier was 14 400 requests per day and about 15 000 tokens per minute, from memory, not measured.
Chaining both Gemma models buys nothing if the figure is per day: one is enough.

### What to do

1. **Read the quotas.** On the *Rate limits* page of `gen-lang-client-0120610618`, record RPM, TPM and RPD for `gemini-2.5-flash` and both Gemma 4 models, with the date.
   A question costs about 4–5 k tokens before history (6 passages of up to 2 000 characters, plus the system instruction), so a 15 k TPM cap means two or three questions a minute on the fallback.
2. **Read the exact model ids** from the API's model listing, not from AI Studio's display names.
3. **Check the call contract on each candidate.** The Worker sends `systemInstruction` and streams with `streamGenerateContent?alt=sse`.
   Gemma models served by the Gemini API are believed to reject `systemInstruction` (unverified); if so, the instruction goes into the first user turn for that model only.
   `gemini-2.5-flash` thinks by default — disable it (`thinkingBudget: 0`) so it behaves like flash-lite on tokens and latency.
4. **Fall back on the daily case only.** `isDailyQuotaFailure` already tells a spent day from a per-minute throttle.
   A per-minute 429 keeps today's behaviour; only a spent day moves to the next model, and only before any token has been streamed to the caller.
5. **Choose the Gemma by measurement.** Deploy a preview Worker that forces each candidate, and replay `scripts/answer-cases.json` against it with `scripts/replay-answers.mjs --endpoint`.
   Keep the one that passes the most cases in both languages; at a tie, the faster one.
6. **Revisit the messages.** `dailyQuota` ("back around 09:00") must only fire when the **whole chain** is spent.
   And ticket 02 left the Worker's own per-subject daily counter (`rl:day:…`, 100/day for the widget, 60 for the CLI, 30 for logs, 40 for Discord) on the per-minute wording, on the ground that it could never fire before the upstream 20.
   With a fallback of thousands a day it **can** fire first — its wording has to be fixed in the same lot. It is a rolling 24 h window, so it must not promise 09:00 either.

### Definition of done

- [x] Quotas recorded — 2026-10-04, read by David in AI Studio: `gemma-4-26b-a4b-it` and `gemma-4-31b-it` each **14 400 RPD and 16 000 TPM** (the 14.4K figure was requests per day). RPM not read. `gemini-2.5-flash` stays at the 20 RPD read on 2026-09-05.
      At 4–5 k tokens a question, 16 000 TPM is three questions a minute on a Gemma, and a full `/analyze` excerpt (40 000 characters, about 10 k tokens) one a minute — which is why a fallback's per-minute refusal hands over to the next model. The day's ceiling now sits far above the Worker's own per-caller caps.
- [x] Exact model ids — `gemma-4-26b-a4b-it` and `gemma-4-31b-it`, from Google's *Run Gemma with the Gemini API* page (2026-10-04), which also documents `systemInstruction` as supported and `thinkingLevel: "minimal"` as thinking off. Not yet observed against the live API: the replay below is that observation.
- [x] Fallback on a spent day only, tested: per-minute 429 does not fall back, a non-quota failure is reported as is, a spent primary moves to rank 2, a spent chain gives the `dailyQuota` message
- [x] Every model is sent the same `systemInstruction`, with its own `thinkingConfig`; a streamed `thought` part is never relayed
- [x] `replay-answers.mjs --model <id>` pins one chain entry, asked alone with no fallback; any id outside the chain is a 400
- [x] Gemma 26B vs 31B decided on a replay of `answer-cases.json` once deployed (#1066), results below. Neither is dropped: each has its own TPM budget, so keeping both doubles the per-minute throughput at no cost. 26B stays first.

### Replay — 2026-10-04, live Worker, `replay-answers.mjs --model`

| Model | Run | Cases passed | Wall time for 3 cases (16 s of it is pacing) |
|-------|-----|--------------|----------------------------------------------|
| `gemma-4-26b-a4b-it` | 1 | 2 of 3 | 38 s |
| `gemma-4-26b-a4b-it` | 2 | 3 of 3 | 38 s |
| `gemma-4-31b-it` | 1 | 3 of 3 | 132 s |

Both models accepted `systemInstruction` and `thinkingLevel: "minimal"`: every case got an answer, none an error.
That is the live observation the ids and the call contract were waiting for.
On answers they are level within what three non-deterministic cases can tell (26B missed one marker once, and the run log did not keep which).
On speed 26B answers in about 7 s, 31B in about 39 s, so 26B goes first.
Three cases is a small sample: it rules out a broken model, not a subtly worse one.

A baseline run on `gemini-2.5-flash-lite` right after got one answer and two 429s from the Worker's own `cli` burst limit (10 a minute), spent by the runs before it, not from Google.
- [x] Worker's own daily cap has a wording of its own, in both languages (`callerDailyCap`: resets 24 h after the caller's latest question)
- [x] Worker README updated; `doc/SUPPORT.md` / `.en.md` and the CLI reference still true as written — they say the assistant is rationed and comes back the next day, which stays right but becomes rarer
