# 02 — An exhausted quota says so, and says when it comes back

Status: ⬜ ready

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
  Pacific, which is mid-morning in Europe — "try again tomorrow" is wrong for a European evening,
  and "midnight Pacific" means nothing to a mission maker.
- Same treatment in both languages, and in the CLI client (`veaf-tools ask`) which hits the same
  Worker.
- The message must not read as a defect. Being rationed is a choice; sounding broken is a bug.

## Notes

- The Worker is deployed by hand; this reaches production only when `npx wrangler deploy` runs.
- Ticket 01's measurement decides whether this is urgent or precautionary. Write it either way — the
  cost is small and the failure mode is silent.

## Definition of done

- [ ] Daily exhaustion distinguished from per-minute throttling
- [ ] Message states when service returns, in local terms rather than Pacific midnight
- [ ] Both languages, widget and CLI
- [ ] Unit tests on both mappings
- [ ] Worker README notes that deployment is manual and this is not live until it runs
