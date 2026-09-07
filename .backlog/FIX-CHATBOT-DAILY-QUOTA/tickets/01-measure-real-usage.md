# 01 — Read the real usage before fixing anything

Status: ⬜ ready

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

## Definition of done

- [ ] The project holding the Worker's key is identified and written down
- [ ] 28-day peak RPD and RPM recorded for the generation model, with the date of the reading
- [ ] Embedding model quota and peak recorded too
- [ ] A one-line verdict: is the ceiling being hit, near, or far away
