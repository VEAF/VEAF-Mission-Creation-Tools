# VEAF documentation chatbot — POC

A free, doc-guiding chatbot for the VEAF Mission Creation Tools documentation site
(MkDocs Material → GitHub Pages). Modeled on the Solde chatbot, re-shaped for a **static, public,
bilingual** site, using **RAG** (retrieval-augmented generation) so each request stays small —
**with no paid services**: the similarity search runs inside the Worker itself.

## Architecture

```
MkDocs page (static, public)
  └─ widget (doc/assets/chatbot/veaf-chatbot.js) — vanilla JS, auto-injected via mkdocs.yml
       │  detects page language (FR/EN) → POST {messages, lang} (SSE)
       ▼
  Cloudflare Worker (poc/doc-chatbot/worker) — free tier
       │  • declared client vocabulary + per-client rate-limit (KV), Origin allow-list for browsers
       │  • body ceiling enforced before the payload is parsed
       │  • GEMINI_API_KEY held as a Worker Secret (never shipped to the client)
       │  • embeds the question (gemini-embedding-001, 768d)
       │  • ranks the language's doc vectors by cosine similarity IN THE WORKER
       │    (binary Float32 index loaded from KV, L2-normalized → cosine = dot product)
       │  • injects only the top-K passages (~few k tokens) into the prompt
       ▼
  Google Gemini API (free tier, gemini-2.5-flash-lite) → token stream
```

**Why RAG.** Injecting the *whole* doc set (~100k tokens/request) hit the Gemini free-tier
tokens-per-minute ceiling after ~2 questions/minute. RAG retrieves only the handful of relevant
passages per question (~few k tokens), lifting that ceiling to ~50+ questions/minute.

**Why in-Worker cosine (no vector DB).** The corpus is small: 157 pages give 724 French chunks and
671 English ones (measured 2026-09-21). Ranking 724 vectors × 768 dims costs **0.35 ms** of CPU per
request — well under the free-tier 10 ms/request limit — so a managed vector DB (which would need
the paid Workers plan) is unnecessary.

**What the index is, in KV.** Two keys per language: `idx:vec:{lang}`, a binary Float32 blob, and
`idx:txt:{lang}`, a JSON array of the passages **in the same order**. The Worker loads both at once
on a cold isolate (2.12 MB + 1.09 MB for French, and **1.23 ms** to parse the texts, once) and
keeps them cached together, so a question costs no KV read at all. The texts used to be one KV
entry per chunk, fetched six at a time per question; that cost 1397 writes per rebuild against a
cap of 1000 a day — see the quota note below. Loading the two halves together is also what lets the
Worker refuse an index whose vectors and texts disagree on length, instead of answering with a
passage shifted by however many chunks were inserted since.

**Index freshness.** The index is rebuilt by `scripts/build-index.mjs` whenever the docs change;
the CI workflow (`.github/workflows/docs-chatbot-index.yml`) runs it and uploads to KV, so
near-daily doc updates re-index with zero manual effort.

## Prerequisites

- A Cloudflare account (free) and a Google Gemini API key (free tier).
- Node.js + npm (uses `npx wrangler`, no global install needed).

## One-time setup

```bash
cd poc/doc-chatbot/worker
npm install

# KV namespace (rate-limit + embeddings index) — paste the returned IDs into wrangler.toml:
npx wrangler kv namespace create CHAT_KV
npx wrangler kv namespace create CHAT_KV --preview

# Gemini key as a Secret (never committed):
npx wrangler secret put GEMINI_API_KEY
```

## Build & load the index

