# 02 — An exhausted quota says so, and says when it comes back

Status: ✅ done

Type: fix

## The problem

When the daily quota is spent, Gemini answers 429 and the Worker maps it to a user-facing message.
That mapping was written for a *rate* limit — something that clears in a minute — not for a **daily**
one that clears at midnight Pacific time. A visitor told to retry shortly will retry all evening.

The failure is also indistinguishable from a breakage: the widget answered a minute ago and does not
any more, with nothing saying why.

## What to build

- Tell the daily case apart from the per-minute case, and word them differently.
- For the daily case, say when it comes back **in the reader's terms**. Quotas reset at midnight
  Pacific, which is around 09:00 in Paris all year — so "midnight Pacific" means nothing to a
  mission maker, and "try again tomorrow" is right in the evening but **wrong at seven in the
  morning**, when the service returns two hours later on the same day. Naming the morning holds at
  both ends.
- Same treatment in both languages, and in the CLI client (`veaf-tools ask`) which hits the same
  Worker.
- The message must not read as a defect. Being rationed is a choice; sounding broken is a bug.

## Notes

- The Worker is deployed by hand; this reaches production only when `npx wrangler deploy` runs.
- Ticket 01's measurement decides whether this is urgent or precautionary. Write it either way — the
  cost is small and the failure mode is silent.

## Definition of done

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

## What was left alone, and why

The Worker's **own** per-subject daily counter (`rl:day:…`) still answers with the per-minute
wording. It is a rolling 24 h TTL, not a midnight rollover, so the "back around 9 h" sentence would
be wrong for it — and its ceilings (100/day for the widget, 60 for the CLI, per IP) all sit above
the project-wide free-tier allowance, so it cannot fire before the upstream one does. Changing it
would have churned a dozen assertions to fix a message nobody can reach.
