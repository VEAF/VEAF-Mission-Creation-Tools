# 07 — Re-measure, and ask the assistant the original question

Status: ⬜ ready

Type: chore

## What it is

The lot's own acceptance test. The point was never the page count.

**Re-measure** with the same method as the opening measurement — for each `validate.*` /
`builder.*` key, take the longest literal run of the message (rich markup and `{placeholders}`
removed, 12 characters minimum) and look for it anywhere under `doc/`. Record the new figure in the
PRD next to the old one.

**Then ask the assistant** the question that opened this whole thread: what the coalition message
means and what to do about it. The documentation chatbot retrieves from an index built off `doc/`,
so the pages have to be indexed before the check means anything.

⚠️ Known constraint carried over from `FIX-WHAT-THE-MISSION-MAKER-CAN-ACT-ON`: the Worker is
deployed by hand and the index is rebuilt by hand. If neither can be done from here, say so
explicitly rather than reporting a check that was not run — and record what *was* verified instead.

## Definition of done

- [ ] The new figure measured and written into the PRD
- [ ] The assistant asked the coalition question, with the answer recorded — or the reason it could
      not be asked, with what was verified in its place
