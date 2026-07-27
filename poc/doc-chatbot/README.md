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
       │  • Origin allow-list (anti-CSRF) + per-IP rate-limit (KV)
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

**Why in-Worker cosine (no vector DB).** The corpus is tiny (~500 chunks). Ranking ~260 vectors ×
768 dims is < 1 ms of CPU — well under the free-tier 10 ms/request limit — so a managed vector DB
(which would need the paid Workers plan) is unnecessary. The index lives in KV: a binary Float32
blob per language for the vectors, and one small JSON value per chunk for its text.

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

# Upload to KV:
npx wrangler kv key  put --binding CHAT_KV --preview false "idx:vec:fr" --path vec-fr.bin
npx wrangler kv key  put --binding CHAT_KV --preview false "idx:vec:en" --path vec-en.bin
npx wrangler kv bulk put --binding CHAT_KV --preview false txt-fr.json
npx wrangler kv bulk put --binding CHAT_KV --preview false txt-en.json
```

Re-run these whenever the documentation changes (this is what the CI workflow automates).

## Deploy the Worker

```bash
npx wrangler deploy
```

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

## Configuration knobs (worker/src/index.js)

| Constant | Default | Meaning |
|----------|---------|---------|
| `MODEL` | `gemini-2.5-flash-lite` | Gemini generation model (2.0-flash-lite is deprecated) |
| `EMBED_MODEL` / `EMBED_DIMS` | `gemini-embedding-001` / `768` | Embedding model + dims (must match the built index) |
| `TOP_K` | `6` | Passages retrieved per question |
| `RL_MAX_PER_WINDOW` / `RL_WINDOW` | `10` / `60s` | Per-IP burst limit |
| `RL_MAX_PER_DAY` | `100` | Per-IP daily limit |
| `ALLOWED_ORIGINS` | localhost + veaf.github.io | Domain allow-list |

## Definition of Done (POC)

- [ ] KV namespace created, `GEMINI_API_KEY` set, index built & uploaded.
- [ ] Worker deployed to `*.workers.dev`; widget visible on local `mkdocs serve`.
- [ ] FR page → streamed FR answer grounded in docs; EN page → streamed EN answer.
- [ ] Several questions in quick succession all answer (no TPM ceiling at low traffic).
- [ ] Non-allow-listed Origin → 403; >10 req/60s → graceful 429 message.

## Gaps for VEAF productionization (out of POC scope)

- Create a BACKLOG lot, branch from `develop`, add tests, open a PR.
- **Automated re-indexing is wired** in `.github/workflows/docs-chatbot-index.yml` (rebuilds + uploads
  to KV on doc changes). It needs three repository secrets: `GEMINI_API_KEY`, `CLOUDFLARE_API_TOKEN`
  (Workers KV edit), `CLOUDFLARE_ACCOUNT_ID`. Note: KV free tier allows 1,000 writes/day — a full
  re-index writes ~500 keys, so avoid many rebuilds per day.
- Map a Gemini 429 to the friendly "too many requests" message (currently generic).
- Integrate the widget into the versioned (mike) docs; pick which branch's docs to index.
- Custom Worker domain and observability.
