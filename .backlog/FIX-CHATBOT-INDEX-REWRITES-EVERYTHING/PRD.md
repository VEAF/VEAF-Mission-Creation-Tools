# FIX-CHATBOT-INDEX-REWRITES-EVERYTHING — one reindex costs more than a day's free quota

Status: ⬜ ready

Found on 2026-09-21 while watching CI after a merge: `Rebuild docs chatbot index` had been **red for
three consecutive merges** and nobody had noticed.

## The measurement

```
your account has reached the free usage limit for this operation for today [code: 10048]
```

Cloudflare's free KV tier allows **1 000 writes a day**. Counted by running the indexer's own
`chunkMarkdown` over `doc/`:

| | |
|---|---|
| documentation pages | **157** |
| chunks, French | **719** |
| chunks, English | **666** |
| KV writes per reindex | **1 387** (both bulk text uploads, plus the two vector blobs) |
| free daily cap | **1 000** |

So **a single full reindex already exceeds the daily quota.** The failure is not "several merges in
one day exhausted it": the first doc-touching merge of the day spends the budget, and every one after
it fails before writing a byte — the run that failed died on its *first* upload, the `idx:vec:fr`
blob, because the budget was gone before it started.

**Consequence, which is the part that matters:** the documentation assistant answers from an index
frozen at the last successful run. On 2026-09-21 that was 09:56, and the doc changes merged in #975,
#977 and #978 — including a new colour table for the spotter view — were not in it.

## Why the existing guard does not help

`scripts/build-index.mjs` already caches embeddings, and says so in its header: *"a typical doc edit
then costs a handful of embeds, well under the free-tier 1000/day cap"*. That protects the **Gemini**
quota, and it works.

Nothing protects the **Cloudflare KV write** quota. Line 217 builds the upload from every record:

```js
const bulk = recs.map((r, i) => ({
  key: `idx:txt:${lang}:${i}`,
  value: JSON.stringify({ text: r.text, title: r.title, path: r.path }),
}));
```

Every chunk, every run, both languages — even when one page changed one heading. Two quotas, one
guarded and one not, and the header comment reads as though both were covered.

## What to do

**Upload only what changed**, the same way embeddings are already reused. The cache the embedding step
persists with `actions/cache` is keyed on the chunk's content hash, so the information needed to skip
an unchanged chunk is already there.

Two traps to design around, both from this repository's own history:

- **The key is the chunk's index** (`idx:txt:fr:17`), not its content. Insert a heading near the top
  of a page and every subsequent chunk shifts, so an index-keyed store has to rewrite the tail anyway.
  Keying on a content hash, with one small manifest listing the current order, would make an edit cost
  its own chunks and nothing else.
- **A `kv key get` on a missing key exits 0**, and a wrangler major changed `kv key put` from remote to
  local without changing the command — six weeks of green, empty reindexing went unnoticed that way
  (see the `a-dependency-bump-can-change-a-default` memory). So whatever this lot does, it has to end
  with a check that reads a known key **back from the remote namespace** and fails loudly on a miss.

## Definition of done

- [ ] A reindex after a one-page doc edit costs writes in the single or double digits, measured and
      printed by the workflow so the next regression is visible.
- [ ] A verification step that reads a key back from the **remote** namespace and fails on a miss.
- [ ] The header comment of `build-index.mjs` names **both** quotas, since it currently reassures
      about the one that is guarded while the unguarded one is the one that breaks.
- [ ] The index rebuilt once by hand (`workflow_dispatch`) after the quota resets, so production
      catches up on #975, #977 and #978.
