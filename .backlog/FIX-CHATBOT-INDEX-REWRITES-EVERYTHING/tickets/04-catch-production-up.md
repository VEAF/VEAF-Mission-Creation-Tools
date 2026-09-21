# 04 — Catch production up

Status: 🧑 waiting-human

Type: chore

## The problem

The live index is frozen at the last successful run, 2026-09-21 09:56. The documentation merged in
#975, #977 and #978 — including the new colour table for the spotter view — is not in it, and the
assistant answers as though those pages did not exist.

## What to do

After this lot merges, run `Rebuild docs chatbot index` once by hand (`workflow_dispatch`). With
ticket 01 in place the run costs four KV writes, so it no longer has to wait for the daily quota to
reset at 00:00 UTC — but it does need the quota **not** to be already exhausted by an earlier
attempt on the same day.

Then confirm on the live assistant, not on the workflow's own green: ask it something only the
newly merged pages answer. A green run proves the bytes landed; only an answer proves the bytes are
the right ones.

## Definition of done

- [ ] The workflow run by hand after the merge, green, with `Index verified`
- [ ] The printed write cost is 4
- [ ] The live assistant answers a question that only #975/#977/#978 documents
