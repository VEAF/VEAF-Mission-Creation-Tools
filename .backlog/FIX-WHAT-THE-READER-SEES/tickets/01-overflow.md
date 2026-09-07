# 01 — An answer longer than one message becomes several

Status: ✅ done

Type: fix

## What to build

`answer.render` produces one string bounded at 2000 characters. It gains a sibling that produces a
**list** of them:

- split on line boundaries, never mid-sentence — a cut inside a line reads as corruption;
- a fenced code block the split runs through is **closed** at the end of one part and **reopened**
  at the start of the next, so neither half is rendered as prose;
- the footer — sources, then the caveat — is appended to the **last** part, and its room is reserved
  there before that part is filled;
- a ceiling on the number of parts. Past it, the last part carries the truncation notice that exists
  today: an answer of fifteen messages is not an answer.

`ask.py` then edits the streaming message with the first part and **posts** the others. The exchange
already switches its editing target on `post`, so the escalation button lands on the last message
with no further change.

## Why the streaming is not touched

While the answer arrives, one message is edited at a bounded rate. Posting parts as they stream
would rate-limit the exchange against itself and interleave with whatever else is written in the
thread. The parts are computed once the whole answer is in hand — which is also the only moment the
*last* part is known, and the footer belongs to it.

## Done when

- 3000 characters arrive whole, in two messages, with sources and caveat on the second;
- a code block split across the boundary renders as code on both sides;
- a preposterous answer is bounded and says so;
- nothing changes for an answer that fits, which is most of them.