```bash
# Embeds the local docs and writes vec-{lang}.bin + txt-{lang}.json
# (reads GEMINI_API_KEY from env or .dev.vars). Paced to the free-tier 100 embeds/min, ~minutes.
node scripts/build-index.mjs

# Upload to KV — four keys, and that number does not grow with the documentation:
npx wrangler kv key put --remote --binding CHAT_KV --preview false "idx:vec:fr" --path vec-fr.bin
npx wrangler kv key put --remote --binding CHAT_KV --preview false "idx:vec:en" --path vec-en.bin
npx wrangler kv key put --remote --binding CHAT_KV --preview false "idx:txt:fr" --path txt-fr.json
npx wrangler kv key put --remote --binding CHAT_KV --preview false "idx:txt:en" --path txt-en.json

# Prove it landed — reads the index back out of the namespace and compares it byte for byte:
for lang in fr en; do
  npx wrangler kv key get --remote --binding CHAT_KV --preview false "idx:vec:$lang" > "remote-vec-$lang.bin"
  npx wrangler kv key get --remote --binding CHAT_KV --preview false "idx:txt:$lang" > "remote-txt-$lang.json"
done
node scripts/verify-index-upload.mjs \
  --vec fr vec-fr.bin remote-vec-fr.bin --vec en vec-en.bin remote-vec-en.bin \
  --txt fr txt-fr.json remote-txt-fr.json --txt en txt-en.json remote-txt-en.json
```

Re-run these whenever the documentation changes (this is what the CI workflow automates).

> **`--remote` is load-bearing.** Without it wrangler 4 writes to its local Miniflare store and
> still prints `Success!`. That is how the live index sat frozen from 2026-08-08 to 2026-09-19 while
> every CI run was green — the verification step above exists so it cannot happen again silently.

> **Two free-tier quotas of 1000 a day sit on a rebuild, not one.** Gemini embeddings are guarded
> by the content-addressed cache inside `build-index.mjs`. Cloudflare **KV writes** are guarded by
> the layout: one value per language rather than one per chunk. Until 2026-09-21 the texts were one
> KV entry per chunk — 1397 writes per rebuild, so a single full reindex already exceeded the cap
> and the first doc-touching merge of the day starved every merge after it. The cap is account-wide
> and this namespace also spends two writes per chat request on rate-limit counters, so the budget
> for indexing is 1000 *minus what visitors use*. `build-index.mjs` prints the cost of the upload it
> just prepared, and the CI job puts it in the run summary.

## Deploy the Worker

**CI does this now.** A push to `develop` touching `poc/doc-chatbot/worker/**` runs the unit tests
and, if they pass, deploys — see `.github/workflows/chatbot-worker.yml`. You should not need the
command below.

It is kept for a first deploy, a rollback, or a local account. Note that deploying by hand from a
branch ships *that* branch's code to production:

```bash
npx wrangler deploy
```

> **Why CI does it.** Until 2026-09-19 the Worker was deployed by hand and the workflow only ran the
> tests. A fix merged, green, in the repository could sit undeployed for weeks with nothing saying
> so — which is exactly what happened to #966, while the assistant kept giving the answer that fix
> had removed.

### Replay the answers a defect once shipped on

The deploy workflow's smoke probe proves the Worker answers and routes, and deliberately nothing
more — it never reaches Gemini, so it costs no quota. What it cannot see is the assistant being
*correct and unhelpful*: `scripts/replay-answers.mjs` replays the questions from
`scripts/answer-cases.json` through the live Worker and checks the answers against markers.

```bash
cd poc/doc-chatbot/worker
node scripts/replay-answers.mjs                     # every case
node scripts/replay-answers.mjs --case csar-aircrafttype-fr
```

No secret: it declares the `cli` client mode, which needs none. Three exit codes, because "no case
failed" and "no case was asked" must not look alike: **0** at least one case answered and none
failed, **1** a case failed, **2** nothing could be asked — a spent daily allowance, typically.

It is **not** wired into the deploy workflow on purpose: each case spends one question out of the
free Gemini allowance the whole documentation site and the Discord bot share, and a model's answer
is not deterministic, so a red case means "go and look", never "revert on sight". Run it by hand
after a change to the system instruction, once the deploy has gone through.

Note the deployed URL (e.g. `https://veaf-docs-chatbot.<your-subdomain>.workers.dev`) and set
`PROD_ENDPOINT` in `doc/assets/chatbot/veaf-chatbot-config.js`. That config is environment-aware
(local Worker on `localhost`, production Worker elsewhere) and is already loaded before the widget
in `mkdocs.yml`, so the same committed file works in both.

## Run locally

