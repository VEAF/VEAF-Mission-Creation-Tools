# 02 — Put a measured number under the floor

Status: ✅ done

Type: feat · Files: `poc/doc-chatbot/worker/scripts/calibrate-floor.mjs`, its questions file,
`.github/workflows/docs-chatbot-index.yml` (or its own), `wrangler.toml`

## What it is

`DEFAULT_MIN_SIMILARITY = 0.35` ships with a comment saying it is a guard against the plainly
unrelated, **not a measured value**. #966 deferred the measurement because it needs the Gemini key.
It also, without saying so, needed a *current* index — until #968 the live one was six weeks stale,
so any calibration would have measured noise.

The method #966 asked for: ask a dozen questions the documentation answers and a dozen it does not,
record the top similarity of each, and set the floor between the two clouds.

## Measure what the Worker measures, not something close to it

Three details, each of which would quietly produce a different number:

- embed the question with task type **`RETRIEVAL_QUERY`** — the index uses `RETRIEVAL_DOCUMENT`,
  and mixing them measures the wrong quantity;
- `gemini-embedding-001`, `outputDimensionality: 768`, exactly as both sides use;
- compare against the vectors **fetched from KV**, not against a fresh local build. The point is the
  index being served, and those two can differ — that is the whole subject of the previous lot.

## Where the number goes

A `[vars]` entry in `wrangler.toml`, so it is version-controlled and ships with ticket 01's deploy,
rather than a dashboard setting that cannot be read from the repository. `minSimilarity(env)` already
parses a string and already refuses anything outside `(0, 1)`.

## Pick the value with the failure costs in mind, not the midpoint

Of the two mistakes, one is much worse: a floor too **high** gags the assistant on questions the
documentation does answer, and looks exactly like missing documentation. Too **low** is a no-op —
the model still judges the excerpts, which is what actually carries #966's fix. So when the clouds
overlap, sit near the bottom of the undocumented cloud rather than halfway.

Record the numbers in the PRD, including the overlap if there is one. If the clouds do not separate,
**say so and keep the default** — a measurement that refuses to produce a number is a result.

## Definition of done

- [x] A script that reproduces the Worker's retrieval scoring, with unit tests on the maths
- [x] At least a dozen questions each way, in both languages, in a file that can be added to
- [x] Run against the **live** index, and the per-question scores recorded in the PRD
- [x] A value chosen and version-controlled, or the default kept with the reason written down
