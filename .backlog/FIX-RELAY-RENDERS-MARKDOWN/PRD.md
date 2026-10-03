# FIX-RELAY-RENDERS-MARKDOWN — a relayed comment shows its markup instead of its formatting

Status: 🧑 waiting-human — built 2026-09-29 (option b, and ticket 02 kept in the lot); one reading left in a real thread, see *Left to read*

Origin: David, 2026-09-09, from the live thread of
[#946](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/946) right after the relay was
repaired: *"les messages apparaissent comme des citations, et on voit le source markdown. ça serait
mieux que le markdown soit appliqué (qu'on voie le formatage)"*.

What the reporter reads in his thread is `**Tes SAM n'étaient pas cassés : ils étaient aveugles.**`
— asterisks included, in a monospace block — where the maintainer wrote emphasis. The whole point
of that sentence was that it stood out.

## Where it comes from, and why it is not a mistake

`render_comment` passes the comment body through `untrusted.quote`, which wraps it in a code fence
sized so the content cannot close it. That is a deliberate guard, documented at the top of
`untrusted.py`: *"A report that broke out of its fence would let the reporter write headings and
checklists into an issue that reads as if a maintainer wrote them — which is a real impersonation
problem."*

**But that guard was written for the other direction.** It protects a **GitHub issue** from a
stranger who filled in `/bug`. The relay runs GitHub → Discord, and its authors are the people
commenting on an issue of this repository. In the thread, the quoted body is already introduced by
a line the comment cannot touch — `💬 **<author>** a répondu sur le ticket #N` — so a comment
rendering bold or a list does not read as the bot speaking.

The mention risk is covered twice over and independently of the fence: `thread.send` is called with
`allowed_mentions=NO_MENTIONS`, and `defuse_mentions` rewrites every `@` that could start one.

So this is a real trade-off to decide, not a bug to fix blind: the fence buys a guarantee that is
worth much less in this direction than in the one it was written for, and it costs the reader the
formatting on every single relayed comment.

## Tickets

| # | Ticket | What it is |
|---|--------|------------|
| 01 | [render the formatting, not the markup](tickets/01-render-the-formatting-not-the-markup.md) | the decision, its options and what each costs |
| 02 | [a thread has room for more than 1200 characters](tickets/02-a-thread-has-room-for-more.md) | **not asked for** — surfaced by the same screenshot, David's call whether to keep it |

## Definition of done

* A maintainer's emphasis, lists and inline code reach the reporter as formatting.
* Whatever is decided, the reason the fence was there is written down where the next reader of
  `untrusted.py` will meet it — the two directions have different threat models and that is the
  thing worth not re-deriving.
* `tests/test_intake_hostile.py` and the fence tests keep covering the `/bug` → GitHub direction
  unchanged. Nothing in this lot touches what a stranger can write into an issue.

## Left to read

Two Discord behaviours the unit tests cannot see, to read on the first comment relayed after the
deploy:

* a fenced code block inside the quotation (its fence lines carry the `> ` prefix too) renders as one code block;
* a blank line written as `> ` keeps the quotation going rather than ending it.

If either fails, the fix is in `relay._quoted_parts` only; the `/bug` → GitHub direction is not
involved.

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**a relayed comment shows its markup instead of its formatting**, David 2026-09-09 from the live thread of [#946](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/946): the reporter reads `**Tes SAM n'étaient pas cassés**`, asterisks included, in a monospace block, where the maintainer wrote emphasis — and the whole point of that sentence was that it stood out. `render_comment` passes the body through `untrusted.quote`, a code fence sized so the content cannot close it. That guard is deliberate and documented, but it was written for **the other direction**: it stops a stranger who filled in `/bug` from writing headings and checklists into a **public GitHub issue** that would read as a maintainer's. The relay runs GitHub → Discord, its authors are the people commenting on this repository's issues, and the quoted body is already introduced by a line the comment cannot touch — so rendering emphasis does not let a comment pass for the bot. The mention risk is covered twice and independently of the fence (`allowed_mentions=NO_MENTIONS` **and** `defuse_mentions`). So it is a trade-off to decide, not a bug to fix blind: three options costed in ticket 01, recommendation being a Discord block quote — formatting applied, the quotation kept, which is how David himself described these messages. Ticket 02 is **not asked for** and flagged as such: the same screenshot shows a 1200-character truncation inside a *thread*, where a second message costs nothing — the very reasoning `FIX-WHAT-THE-READER-SEES` applied to `/ask` and that never reached the relay, on precisely the long answers that explain a cause **Built 2026-09-29** (option b and ticket 02, David's choice): a block quote with the formatting applied, long comments split across up to five messages. Left to read on the first relayed comment: a code block inside the quote, and blank lines keeping the quotation
