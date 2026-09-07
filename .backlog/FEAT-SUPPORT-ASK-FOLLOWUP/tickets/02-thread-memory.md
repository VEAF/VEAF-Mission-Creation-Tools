# 02 — The thread remembers what it was about

Status: ✅ done — merged in #931

Type: feat

## What

Record, for each thread `/ask` opens: the opening question, and the turns exchanged since. Keep it in
a JSON file on the `state` volume, beside the quota counters, the filed-issue ledger and the relay
links — the same shape as `relay-links.json`, for the same reason: a conversation must survive
`docker compose up -d --build`.

- new setting `SUPPORT_BOT_ASK_THREADS_FILE`, default `state/ask-threads.json`, documented in
  `.env.example` **and** in the README table (both directions are asserted by
  `tests/test_packaging.py`), with `/app/state/ask-threads.json` added to the `Dockerfile`'s defaults;
- the record is trimmed: the Worker keeps `MAX_HISTORY = 12` turns anyway, so storing more is dead
  weight. Old threads are dropped by age, so the file cannot grow for ever on a busy server;
- a file that cannot be read or written **must not** take `/ask` down. A follow-up in a thread the
  service no longer knows is answered with "open a new question with `/ask`", never with silence.

## Why not read the thread back from Discord instead

It looks cheaper — the messages are right there — and it does not work: without the privileged
`MESSAGE_CONTENT` intent, the history the bot fetches comes back with empty `content` for everything
except its own messages. The asker's original question would be readable only because the bot echoed
it, which makes the record the honest source rather than a cache of one.

## Done when

- an answered `/ask` leaves a record; a follow-up finds it and continues the conversation;
- the record survives a restart of the service;
- an unreadable or unwritable file degrades to a clear message, and `/ask` keeps working;
- old records are pruned, and a test proves the file stops growing.
