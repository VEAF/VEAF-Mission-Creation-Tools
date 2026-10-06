# 04 — When the day's allowance is spent, answer with another model

Status: ✅ done

Type: feat

## The problem

Ticket 01 measured the ceiling being hit: 23 generation requests against 20 on 2026-09-22.
That allowance is shared by every caller of the Worker — the documentation widget, `veaf-tools ask`, the Discord bot on `/chat` and `/analyze` — since they all go through the single generation call in `streamGemini` ([`src/index.js`](../../../poc/doc-chatbot/worker/src/index.js)).
Ticket 02 made the failure honest; it did not make it rarer.

Billing stays off (David, 2026-09-05).
But the free tier counts **per model**: a model that has not been called today still has its whole allowance.
So when the primary model answers that the daily quota is spent, the Worker can ask the same question to the next model in a chain.

## The chain

| Rank | Model | Why |
|------|-------|-----|
| 1 | `gemini-2.5-flash-lite` | The current model |
| 2 | `gemini-2.5-flash` | Same family, the system instruction works unchanged; 20 more a day |
| 3 | Gemma 4 — 26B **or** 31B, chosen by measurement | Its own, much larger allowance |

AI Studio lists both Gemma 4 models with a figure of 14.4K (David, 2026-10-04).
Which column it sits in — requests per day or tokens per minute — was not read; the historical Gemma free tier was 14 400 requests per day and about 15 000 tokens per minute, from memory, not measured.
Chaining both Gemma models buys nothing if the figure is per day: one is enough.

## What to do

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

## Definition of done

- [x] Quotas recorded — 2026-10-04, read by David in AI Studio: `gemma-4-26b-a4b-it` and `gemma-4-31b-it` each **14 400 RPD and 16 000 TPM** (the 14.4K figure was requests per day). RPM not read. `gemini-2.5-flash` stays at the 20 RPD read on 2026-09-05.
      At 4–5 k tokens a question, 16 000 TPM is three questions a minute on a Gemma, and a full `/analyze` excerpt (40 000 characters, about 10 k tokens) one a minute — which is why a fallback's per-minute refusal hands over to the next model. The day's ceiling now sits far above the Worker's own per-caller caps.
- [x] Exact model ids — `gemma-4-26b-a4b-it` and `gemma-4-31b-it`, from Google's *Run Gemma with the Gemini API* page (2026-10-04), which also documents `systemInstruction` as supported and `thinkingLevel: "minimal"` as thinking off. Not yet observed against the live API: the replay below is that observation.
- [x] Fallback on a spent day only, tested: per-minute 429 does not fall back, a non-quota failure is reported as is, a spent primary moves to rank 2, a spent chain gives the `dailyQuota` message
- [x] Every model is sent the same `systemInstruction`, with its own `thinkingConfig`; a streamed `thought` part is never relayed
- [x] `replay-answers.mjs --model <id>` pins one chain entry, asked alone with no fallback; any id outside the chain is a 400
- [x] Gemma 26B vs 31B decided on a replay of `answer-cases.json` once deployed (#1066), results below. Neither is dropped: each has its own TPM budget, so keeping both doubles the per-minute throughput at no cost. 26B stays first.

## Replay — 2026-10-04, live Worker, `replay-answers.mjs --model`

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
