# FIX-RELAY-RENDERS-MARKDOWN — a relayed comment shows its markup instead of its formatting

Status: ⬜ ready

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
