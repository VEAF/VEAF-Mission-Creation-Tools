# 04 — Catch production up

Status: 🧑 waiting-human

Type: chore

## The problem

The live index is frozen at the last successful run, 2026-09-21 09:56. The documentation merged in
#975, #977 and #978 — including the new colour table for the spotter view — is not in it, and the
assistant answers as though those pages did not exist.

## What happened on merge (2026-09-21, 20:27 UTC)

The merge triggered both workflows. Measured, not assumed:

- **`Deploy the Worker` succeeded** (run 35651149962). Production runs the new code.
- **`Rebuild docs chatbot index` failed** (run 35651149986), on its **first** write:
  `A request to the Cloudflare API (…/values/idx%3Avec%3Afr) failed — your account has reached the
  free usage limit for this operation for today [code: 10048]`. The day's 1 000 writes were already
  gone: the 09:56 run had spent them under the old per-chunk layout, and five rebuilds had failed
  after it. So `idx:txt:{lang}` does not exist yet, in either language.
- **The live assistant answers anyway**, which is the point of the transition fallback added for
  exactly this case. Asked "Comment déclarer une combat zone dans mission.yaml ?" at 20:31 UTC, it
  returned the real `type: zone` block with `zone_name`, `friendly_name`, `briefing` and
  `training`. Without the fallback this would have been a 502, and every other question with it,
  until midnight UTC.

The answer above still comes from the **old** index, so it is the 09:56 snapshot: #975, #977 and
#978 are still missing from it. That is what remains to do.

## What to do

Once the KV quota resets (00:00 UTC), run `Rebuild docs chatbot index` by hand
(`workflow_dispatch`). With ticket 01 in place the run costs four writes, so a single reset is
enough and no further merge has to wait on it.

Then confirm on the live assistant, not on the workflow's own green: ask it something only the
newly merged pages answer. A green run proves the bytes landed; only an answer proves the bytes are
the right ones.

## Definition of done

- [ ] The workflow run by hand after the quota resets, green, with `Index verified`
- [ ] The printed write cost is 4
- [ ] The live assistant answers a question that only #975/#977/#978 documents
- [ ] Then ticket 06: the transition fallback comes out
