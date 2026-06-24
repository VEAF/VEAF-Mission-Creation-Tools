# Lot CHATBOT-CLI — doc chatbot as a `veaf-tools` CLI command + TUI entry

Status: ✅ done

**Goal**: Bring the documentation chatbot (ask a question about the VEAF docs, get a grounded AI answer) to the design-time tooling — a `veaf-tools ask` CLI command (one-shot + interactive REPL with session history) and a TUI menu entry — **reusing the same RAG index built by the docs CI** (single source of truth). The index (`vec-{lang}.bin` + `txt-{lang}.json` from `poc/doc-chatbot/worker/scripts/build-index.mjs`) is published as a public artifact; the Python tool downloads + caches it, then only embeds the question and generates the answer with the *user's own* `GEMINI_API_KEY`. No local re-embedding, no Cloudflare credentials, no extra runtime dependency (`requests` + pure-Python cosine). Approach decided over full-injection (wastes the user's quota at ~100k tokens/question) and over calling the deployed Worker (Origin allow-list 403 + burns the project's quota). Idiomatic to veaf-tools: Typer command in `commands/`, `BaseWorker` pattern, InquirerPy TUI, config via env var / `~/veafmct.yaml`, `veaf_libs.logger`, i18n `t()`, tests in `test/python/`.

**Branch**: `feature/chatbot-cli` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| CHATBOT-CLI-001 | Publish the embeddings index as a public artifact in the docs CI. **Done**: `docs-chatbot-index.yml` now also uploads `vec/txt-{lang}` to a rolling `doc-index` GitHub Release (in addition to the KV upload), so non-Cloudflare clients can fetch it over plain HTTPS. | `.github/workflows/docs-chatbot-index.yml` | feat | ✅ |
| CHATBOT-CLI-002 | `index_store`: download the published `vec-{lang}.bin` + `txt-{lang}.json`, cache under `~/.veaf/doc-index/` with an ETag check, expose load helpers (Float32 vectors + texts); fall back to the cache when offline. | `doc_chatbot/index_store.py`, `test/python/doc_chatbot/test_index_store.py` | feat | ✅ |
| CHATBOT-CLI-003 | `DocChatWorker` (`BaseWorker`): embed the question (`gemini-embedding-001`, 768d, user key) → cosine top-K over the cached index → stream a grounded answer from `gemini-2.5-flash-lite` (SSE via `requests`). Resolve the key from `GEMINI_API_KEY` env or `~/veafmct.yaml`; clear localized error if missing. | `doc_chatbot/doc_chat_worker.py`, `test/python/doc_chatbot/test_doc_chat_worker.py` | feat | ✅ |
| CHATBOT-CLI-004 | `ask` CLI command: one-shot (`veaf-tools ask "…"`) + interactive REPL (session history, `quit`); language from the global `--lang`; rendered via Rich `console`. | `veaf_tools/commands/ask.py`, `veaf_tools/commands/__init__.py`, `veaf_libs/locales/{en,fr}.json` | feat | ✅ |
| CHATBOT-CLI-005 | TUI entry « Ask the documentation » (runs `veaf-tools ask` → its REPL, reusing `DocChatWorker`). | `veaf_libs/tui.py`, `veaf_libs/locales/{en,fr}.json` | feat | ✅ |
| CHATBOT-CLI-006 | Docs (`doc/TOOLS_REFERENCE*.md` + TUI mention), `CHANGELOG`, version bump, and bump the coverage gate (66→67) per the ratchet policy. | `doc/TOOLS_REFERENCE.md`, `doc/TOOLS_REFERENCE.en.md`, `CHANGELOG.md`, `pyproject.toml` | feat | ✅ |

> **Superseded by `CHATBOT-CLI-WORKER`.** David's review: mission makers are not technical enough to obtain a Gemini key, so the CLI must work **with no key by default**. The original "download the index + embed/generate with the user's own key" design (001–003) was reworked to proxy the existing Cloudflare Worker (which already holds the project key server-side). The direct-key path was removed.
