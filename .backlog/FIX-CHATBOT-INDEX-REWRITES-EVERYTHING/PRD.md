# FIX-CHATBOT-INDEX-REWRITES-EVERYTHING — one reindex costs more than a day's free quota

Status: 🔄 in-progress

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

**Stop spending a write per chunk.** The texts become **one KV value per language**, positionally
aligned with the vector blob that is already stored that way: `idx:vec:{lang}` and `idx:txt:{lang}`.
Four writes per rebuild, whether one heading changed or the whole documentation did.

### The scheme this replaced, and why it was dropped

The first sketch here was to key each chunk on a content hash, with a small manifest giving the
order, so an edit would cost its own chunks and nothing else. It was written before anything on the
Worker side was measured. Two numbers, taken 2026-09-21 (Node 26, over the current `doc/`):

- The Worker **already** loads a 2.12 MB vector blob per isolate. The French texts add 1.09 MB and
  **1.23 ms** of `JSON.parse`, once per isolate — against a free-plan ceiling of 10 ms of CPU per
  request, and next to the cosine loop's **0.35 ms spent on every single request**. The change also
  *removes* the six per-question KV reads that fetched the top-K texts one key at a time.
- Content-addressed keys would have needed a first run rewriting all 1 395 entries under the new
  naming — over the cap again — so a resume mechanism, a per-run write budget and a diffing script.
  Three times the code, the same visible result, and a two-day migration.

### Two traps to design around, both from this repository's own history

- **The key was the chunk's index** (`idx:txt:fr:17`), not its content. Insert a heading near the
  top of a page and every subsequent chunk shifts. That is not only a write-cost problem: the
  Worker cached the vector blob per isolate and fetched the texts fresh, so an isolate holding the
  old blob after a rebuild served passages shifted by the number of chunks inserted, with nothing
  raising an error. Loading both halves together and refusing a length disagreement closes that.
- **A `kv key get` on a missing key exits 0**, and a wrangler major changed `kv key put` from remote to
  local without changing the command — six weeks of green, empty reindexing went unnoticed that way
  (see the `a-dependency-bump-can-change-a-default` memory). So whatever this lot does, it has to end
  with a check that reads a known key **back from the remote namespace** and fails loudly on a miss.

### Residue

The 1 395 old `idx:txt:{lang}:{i}` keys stay in the namespace, unread. Deleting them counts as
writes, which would cost the two days of quota this change exists to save; they are about 2 MB of a
1 GB free allowance.

## Definition of done

- [ ] A reindex after a one-page doc edit costs writes in the single or double digits, measured and
      printed by the workflow so the next regression is visible.
- [ ] A verification step that reads a key back from the **remote** namespace and fails on a miss.
- [ ] The header comment of `build-index.mjs` names **both** quotas, since it currently reassures
      about the one that is guarded while the unguarded one is the one that breaks.
- [ ] The index rebuilt once by hand (`workflow_dispatch`) after the quota resets, so production
      catches up on #975, #977 and #978.
