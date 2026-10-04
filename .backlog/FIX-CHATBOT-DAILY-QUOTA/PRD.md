# FIX-CHATBOT-DAILY-QUOTA — the website chatbot has a ceiling nobody has looked at

Status: ✅ done

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
| 01 | [Read the real usage before fixing anything](tickets/01-measure-real-usage.md) | chore |
| 02 | [An exhausted quota says so, and says when it comes back](tickets/02-quota-message.md) | fix |
| 03 | [The page tells visitors the assistant is rationed](tickets/03-document-the-ceiling.md) | docs |
| 04 | [When the day's allowance is spent, answer with another model](tickets/04-model-fallback.md) | feat |

Tickets 01–03 are done: 02 and 03 shipped in #916 on 2026-09-05, and 01 found the ceiling hit — 23 generation requests against 20 on 2026-09-22.
Ticket 04 was added on 2026-10-04 because of that reading: the free tier counts per model, so a chain of models raises the ceiling without enabling billing.

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**the website chatbot has a ceiling nobody has looked at**. Measured on 2026-09-05 while sizing the support programme: Google's free tier is **20 requests per day** for `gemini-2.5-flash-lite` (10 RPM) and for `gemini-2.5-flash` (5 RPM), per project — read off AI Studio, not from documentation. The production chatbot spends one generation call per question, so its ceiling is on the order of twenty questions a day for every visitor of the site combined, low enough that one link posted on Discord could exhaust it in an afternoon. **What is not measured** is whether it ever gets there: the screen consulted was showing the wrong Google project, so ticket 01 is to read the real peak before anything else — it may be three a day, in which case this lot is a message and a documentation line. Either way the failure is invisible from outside: the widget answers, then stops, and a visitor concludes it is broken rather than rationed. David decided the same day **not to enable billing** (50 analyses a day for the support bot would have run about $6 a month at the paid rate), so the ceiling stays; what changes is that it stops being silent
