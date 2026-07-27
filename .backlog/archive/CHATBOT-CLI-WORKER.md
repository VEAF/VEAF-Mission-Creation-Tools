# Lot CHATBOT-CLI-WORKER — `ask` proxies the Worker (no user key)

Status: ✅ done

**Goal**: Make `veaf-tools ask` work out of the box with **no API key**. A project key cannot be shipped in the distributed tool (it would be scraped and the quota/key abused), so the default routes through the project's Cloudflare Worker — which owns the Gemini key server-side, runs the RAG and streams the answer, exactly like the website chatbot. Supersedes CHATBOT-CLI-001/002/003 (the direct-key + local-index path was removed). David's decisions: **Worker only** (no user-key path) and the CLI authenticates with a **dedicated header** (not by loosening the browser Origin allow-list).

**Branch**: `feat/chatbot-cli-worker` → PR → `develop`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| CHATBOT-CLI-WORKER-001 | Worker: accept non-browser CLI requests via an `X-VEAF-Client: cli` header (`isAllowedClient`), keeping the browser Origin allow-list and the per-IP rate limit. Unit-tested. | `poc/doc-chatbot/worker/src/index.js`, `poc/doc-chatbot/worker/test/unit.test.mjs` | feat | ✅ |
| CHATBOT-CLI-WORKER-002 | Replace the direct-key client with `WorkerChatWorker` (POST `/chat` + `X-VEAF-Client` header, stream the SSE answer); rewire `ask`; remove `index_store`/`doc_chat_worker` and the key handling; revert the GitHub-Release index publish (no longer needed). Docs FR/EN (no key), CHANGELOG, version bump, locales, tests. | `doc_chatbot/worker_client.py`, `veaf_tools/commands/ask.py`, `.github/workflows/docs-chatbot-index.yml`, `doc/TOOLS_REFERENCE*.md`, `test/python/doc_chatbot/test_worker_client.py` | feat | ✅ |
