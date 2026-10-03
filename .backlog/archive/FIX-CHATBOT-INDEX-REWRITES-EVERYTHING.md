# FIX-CHATBOT-INDEX-REWRITES-EVERYTHING — one reindex costs more than a day's free quota

Status: ✅ done — PR #980 merged 2026-09-21 (tickets 01 to 05, ticket 04 closed 2026-09-22 with · archived 2026-10-02
production holding the new index, fr and en); ticket 06 — remove the transition fallback — merged
2026-09-30 in #1034.

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

## Tickets, in full

## 01 — One text blob per language, so a reindex costs four writes

Status: ✅ done

Type: fix

### The problem

`idx:txt:{lang}:{i}` is one KV entry per chunk. Measured on 2026-09-21 by running the indexer's own
`chunkMarkdown` over `doc/`: 157 pages, **724** French chunks and **671** English ones, so **1 397**
KV writes per reindex against a free-tier cap of **1 000 a day**. One full reindex cannot fit in a
day, whatever changed.

### What to do

Store the texts of a language the way its vectors are already stored: **one value**, aligned with
the vector blob by position.

| key | value |
|---|---|
| `idx:vec:{lang}` | Float32 blob, unchanged |
| `idx:txt:{lang}` | JSON array of `{text, title, path}`, same order as the blob |

Four writes per reindex, always — a one-word fix and a full rebuild cost the same.

#### Why not the content-hash scheme the PRD sketched

It was written before the Worker side was measured. Two numbers settle it:

- The Worker **already** pulls a 2.12 MB vector blob per isolate; the French texts add 1.09 MB and
  **1.23 ms** of `JSON.parse`, once per isolate (measured 2026-09-21, Node 26). For comparison the
  cosine loop costs **0.35 ms on every single request**. The free-plan ceiling is 10 ms of CPU per
  request, so the one-off parse sits well inside it — and the change *removes* the six per-request
  KV reads that fetched the top-K texts.
- Content-hash keys would need a first run rewriting all 1 397 entries under the new naming — over
  the cap again — hence a resume mechanism, a per-run budget and a diffing script. Three times the
  code for the same visible result.

#### Residue, stated rather than discovered later

The 1 395 old `idx:txt:{lang}:{i}` keys stay in the namespace, unread. Deleting them counts as
writes too, so it would cost the two days of quota this lot exists to avoid. They are about 2 MB of
a 1 GB free allowance.

### Definition of done

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

## 02 — The workflow prints what it spends, and reads back all four keys

Status: ✅ done

Type: fix

### The problem

Nothing in the pipeline ever said how many KV writes a run costs. The quota was discovered by
reading a failure message, three merges after the first one broke. A cost that is never printed is
a cost nobody watches, and ticket 01 only holds as long as nobody reintroduces a per-chunk key.

### What to do

1. `build-index.mjs` prints the write cost of the upload it just prepared, and the cap it is
   measured against.
2. The workflow puts **four** keys (`idx:vec:{fr,en}`, `idx:txt:{fr,en}`) and writes the same figure
   to the job summary, so it is visible without opening the log.
3. The verification step reads **all four** back from the **remote** namespace and byte-compares
   them. The bulk-file special case goes away with the bulk file: `--txt` becomes the same plain
   comparison as `--vec`.

The `KV_MISSING_SENTINEL` handling stays exactly as it is. `kv key get` on an absent key still
exits 0 and prints `Value not found` to stdout, and that is still the only reason a missing key is
distinguishable from a value.

### Definition of done

- [ ] The write cost is printed by the build and lands in the job summary
- [ ] Four keys uploaded, four keys read back from `--remote` and compared byte for byte
- [ ] `verify-index-upload.mjs` no longer parses a bulk file; `--print-last-key` is gone with it
- [ ] Its tests follow the same path

## 03 — Name both quotas where the reassurance is

Status: ✅ done

Type: doc

### The problem

The header of `build-index.mjs` reads:

> a typical doc edit then costs a handful of embeds, well under the free-tier 1000/day cap

True, and about the **Gemini** quota. There are two free-tier caps of 1 000 a day in this pipeline
and the sentence covers the guarded one, which reads as though both were. The unguarded one is the
one that broke.

A third consumer belongs in the same note: the Worker writes **two KV entries per chat request**
(the burst and daily rate-limit counters, `src/index.js`). They draw on the same account-wide
1 000 writes a day as the index. So the index budget is not 1 000, it is 1 000 minus what the
visitors spend — one more reason a reindex should cost four writes and not a thousand.

### What to do

State both caps, and the counters, where someone deciding to add a KV key would read them:

- the header of `build-index.mjs`
- the KV section of `wrangler.toml`
- `poc/doc-chatbot/README.md`, whose upload commands change with ticket 01 anyway

### Definition of done

- [ ] The three places name the Gemini embeddings cap **and** the Cloudflare KV write cap
- [ ] The rate-limit counters are named as sharing the KV cap
- [ ] The README's upload and verification commands match the four-key layout

## 04 — Catch production up

Status: ✅ done — 2026-09-22, run 35702564003

Type: chore

### The problem

The live index is frozen at the last successful run, 2026-09-21 09:56. The documentation merged in
##975, #977 and #978 — including the new colour table for the spotter view — is not in it, and the
assistant answers as though those pages did not exist.

### What happened on merge (2026-09-21, 20:27 UTC)

