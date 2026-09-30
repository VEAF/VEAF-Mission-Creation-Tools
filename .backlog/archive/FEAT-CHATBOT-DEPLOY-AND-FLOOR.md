# FEAT-CHATBOT-DEPLOY-AND-FLOOR — deploy the Worker from CI, and put a measured number under the floor

Status: ✅ done — merged as #969 · archived 2026-09-28

Opened 2026-09-19, straight out of
[FIX-CHATBOT-INDEX-UPLOADS-LOCALLY](FIX-CHATBOT-INDEX-UPLOADS-LOCALLY.md). Two things that
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

## Outcome — measured 2026-09-19 {#outcome}

### 01 — the Worker deploys itself

Merged as #969, and the merge was the test. The run it triggered deployed for real — `Uploaded
veaf-docs-chatbot`, **Version ID `efef2f32`**, distinct from the `60a15356` deployed by hand
twenty minutes earlier — and the smoke probe passed (`POST /nope -> 404`, `POST /analyze -> 403`).

**The token already held Workers Scripts edit.** That was the open risk and it did not materialise;
nothing needs widening. On the pull request, `Deploy the Worker` reported *skipping*, which is the
guard working.

### 02 — the floor, and what the measurement actually said

24 questions per language against the live index (708 French chunks, 655 English):

| | documented | undocumented | |
|---|---|---|---|
| **fr** | 0.694 – 0.846 (median 0.785) | 0.605 – **0.736** (median 0.674) | clouds **overlap** by 3 |
| **en** | **0.750** – 0.831 (median 0.770) | 0.578 – 0.724 (median 0.655) | clouds separate |

Two findings, and the first was not what anyone was looking for:

1. **The shipped default of `0.35` was a no-op.** Nothing in 48 questions scored below **0.578** —
   not the Spitfire's propeller pitch, not the price of a DCS module. A floor set at 0.35 has never
   filtered a single passage. It was shipped as "a guard against the plainly unrelated"; it was not
   even that.
2. **No floor separates the two clouds in French.** An undocumented question reaches 0.736 while a
   documented one drops to 0.694. English separates cleanly between 0.724 and 0.750 — a per-language
   floor would work there, which is noted below rather than built.

**Chosen: `MIN_SIMILARITY = "0.6"`**, in `wrangler.toml` so it is version-controlled and ships with
ticket 01's deploy. Deliberately modest: 0.09 below the lowest documented question measured, and
above the genuinely unrelated tail. The reasoning is asymmetric, not statistical — the calibration
questions are *well phrased*, real ones are worse and will score lower, and of the two mistakes only
one is invisible. A floor too high gags a documented question and reads exactly like missing
documentation; too low simply leaves the work to the model judging the excerpts, which #966 built and
which demonstrably works.

**One caveat on the method, worth knowing before anyone raises the number.** The French overlap is
driven by questions that *name the product* — "Peut-on utiliser VEAF MCT sur une console Xbox ?"
scores 0.736. That one is arguably a question the documentation *should* answer, so counting it as
undocumented is debatable. Treat the overlap as a soft edge, not a hard one.

### Open, and not built {#open}

- **A per-language floor** (`MIN_SIMILARITY_EN`) would work: English separates where French does not.
  It is a change to production code for a gain in one language, so it is proposed rather than done.
- **The question set is the measurement.** A floor is only as good as the questions it was measured
  against; `scripts/calibration-questions.json` says so and asks to be added to rather than replaced.
  Re-running the workflow after a documentation change costs about 48 embeddings.

## Definition of done

- [x] 01 — a push to `develop` touching the Worker deploys it, after its tests
- [x] 02 — the floor is measured against the **live** index, with the numbers recorded here
- [x] 02 — the chosen value is version-controlled rather than set in a dashboard
- [x] Worker unit tests, `docs-check` and the Python suite green

---

## Tickets, in full

## 01 — The Worker deploys itself

Status: ✅ done

Type: feat · Files: `.github/workflows/chatbot-worker.yml`

### What it is

A push to `develop` that touches `poc/doc-chatbot/worker/**` deploys the Worker, after its unit
tests pass. Today the workflow gates the code and stops there, which is how #966 sat in the
repository, merged and green, while production ran the previous version.

### How

Extend the existing workflow rather than adding a second one: the tests are the gate the deploy
must wait on, and splitting them across two workflows means re-running the install to deploy.

- `deploy` job, `needs: worker-tests`, `if: github.ref == 'refs/heads/develop' && github.event_name == 'push'`
- `npx wrangler deploy`, with `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID`
- a `concurrency` group so two pushes cannot race a deploy

### The permission this needs, and what happens without it

The token is known to hold **KV edit**. **Workers Scripts edit** is a different permission and
nothing has needed it before. If it is missing the job fails on the deploy — which is right, and is
David's to widen; do not work around it.

### Do not repeat the index mistake

`wrangler deploy` has no local mode, so the silent no-op that cost six weeks is not available here.
A smoke probe after the deploy is still worth it: `POST /nope` must answer 404 and `POST /analyze`
403, which proves the Worker answers and routes. Say in the comment that this proves the Worker is
up, **not** which version it is — an honest narrow check beats a broad claim.

### Definition of done

- [x] A push to `develop` touching the Worker deploys it, after the tests
- [x] Nothing deploys from a pull request, or from any other branch
- [x] A smoke probe runs after the deploy, and its comment does not overstate what it proves
- [x] The hand-deploy instructions in `poc/doc-chatbot/README.md` say CI now does it

---

## 02 — Put a measured number under the floor

Status: ✅ done

Type: feat · Files: `poc/doc-chatbot/worker/scripts/calibrate-floor.mjs`, its questions file,
`.github/workflows/docs-chatbot-index.yml` (or its own), `wrangler.toml`

### What it is

`DEFAULT_MIN_SIMILARITY = 0.35` ships with a comment saying it is a guard against the plainly
unrelated, **not a measured value**. #966 deferred the measurement because it needs the Gemini key.
It also, without saying so, needed a *current* index — until #968 the live one was six weeks stale,
so any calibration would have measured noise.

The method #966 asked for: ask a dozen questions the documentation answers and a dozen it does not,
record the top similarity of each, and set the floor between the two clouds.

### Measure what the Worker measures, not something close to it

Three details, each of which would quietly produce a different number:

- embed the question with task type **`RETRIEVAL_QUERY`** — the index uses `RETRIEVAL_DOCUMENT`,
  and mixing them measures the wrong quantity;
- `gemini-embedding-001`, `outputDimensionality: 768`, exactly as both sides use;
- compare against the vectors **fetched from KV**, not against a fresh local build. The point is the
  index being served, and those two can differ — that is the whole subject of the previous lot.

### Where the number goes

A `[vars]` entry in `wrangler.toml`, so it is version-controlled and ships with ticket 01's deploy,
rather than a dashboard setting that cannot be read from the repository. `minSimilarity(env)` already
parses a string and already refuses anything outside `(0, 1)`.

### Pick the value with the failure costs in mind, not the midpoint

Of the two mistakes, one is much worse: a floor too **high** gags the assistant on questions the
documentation does answer, and looks exactly like missing documentation. Too **low** is a no-op —
the model still judges the excerpts, which is what actually carries #966's fix. So when the clouds
overlap, sit near the bottom of the undocumented cloud rather than halfway.

Record the numbers in the PRD, including the overlap if there is one. If the clouds do not separate,
**say so and keep the default** — a measurement that refuses to produce a number is a result.

### Definition of done

- [x] A script that reproduces the Worker's retrieval scoring, with unit tests on the maths
- [x] At least a dozen questions each way, in both languages, in a file that can be added to
- [x] Run against the **live** index, and the per-question scores recorded in the PRD
- [x] A value chosen and version-controlled, or the default kept with the reason written down

---
