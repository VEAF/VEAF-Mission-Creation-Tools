# 02 — a thread has room for more than 1200 characters

Status: ⬜ ready

**Not asked for.** It is visible in the same screenshot as ticket 01 and it is the same defect the
`FIX-WHAT-THE-READER-SEES` lot already fixed elsewhere, so it is written down rather than lost —
David decides whether to keep it in this lot, move it, or drop it.

## What the screenshot shows

Under the relayed comment: `✂️ Message tronqué — la suite est sur le ticket`. `MAX_COMMENT_CHARS`
is 1200, and the maintainer's answer was longer, so the reporter gets the beginning and a link.

That ceiling exists because a Discord *message* stops at 2000 characters. But the relay writes into
a **thread**, where a second message costs nothing — which is exactly the reasoning
`FIX-WHAT-THE-READER-SEES` applied to `/ask`: *"a thread has room for more than one message […] the
first part replaces the streaming placeholder, the rest are posted after it"*
(`answer.render_messages`). The relay never got that treatment.

The answer being cut is also, in practice, the one that matters most: a maintainer writing 1200+
characters is a maintainer explaining a cause, and the reporter is the person who most needs it.

## Why it is not simply "raise the constant"

* Two independent bounds are in play and only one of them is Discord's. `MAX_RELAYED_PER_ROUND` (5)
  exists so a maintainer pasting a long exchange cannot turn a thread into a wall; splitting one
  long comment into several messages interacts with that budget, and the round's ceiling should
  count *comments*, not messages, or five long answers become a wall by another route.
* Whatever `quote`/rendering becomes in ticket 01 changes where a split may fall: cutting inside a
  fence, or between a `> ` prefix and its line, produces broken output. The split has to be aware
  of the rendering, which is why this ticket sits behind ticket 01 rather than beside it.
* `relay.truncated` stops being the right sentence and `relay.more` may need to say something
  different — both need their French and English forms.

## Tests

* a comment over the ceiling arrives whole, across as many messages as it takes, in order;
* no single message exceeds Discord's limit;
* a split never falls inside a code fence or between a quote prefix and its line;
* the per-round comment budget still counts comments, so one long answer does not consume it.
