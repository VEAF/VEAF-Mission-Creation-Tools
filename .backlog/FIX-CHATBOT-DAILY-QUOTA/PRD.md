# FIX-CHATBOT-DAILY-QUOTA — the website chatbot has a ceiling nobody has looked at

Status: ⬜ ready

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
- Daily quotas reset at **midnight Pacific time**, which is late afternoon in Europe. A message
  saying "try tomorrow" would be wrong for most of the European evening.
- The Worker is deployed by hand (`npx wrangler deploy`); nothing here reaches production until
  that runs.
- Both documentation languages, in lockstep.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Read the real usage before fixing anything](tickets/01-measure-real-usage.md) | chore |
| 02 | [An exhausted quota says so, and says when it comes back](tickets/02-quota-message.md) | fix |
| 03 | [The page tells visitors the assistant is rationed](tickets/03-document-the-ceiling.md) | docs |
