# 04 — `/bug` runs on the same tight token budget `/suggest` was fixed for

Status: ⬜ ready

Type: fix

## What is wrong

A deferred Discord interaction token dies after **fifteen minutes**. `/bug` spends two waits inside
one: the prior-art proposal (`MATCH_EXPIRY_SECONDS = 300`) and the draft (`DRAFT_EXPIRY_SECONDS =
480`). 780 of 900 seconds, which `draft.py`'s own comment describes as *"leaves two minutes to write
the last message"* — before counting the preparation that precedes them: downloading an 11 MB log,
summarising a mission, walking a checkout for callers.

Finding 50 of lot 4's review. Recorded, not corrected.

The failure it produces is the worst kind: somebody lets the first question expire, takes his time
on the draft, clicks **File the issue** — and the token is dead. He has consented to something that
will never happen, and the service cannot even tell him, since telling him needs the same token.

## What to build

What lot 5 built for `/suggest`, in `SuggestIntake._may_ask`: measure the elapsed time and skip a
*verification* question when the consent click would no longer fit. The checks give way, never the
consent — and a skipped check is still computed and still recorded in the issue.

Read that implementation first; the point is one behaviour in two flows, not two variants.

## Definition of done

- [ ] `/bug` bounds its questions against the token's life, the consent click protected last
- [ ] A skipped sweep is still recorded in the issue, saying nobody was asked
- [ ] The numbers live in one place shared with `/suggest`, not copied
- [ ] Unit tests: a late exchange skips the question and still files; the click always fits
- [ ] Quality gate clean
