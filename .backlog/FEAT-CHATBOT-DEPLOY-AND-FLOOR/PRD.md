# FEAT-CHATBOT-DEPLOY-AND-FLOOR — deploy the Worker from CI, and put a measured number under the floor

Status: 🔄 in-progress

Opened 2026-09-19, straight out of
[FIX-CHATBOT-INDEX-UPLOADS-LOCALLY](../FIX-CHATBOT-INDEX-UPLOADS-LOCALLY/PRD.md). Two things that
lot established and deliberately left alone, both now asked for.

## Why these two together

They are the same failure seen twice. The chatbot has three moving parts in production — the
**index**, the **Worker code**, and the **floor** that decides what the Worker retrieves — and until
today not one of them had a reliable path from the repository to production:

| Part | State before today | After |
|---|---|---|
| Index | rebuilt by CI, uploaded nowhere, green for six weeks | fixed and verified (#968) |
| Worker code | deployed by hand; #966 sat undeployed until it was noticed | **ticket 01** |
| Floor | `0.35`, explicitly shipped as "not a measured value" | **ticket 02** |

And they are coupled: once the deploy is automated, the floor can live in `wrangler.toml` as a
version-controlled `[vars]` entry instead of a dashboard setting nobody can read from the
repository. Measuring it and having nowhere good to put it would be half a job.

## What is known going in, so it is not re-derived

- `MIN_SIMILARITY` is read through `minSimilarity(env)`, which falls back to `DEFAULT_MIN_SIMILARITY`
  on anything unparseable or outside `(0, 1)` — so a bad value can neither gag the assistant nor
  disable the floor. A `[vars]` entry arrives as a string and `Number.parseFloat` handles it.
- Retrieval embeds the question with task type **`RETRIEVAL_QUERY`**, while the index embeds chunks
  with `RETRIEVAL_DOCUMENT`. A calibration that used the wrong task type would measure a different
  quantity from the one the Worker compares against the floor.
- Vectors in the index are already L2-normalised, so the cosine is a plain dot product.
- The live token holds **KV edit** (proved by #968's run). Whether it holds **Workers Scripts edit**
  is unknown — nothing has ever needed it. If it does not, ticket 01's job fails loudly, which is
  the correct outcome and needs a wider token rather than a code change.

## Definition of done

- [ ] 01 — a push to `develop` touching the Worker deploys it, after its tests
- [ ] 02 — the floor is measured against the **live** index, with the numbers recorded here
- [ ] 02 — the chosen value is version-controlled rather than set in a dashboard
- [ ] Worker unit tests, `docs-check` and the Python suite green