```bash
# Terminal 1 — Worker. KV (incl. the index) is a networked resource, so use --remote:
cd poc/doc-chatbot/worker
cp .dev.vars.example .dev.vars   # then put your real GEMINI_API_KEY in it
npx wrangler dev --remote --port 8787

# Terminal 2 — docs on http://localhost:8000 :
poetry install --with docs
poetry run mkdocs serve
```

`http://localhost:8000` and `http://127.0.0.1:8000` are on the Worker's Origin allow-list, and the
widget auto-targets the local Worker on localhost.

## Routes and clients

The Worker serves two routes, and every caller belongs to a **declared client mode** (`CLIENTS` in
`worker/src/index.js`). Each mode carries its own quota and its own body ceiling, so one client
misbehaving cannot starve the documentation widget of the shared free Gemini quota.

| Route | Purpose | Payload |
|-------|---------|---------|
| `POST /chat` | Grounded documentation answer (RAG) | `{ lang, messages: [{role, content}] }` |
| `POST /analyze` | Explain a DCS log excerpt | `{ lang, excerpt, matches: [{id, label, help, count}], question? }` |

| Client | Selected by | Routes | Burst / day | Body ceiling |
|--------|-------------|--------|-------------|--------------|
| `web` | an allow-listed `Origin` (the doc widget) | `/chat` | 10 / 60s, 100 / day | 64 KiB |
| `cli` | `X-VEAF-Client: cli`, no `Origin` (`veaf-tools ask`) | `/chat` | 10 / 60s, 60 / day | 64 KiB |
| `logs` | `X-VEAF-Client: logs`, no `Origin` (`veaf-logs`) | `/analyze` | 4 / 60s, 30 / day | 128 KiB |
| `discord` | `X-VEAF-Client: discord` **plus** `X-VEAF-Auth` matching the `DISCORD_CLIENT_SECRET` Secret | both | 5 / 60s, 40 / day **per user** | 64 KiB |

**How admission works, and what it deliberately does not do.** A request carrying an `Origin` is a
browser request: the allow-list decides, and its `X-VEAF-Client` header is ignored outright. Without
an `Origin`, the header *selects* a non-browser mode — it is a routing label, not a credential, and
it buys nothing beyond that mode's own quota. It used to be treated as proof: `X-VEAF-Client: cli`
short-circuited the allow-list entirely, so any caller at all could use the Worker (and VEAF's
Gemini key) from anywhere.

`discord` is groundwork for [`FEAT-SUPPORT-DISCORD-QA`](../../.backlog/FEAT-SUPPORT-DISCORD-QA/PRD.md):
a whole Discord sits behind one IP, so that mode presents a shared Secret and passes its own
per-user `subject` in the payload to carry the quota. While `DISCORD_CLIENT_SECRET` is unset, the
mode is refused — an unconfigured Secret is a closed door, not an open one.

**Rate limiting fails closed.** The KV counters are the normal path; if KV is unavailable the Worker
falls back to a much stricter per-isolate ceiling (`DEGRADED_MAX_PER_WINDOW`). A KV outage degrades
the limit, it never removes it. Callers without a `CF-Connecting-IP` still share one `unknown`
bucket, which is strict rather than lax and is left as is.

## Configuration knobs (worker/src/index.js)

| Constant | Default | Meaning |
|----------|---------|---------|
| `MODEL` | `gemini-2.5-flash-lite` | Gemini generation model (2.0-flash-lite is deprecated) |
| `EMBED_MODEL` / `EMBED_DIMS` | `gemini-embedding-001` / `768` | Embedding model + dims (must match the built index) |
| `TOP_K` | `6` | Passages retrieved per question |
| `CLIENTS` | see the table above | Client vocabulary: routes, quotas, body ceilings |
| `RL_WINDOW` | `60s` | Burst window for every client |
| `DEGRADED_MAX_PER_WINDOW` | `2` | Per-isolate ceiling used when KV is unreachable |
| `MAX_EXCERPT_CHARS` / `MAX_MATCHES` | `40000` / `40` | Log excerpt and catalogue entries kept in an `/analyze` prompt |
| `ALLOWED_ORIGINS` | localhost + veaf.github.io | Browser Origin allow-list |

## Tests

