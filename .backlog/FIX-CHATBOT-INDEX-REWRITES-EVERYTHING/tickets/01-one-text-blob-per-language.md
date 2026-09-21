# 01 — One text blob per language, so a reindex costs four writes

Status: ✅ done

Type: fix

## The problem

`idx:txt:{lang}:{i}` is one KV entry per chunk. Measured on 2026-09-21 by running the indexer's own
`chunkMarkdown` over `doc/`: 157 pages, **724** French chunks and **671** English ones, so **1 397**
KV writes per reindex against a free-tier cap of **1 000 a day**. One full reindex cannot fit in a
day, whatever changed.

## What to do

Store the texts of a language the way its vectors are already stored: **one value**, aligned with
the vector blob by position.

| key | value |
|---|---|
| `idx:vec:{lang}` | Float32 blob, unchanged |
| `idx:txt:{lang}` | JSON array of `{text, title, path}`, same order as the blob |

Four writes per reindex, always — a one-word fix and a full rebuild cost the same.

### Why not the content-hash scheme the PRD sketched

It was written before the Worker side was measured. Two numbers settle it:

- The Worker **already** pulls a 2.12 MB vector blob per isolate; the French texts add 1.09 MB and
  **1.23 ms** of `JSON.parse`, once per isolate (measured 2026-09-21, Node 26). For comparison the
  cosine loop costs **0.35 ms on every single request**. The free-plan ceiling is 10 ms of CPU per
  request, so the one-off parse sits well inside it — and the change *removes* the six per-request
  KV reads that fetched the top-K texts.
- Content-hash keys would need a first run rewriting all 1 397 entries under the new naming — over
  the cap again — hence a resume mechanism, a per-run budget and a diffing script. Three times the
  code for the same visible result.

### Residue, stated rather than discovered later

The 1 395 old `idx:txt:{lang}:{i}` keys stay in the namespace, unread. Deleting them counts as
writes too, so it would cost the two days of quota this lot exists to avoid. They are about 2 MB of
a 1 GB free allowance.

## Definition of done

- [ ] `build-index.mjs` emits `txt-{lang}.json` as the **KV value** (a JSON array), not a bulk file
- [ ] The Worker loads vectors and texts **together**, caches them together, and refuses an index
      whose two halves disagree on length — a skew serves the wrong passage for a vector, silently
- [ ] The indexer refuses a cached vector of the wrong width. Raised by the review pass over past
      PRs, which found the same warning left unanswered on #422: the cache is keyed on the chunk
      text alone, not on the model. Measured 2026-09-21 — a 384-wide entry among 768-wide ones is
      zero-padded into its slot, so the blob length and the passage count both stay exactly right
      and the length check above passes while that passage ranks on half a vector
- [ ] Unit tests cover the new retrieval path and the length-skew refusal
- [ ] A test pins the invariant that matters: **two** KV keys per language, whatever the chunk count
