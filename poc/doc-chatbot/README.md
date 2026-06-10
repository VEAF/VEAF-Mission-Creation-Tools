# VEAF documentation chatbot — POC

A free, doc-guiding chatbot for the VEAF Mission Creation Tools documentation site
(MkDocs Material → GitHub Pages). Modeled on the Solde chatbot, re-shaped for a **static, public,
bilingual** site, using **RAG** (retrieval-augmented generation) so each request stays small.

## Architecture

```
MkDocs page (static, public)
  └─ widget (doc/assets/chatbot/veaf-chatbot.js) — vanilla JS, auto-injected via mkdocs.yml
       │  detects page language (FR/EN) → POST {messages, lang} (SSE)
       ▼
  Cloudflare Worker (poc/doc-chatbot/worker) — free tier
       │  • Origin allow-list (anti-CSRF) + per-IP rate-limit (KV)
       │  • GEMINI_API_KEY held as a Worker Secret (never shipped to the client)
       │  • embeds the question (gemini-embedding-001) → queries Vectorize (topK, filtered by lang)
       │  • injects ONLY the retrieved passages (~few k tokens) into the prompt
       ▼
  Google Gemini API (free tier, gemini-2.5-flash-lite) → token stream
```

**Why RAG.** The site is static (no server to hold the key or throttle abuse), so a free
serverless proxy plays the role the Solde FastAPI backend played. Injecting the *whole* doc set
(~100k tokens/request) hit the Gemini free-tier tokens-per-minute ceiling after ~2 questions/minute.
RAG retrieves only the handful of relevant passages per question (~few k tokens), lifting that
ceiling to ~50+ questions/minute while keeping answers grounded.

**Index freshness.** The embeddings index is rebuilt by `scripts/build-index.mjs` whenever the docs
change. For productionization this step is meant to run automatically in the docs CI (`docs.yml`),
so near-daily doc updates re-index with zero manual effort.

## Prerequisites

- A Cloudflare account (free) and a Google Gemini API key (free tier).
- Node.js + npm (uses `npx wrangler`, no global install needed).

## One-time setup

```bash
cd poc/doc-chatbot/worker
npm install

# 1. KV namespace (per-IP rate-limit) — paste the returned ids into wrangler.toml:
npx wrangler kv namespace create CHAT_KV
npx wrangler kv namespace create CHAT_KV --preview

# 2. Vectorize index (RAG) + a metadata index on `lang` for language filtering:
npx wrangler vectorize create veaf-docs --dimensions=768 --metric=cosine
npx wrangler vectorize create-metadata-index veaf-docs --property-name=lang --type=string

# 3. Gemini key as a Secret (never committed):
npx wrangler secret put GEMINI_API_KEY
```

## Build & load the index

```bash
# Embeds the local docs and writes vectors.ndjson (reads GEMINI_API_KEY from env or .dev.vars):
node scripts/build-index.mjs
# Loads them into Vectorize:
npx wrangler vectorize insert veaf-docs --file vectors.ndjson
```

Re-run these two commands whenever the documentation changes (this is the step to wire into CI for
production).

## Deploy the Worker

```bash
npx wrangler deploy
```

Note the deployed URL, e.g. `https://veaf-docs-chatbot.<your-subdomain>.workers.dev`, then set
`PROD_ENDPOINT` in `doc/assets/chatbot/veaf-chatbot-config.js`:

```js
var PROD_ENDPOINT = "https://veaf-docs-chatbot.<your-subdomain>.workers.dev/chat";
```

That config is environment-aware (local Worker on `localhost`, production Worker elsewhere) and is
already loaded before the widget in `mkdocs.yml`, so the same committed file works in both.

## Run locally

```bash
# Terminal 1 — Worker. Vectorize is a networked resource, so local dev must use --remote:
cd poc/doc-chatbot/worker
cp .dev.vars.example .dev.vars   # then put your real GEMINI_API_KEY in it
npx wrangler dev --remote --port 8787

# Terminal 2 — docs on http://localhost:8000 :
poetry install --with docs
poetry run mkdocs serve
```

`http://localhost:8000` and `http://127.0.0.1:8000` are already on the Worker's Origin allow-list,
and the widget auto-targets the local Worker on localhost.

## Configuration knobs (worker/src/index.js)

| Constant | Default | Meaning |
|----------|---------|---------|
| `MODEL` | `gemini-2.5-flash-lite` | Gemini generation model (2.0-flash-lite is deprecated) |
| `EMBED_MODEL` / `EMBED_DIMS` | `gemini-embedding-001` / `768` | Embedding model + dims (must match the Vectorize index) |
| `TOP_K` | `6` | Passages retrieved per question |
| `RL_MAX_PER_WINDOW` / `RL_WINDOW` | `10` / `60s` | Per-IP burst limit |
| `RL_MAX_PER_DAY` | `100` | Per-IP daily limit |
| `ALLOWED_ORIGINS` | localhost + veaf.github.io | Domain allow-list |

## Definition of Done (POC)

- [ ] KV + Vectorize created, `GEMINI_API_KEY` set, index built & inserted.
- [ ] Worker deployed to `*.workers.dev`; widget visible on local `mkdocs serve`.
- [ ] FR page → streamed FR answer grounded in docs; EN page → streamed EN answer.
- [ ] Several questions in quick succession all answer (no TPM ceiling at low traffic).
- [ ] Non-allow-listed Origin → 403; >10 req/60s → graceful 429 message.

## Gaps for VEAF productionization (out of POC scope)

- **Automated re-indexing is wired** in `.github/workflows/docs-chatbot-index.yml` (rebuilds + upserts
  the index on doc changes). It needs three repository secrets to actually run:
  `GEMINI_API_KEY`, `CLOUDFLARE_API_TOKEN` (Vectorize edit), `CLOUDFLARE_ACCOUNT_ID`.
- **Vectorize in production needs the paid Workers plan ($5/mo);** the free tier covers prototyping
  only. Budget for it before public launch.
- Map a 429 from Gemini to the friendly "too many requests" message (currently generic).
- Integrate the widget into the versioned docs deploy (mike) so all versions get it; pick which
  branch's docs to index (`develop-v6` vs `main`).
- Custom Worker domain, observability, and a global spend/quota cap.
