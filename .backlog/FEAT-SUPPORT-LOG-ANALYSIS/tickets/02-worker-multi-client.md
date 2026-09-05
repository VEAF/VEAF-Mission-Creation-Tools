# 02 — The Worker learns to serve more than one kind of client

Status: ✅ done

Type: fix

## The problem

This lot is the first to add a second kind of client to the Worker, and the Worker's admission
control does not survive it.

**The header is the door.** `isAllowedClient`
([`poc/doc-chatbot/worker/src/index.js:282`](../../../poc/doc-chatbot/worker/src/index.js)) reads:

```js
return cliHeader === "cli" || (!!origin && ALLOWED_ORIGINS.has(origin));
```

Any caller sending `X-VEAF-Client: cli` is admitted, whatever its origin — the browser allow-list is
bypassed entirely. The code documents this as non-secret and leans on the per-IP rate limit instead
([`worker_client.py:24`](../../../src/python/veaf-tools/doc_chatbot/worker_client.py)). **This hole
predates the programme**; it is fixed here because this is the lot that starts relying on client
identity.

**The rate limit fails open.** `allowRequest`
([`src/index.js:98`](../../../poc/doc-chatbot/worker/src/index.js)) counts per IP in KV — 10 per
minute, 100 per day — and its `catch` returns `true`. KV unavailable means no limit at all. The
read-then-write is not atomic and KV is eventually consistent, both acknowledged in comments; every
request without `CF-Connecting-IP` shares one `unknown` counter.

**And it will not survive the bot at all.** [`FEAT-SUPPORT-DISCORD-QA`](../../FEAT-SUPPORT-DISCORD-QA/PRD.md)
puts an entire Discord behind a **single IP**: 100 requests a day for everyone. That lot needs a
`discord` client mode whose quota is carried by the service, per Discord user. The groundwork is
here.

## What changes

- A declared client vocabulary (`web`, `cli`, `logs`, later `discord`) with per-client limits,
  instead of one header that opens everything.
- Admission that does not treat a self-declared header as proof.
- Rate limiting that **fails closed**, or degrades to a stricter local ceiling rather than to none.
- A route, or a mode, for log analysis: the request carries a bounded excerpt and the catalogue
  entries already matched locally, and gets back an explanation.
- A request body ceiling before `request.json()` — there is none today.

## Notes

- The Worker is deployed by hand (`npx wrangler deploy`); the CI workflow only rebuilds the KV
  index. Whatever ships here must be deployable without a pipeline, and say so.
- `poc/doc-chatbot/worker/test/unit.test.mjs` already covers `isAllowedClient`. Those tests move
  with the behaviour rather than being deleted.
- The free Gemini quota is the real ceiling behind all of this; per-client limits must keep the
  documentation widget working when another client misbehaves.

## Definition of done

- [x] Client modes declared, with a limit per mode
- [x] A self-declared header alone no longer grants browser-bypassing access
- [x] Rate limiting fails closed; a KV outage cannot remove the limit
- [x] Body size ceiling enforced before parsing
- [x] A log-analysis mode accepting an excerpt plus matched catalogue entries
- [x] Unit tests extended, including the fail-closed path and the body ceiling
- [x] Deployment steps written down in the Worker README, which is stale and gets refreshed here
