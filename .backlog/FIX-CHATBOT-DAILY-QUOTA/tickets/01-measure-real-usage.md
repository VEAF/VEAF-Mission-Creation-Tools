# 01 — Read the real usage before fixing anything

Status: ✅ done

Type: chore

## The problem

The ceiling is known — 20 requests per day on the free tier — but not whether the chatbot reaches
it. The AI Studio screen consulted on 2026-09-05 was showing the *VEAF NodeBB community* project,
not the one holding the Worker's `GEMINI_API_KEY`, so the peak usage of the chatbot itself was never
read.

Everything else in this lot depends on that number. If the site serves three questions a day, the
rest is one sentence of documentation. If it clips 20 regularly, visitors are meeting a wall with no
explanation.

## What to do

1. Find which Google project holds the Worker's key. The secret is set with `npx wrangler secret`,
   so the project is not in the repository — it is visible in AI Studio, or by the key's own listing.
2. On that project's **Rate limits** page, read the 28-day peak for `gemini-2.5-flash-lite`, both
   RPD and RPM.
3. Record both figures, with the date, in this ticket. They are the input to tickets 02 and 03.

While there, note the same figures for `gemini-embedding-001`: the Worker spends one embedding call
per question on top of the generation call, and that quota is separate.

## Reading — 2026-10-04 (28-day window, read by David in AI Studio)

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

## Definition of done

- [x] The project holding the Worker's key is identified and written down
- [x] 28-day peak RPD recorded for the generation model, with the date of the reading (RPM not read)
- [x] Embedding model quota and peak recorded too
- [x] A one-line verdict: is the ceiling being hit, near, or far away