The merge triggered both workflows. Measured, not assumed:

- **`Deploy the Worker` succeeded** (run 35651149962). Production runs the new code.
- **`Rebuild docs chatbot index` failed** (run 35651149986), on its **first** write:
  `A request to the Cloudflare API (…/values/idx%3Avec%3Afr) failed — your account has reached the
  free usage limit for this operation for today [code: 10048]`. The day's 1 000 writes were already
  gone: the 09:56 run had spent them under the old per-chunk layout, and five rebuilds had failed
  after it. So `idx:txt:{lang}` does not exist yet, in either language.
- **The live assistant answers anyway**, which is the point of the transition fallback added for
  exactly this case. Asked "Comment déclarer une combat zone dans mission.yaml ?" at 20:31 UTC, it
  returned the real `type: zone` block with `zone_name`, `friendly_name`, `briefing` and
  `training`. Without the fallback this would have been a 502, and every other question with it,
  until midnight UTC.

The answer above still comes from the **old** index, so it is the 09:56 snapshot: #975, #977 and
##978 are still missing from it. That is what remains to do.

### What to do

Once the KV quota resets (00:00 UTC), run `Rebuild docs chatbot index` by hand
(`workflow_dispatch`). With ticket 01 in place the run costs four writes, so a single reset is
enough and no further merge has to wait on it.

Then confirm on the live assistant, not on the workflow's own green: ask it something only the
newly merged pages answer. A green run proves the bytes landed; only an answer proves the bytes are
the right ones.

### Definition of done

- [x] The workflow run by hand after the quota resets, green, with `Index verified`
- [x] The printed write cost is 4
- [x] The live assistant answers a question that only #975/#977/#978 documents
- [ ] Then ticket 06: the transition fallback comes out

### Done — 2026-09-22 08:01 UTC, run 35702564003

The quota had reset at 00:00 UTC and nothing had rebuilt since the 21:12 failure, so the index was
still the 09:56 snapshot. Run by hand on `develop`, green in 1 min 20.

- `Prepared 1396 chunks; 1353 cached, 43 to embed` — the 43 are the newly merged pages.
- `KV writes to upload this index: 4 (2 keys x 2 languages)`, all four with `--remote`.
- `Index verified: the namespace holds exactly what this build produced.`

Confirmed on the live assistant rather than on the run's own green, in both languages, with the
spotter view's colour table — which only #978 documents:

| | |
|---|---|
| fr | *"que signifie un cercle orange autour d'un nœud ?"* → **"ce nœud a un avion en vue"** |
| en | *"orange circle / red square?"* → **"has an aircraft in sight" / "is a battery, and it is live"** |

Both HTTP 200. Ticket 06 is unblocked.

## 05 — The hand-run reindex never got the `--remote` fix

Status: ✅ done

Type: fix

### The problem

Found on 2026-09-21 while grepping for the last users of the bulk layout. `poetry run
reindex-docs` (`veaf_build/reindex_docs.py`) is a second path that builds and uploads the same
index, and it still read:

```python
base + ["key", "put", *common, "idx:vec:fr", "--path", "vec-fr.bin"],
...
base + ["bulk", "put", *common, "txt-fr.json"],
```

with `common = ["--binding", "CHAT_KV", "--preview", "false"]`. **No `--remote`.**

That is exactly the bug FIX-CHATBOT-INDEX-UPLOADS-LOCALLY closed on 2026-09-19 — wrangler 4 writes
to its local Miniflare store and prints `Success!` — fixed in the workflow and never here. So every
hand-run reindex since the wrangler 4 bump of 2026-08-08 wrote to a folder and reported success,
and nothing read it back. Its test asserted `--binding CHAT_KV` and `--preview false`, which is
what made the omission invisible: the command was checked for the flags someone thought of.

### What to do

- `--remote` on every command, and a test that asserts it on every command rather than on a sample
- `key put` for the texts, matching ticket 01 — a `bulk put` of a plain JSON array is not even the
  right file format any more
- the same read-back-and-compare the workflow does, run after the upload: this path had no
  verification at all, which is why a silent no-op survived a lot dedicated to that exact failure

### Definition of done

- [ ] All four uploads carry `--remote`, asserted per command
- [ ] Texts go up with `key put`; a test refuses `bulk` anywhere in the commands
- [ ] The command reads all four values back and compares them, failing loudly on a miss

## 06 — Remove the transition fallback once production holds the new index

Status: ✅ done — 2026-09-30

Type: chore

### The problem

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

### What to do

Once ticket 04 confirms the live assistant answers from the new index in **both** languages:

- drop the `texts === null` branch in `loadIndex` and the fallback in `retrieveContext`
  (`poc/doc-chatbot/worker/src/index.js`), restoring `no passages for {lang}` on an absent key
- drop the two transition tests in `poc/doc-chatbot/worker/test/unit.test.mjs`
- drop the transition sentence from the `CHANGELOG.md` entry if it has not shipped yet

Leave the old `idx:txt:{lang}:{i}` keys where they are — deleting them costs writes, and they are
about 2 MB of a 1 GB allowance.

### Definition of done

- [x] Ticket 04 closed: the live assistant answers from the new index, fr and en (2026-09-22)
- [x] The shim, its comments and its transition test are gone (the second one now asserts `no passages for {lang}`)
- [x] `no passages for {lang}` is raised again when `idx:txt:{lang}` is missing
