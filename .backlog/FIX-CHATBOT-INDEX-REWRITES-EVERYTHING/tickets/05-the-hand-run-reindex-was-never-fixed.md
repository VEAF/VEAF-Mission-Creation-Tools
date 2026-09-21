# 05 — The hand-run reindex never got the `--remote` fix

Status: ✅ done

Type: fix

## The problem

Found on 2026-09-21 while grepping for the last users of the bulk layout. `poetry run
reindex-docs` (`veaf_build/reindex_docs.py`) is a second path that builds and uploads the same
index, and it still read:

```python
base + ["key", "put", *common, "idx:vec:fr", "--path", "vec-fr.bin"],
...
base + ["bulk", "put", *common, "txt-fr.json"],
```

with `common = ["--binding", "CHAT_KV", "--preview", "false"]`. **No `--remote`.**

That is exactly the bug FIX-CHATBOT-INDEX-UPLOADS-LOCALLY closed on 2026-09-19 — wrangler 4 writes
to its local Miniflare store and prints `Success!` — fixed in the workflow and never here. So every
hand-run reindex since the wrangler 4 bump of 2026-08-08 wrote to a folder and reported success,
and nothing read it back. Its test asserted `--binding CHAT_KV` and `--preview false`, which is
what made the omission invisible: the command was checked for the flags someone thought of.

## What to do

- `--remote` on every command, and a test that asserts it on every command rather than on a sample
- `key put` for the texts, matching ticket 01 — a `bulk put` of a plain JSON array is not even the
  right file format any more
- the same read-back-and-compare the workflow does, run after the upload: this path had no
  verification at all, which is why a silent no-op survived a lot dedicated to that exact failure

## Definition of done

- [ ] All four uploads carry `--remote`, asserted per command
- [ ] Texts go up with `key put`; a test refuses `bulk` anywhere in the commands
- [ ] The command reads all four values back and compares them, failing loudly on a miss
