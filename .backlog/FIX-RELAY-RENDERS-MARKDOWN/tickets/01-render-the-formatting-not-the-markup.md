# 01 — render the formatting, not the markup

Status: ⬜ ready

`render_comment` wraps the comment body in `untrusted.quote`, a code fence. The reporter therefore
reads the markup. David wants the formatting.

## The options, and what each costs

**a) Drop the fence, send the body after `defuse_mentions`.** Emphasis, inline code, lists and
links render. Cost: Discord's markdown is not GitHub's, so a rich comment renders approximately —
tables have no equivalent at all, and a stray unclosed fence in the comment disturbs the message
around it. The body would also no longer be visibly *somebody else's words*, which is half of what
the current form communicates.

**b) A Discord block quote (`> ` on every line), markdown applied inside it.** Keeps the "this is a
quotation" reading that David's own wording takes for granted — he described them as citations
without complaining about that part — and Discord applies formatting inside a block quote. Two
things to measure rather than assume: a block quote is closed by a line that does not carry `> `,
**blank lines included**, so every line of a multi-line body needs the prefix; and a fenced code
block inside a quote needs checking, since a maintainer pasting a log or a Lua snippet is the
second most likely thing after emphasis. `>>> ` swallows the rest of the message, which does not
fit here — `relay.truncated` comes after the body.

**c) Keep the fence.** The reader keeps losing the formatting on every comment. Worth listing
honestly: it is the only option where nothing has to be re-verified about what a comment can do to
a thread.

**Recommendation: b.** It answers the request without giving up the quotation, and it is the only
one that keeps a visible boundary between the maintainer's words and the bot's own line.

## What must not move

The `/bug` → GitHub direction. `quote` is used by `issue_body.py` and `filing.py` to embed what a
stranger typed into a **public issue**, and there the impersonation guard is the whole point. This
ticket changes what the *relay* does with a comment, not what `quote` does — so either
`render_comment` stops calling it, or `quote` gains an explicit rendering mode and every other
caller keeps today's behaviour by default. The tests holding the fence and
`tests/test_intake_hostile.py` stay green untouched; if one of them goes red, the change has
reached the wrong direction.

## Tests

* a body with `**bold**`, a list and inline code reaches the thread with the markup applied;
* every line of a multi-line body carries the quote prefix, blank lines included, so the quotation
  does not end early;
* a body containing a fenced code block still renders as one thing rather than breaking the message;
* a body containing `@everyone`, `@here` and `<@&roleid>` still cannot ping — asserted on the
  rendered string, not only on `allowed_mentions`, because two independent guards is the point;
* the `/bug` → GitHub callers of `quote` produce byte-identical output to before.
