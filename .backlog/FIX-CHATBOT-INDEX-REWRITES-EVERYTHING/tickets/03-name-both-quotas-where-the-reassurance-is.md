# 03 — Name both quotas where the reassurance is

Status: ✅ done

Type: doc

## The problem

The header of `build-index.mjs` reads:

> a typical doc edit then costs a handful of embeds, well under the free-tier 1000/day cap

True, and about the **Gemini** quota. There are two free-tier caps of 1 000 a day in this pipeline
and the sentence covers the guarded one, which reads as though both were. The unguarded one is the
one that broke.

A third consumer belongs in the same note: the Worker writes **two KV entries per chat request**
(the burst and daily rate-limit counters, `src/index.js`). They draw on the same account-wide
1 000 writes a day as the index. So the index budget is not 1 000, it is 1 000 minus what the
visitors spend — one more reason a reindex should cost four writes and not a thousand.

## What to do

State both caps, and the counters, where someone deciding to add a KV key would read them:

- the header of `build-index.mjs`
- the KV section of `wrangler.toml`
- `poc/doc-chatbot/README.md`, whose upload commands change with ticket 01 anyway

## Definition of done

- [ ] The three places name the Gemini embeddings cap **and** the Cloudflare KV write cap
- [ ] The rate-limit counters are named as sharing the KV cap
- [ ] The README's upload and verification commands match the four-key layout
