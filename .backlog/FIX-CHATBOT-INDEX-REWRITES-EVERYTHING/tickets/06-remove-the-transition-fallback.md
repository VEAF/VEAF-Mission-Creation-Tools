# 06 — Remove the transition fallback once production holds the new index

Status: ⬜ ready — unblocked 2026-09-22 by ticket 04: production holds the new index in fr and en

Type: chore

## The problem

Raised by the review pass over git history. The Worker and the index ship through **two workflows
with no ordering between them**:

- `chatbot-worker.yml` deploys on any push to `develop` touching `poc/doc-chatbot/worker/**` —
  which this lot does, so the merge itself deploys the new Worker.
- `docs-chatbot-index.yml` rebuilds the index separately, and can fail.

So the new code reaches production **before** `idx:txt:{lang}` exists, and a failed rebuild leaves
it there. On the day this lot shipped that was the likely case rather than the unlucky one: five
rebuilds had already failed on the KV write quota, the one success being 09:56. Without a
fallback, `loadIndex` would have thrown `no passages for fr` and the caller turned it into a
**502 on every question** until the quota reset at midnight UTC.

`loadIndex` therefore keeps a shim: when `idx:txt:{lang}` is absent it serves the pre-2026-09-21
per-chunk `idx:txt:{lang}:{i}` entries, reading only the top-K so that path costs the same six KV
reads the old code did. A genuinely missing index still surfaces, one step later, as
`no passages retrieved`.

## What to do

Once ticket 04 confirms the live assistant answers from the new index in **both** languages:

- drop the `texts === null` branch in `loadIndex` and the fallback in `retrieveContext`
  (`poc/doc-chatbot/worker/src/index.js`), restoring `no passages for {lang}` on an absent key
- drop the two transition tests in `poc/doc-chatbot/worker/test/unit.test.mjs`
- drop the transition sentence from the `CHANGELOG.md` entry if it has not shipped yet

Leave the old `idx:txt:{lang}:{i}` keys where they are — deleting them costs writes, and they are
about 2 MB of a 1 GB allowance.

## Definition of done

- [x] Ticket 04 closed: the live assistant answers from the new index, fr and en (2026-09-22)
- [ ] The shim, its comments and its two tests are gone
- [ ] `no passages for {lang}` is raised again when `idx:txt:{lang}` is missing