```bash
cd poc/doc-chatbot/worker
npm test          # node --test, no network, no Cloudflare account needed
```

## Deploying a change

The Worker is deployed **by hand** — there is no pipeline for it. The
`.github/workflows/docs-chatbot-index.yml` workflow only rebuilds and uploads the KV index; it never
touches the Worker code. So any change under `worker/src/` reaches production only when someone runs:

```bash
cd poc/doc-chatbot/worker
npm test                        # gate
npx wrangler deploy --dry-run   # bundles without shipping, checks the bindings resolve
npx wrangler deploy             # ships it
```

Nothing under `worker/src/` is live until `npx wrangler deploy` has run — including the user-facing
messages, which are Worker-side strings. A merged pull request changes what the *next* deploy will
ship, not what visitors see today.

Secrets are set once per environment and are not part of a deploy:

```bash
npx wrangler secret put GEMINI_API_KEY
npx wrangler secret put DISCORD_CLIENT_SECRET   # only when the Discord bot lot ships
```

### Tuning the relevance floor — `MIN_SIMILARITY`

Retrieval ranks every indexed passage by cosine similarity and keeps the best ones. Ranking alone
always yields results, however unrelated: on a question the documentation does not cover, the model
used to receive six confident-looking excerpts and answer from them, because nothing told it the
search had failed. `MIN_SIMILARITY` is the cosine floor under which a passage is dropped; when
nothing clears it, the assistant is told the search found nothing and says so instead of answering.

It is a plain Worker variable, not a secret, so it can be tuned without a redeploy of the source:

```bash
npx wrangler secret put MIN_SIMILARITY   # or set it as a var in the Cloudflare dashboard
```

**The shipped default (`0.35`) is a guard against the plainly off-topic, not a measured value.** A
value outside `(0, 1)`, or one that does not parse, falls back to it rather than disabling the floor
(`0`) or gagging the assistant (`1`).

To calibrate it properly you need the Gemini key: ask a dozen questions the documentation *does*
answer and a dozen it does not, record the top similarity of each, and set the floor between the two
clouds. Raise it carefully — a floor set too high is worse than none, since it silences the
assistant on questions it could have answered.

Note that a floor is only half the remedy: a passage can clear any threshold and still not answer the
question, which is why the system instruction also tells the model that the excerpts are search
results that may have missed, and to decline rather than guess.

## State of the POC

- [x] KV namespace created, `GEMINI_API_KEY` set, index built & uploaded.
- [x] Worker deployed to `*.workers.dev`; widget live on the documentation site.
- [x] FR page → streamed FR answer grounded in docs; EN page → streamed EN answer.
- [x] Several questions in quick succession all answer (no TPM ceiling at low traffic).
- [x] Non-allow-listed Origin → 403; over the burst limit → graceful 429 message.
- [x] Automated re-indexing wired in `.github/workflows/docs-chatbot-index.yml` (rebuilds + uploads
      to KV on doc changes). It needs three repository secrets: `GEMINI_API_KEY`,
      `CLOUDFLARE_API_TOKEN` (Workers KV edit), `CLOUDFLARE_ACCOUNT_ID`. Note: the KV free tier
      allows 1,000 writes/day — a full re-index writes ~500 keys, so avoid many rebuilds per day.
- [x] A Gemini 429 maps to a friendly message, and the *daily* allowance is told apart from the
      per-minute burst limit (the free tier is rationed per day and per project, so the site's whole
      audience shares one daily allowance; the two 429s need opposite advice). The widget and
      `veaf-tools ask` both read the Worker's wording out of the response body rather than
      reporting a bare status.
- [x] Unit tests under `worker/test/`, run by `npm test`.
- [x] Declared client modes, admission that ignores a self-declared header for browsers,
      fail-closed rate limiting, body ceiling, `/analyze` log-analysis mode.

## Remaining

- Integrate the widget into the versioned (mike) docs; pick which branch's docs to index.
- Custom Worker domain and observability.
- Per-client counters are read-then-written non-atomically in an eventually consistent KV, so the
  burst limit is approximate under concurrency. Acceptable for an abuse guard; a Durable Object
  would be the fix if it ever needs to be exact.
