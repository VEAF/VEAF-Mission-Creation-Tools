# FEAT-BOT-FORUM-TAGS — the post the forum actually accepts, and a link to find it

Status: ✅ done — merged 2026-09-08 in #945, after #943 shipped the forum itself.

## Why this lot exists

`FEAT-BOT-FORUM-FOLLOWUP` shipped and was tried in production the same day. The post was refused:

```
"event": "bug.forum_failed", "error": "HTTPException: 400 Bad Request (error code: 40067):
A tag is required to create a forum post in this channel"
```

The VEAF forum has four tags — `issue`, `suggestion`, `question`, `announcement` — and **Tags
requis lorsque les gens postent** is on. The fallback did its job: the follow-up went back to the
`vmct-bot-channel` thread and no report was lost. But the forum is unusable until the bot posts a
tag, and turning the requirement off to accommodate the one tool that cannot honour it would be the
wrong way round — the tagging is what a forum is *for*.

David also asked, in the same breath, for the **summary message to carry a link to the thread**.
That was invisible while the thread hung in the channel the command was used in — it was right
there under the message. Once it lives in a forum, nothing in the reporter's ephemeral answer says
where his report went.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Apply the tag the forum requires](tickets/01-apply-the-required-tag.md) | ✅ |
| 02 | [The summary message links to the follow-up thread](tickets/02-summary-links-to-thread.md) | ✅ |

## Decisions taken before implementing

- **Tags are named, not numbered.** Discord's interface offers no *Copy Tag ID*, so an id would
  have to be read through the API before it could be configured — a name is the only thing a
  deployment can reasonably write down. Resolved case-insensitively against the forum's own
  `available_tags`.
- **Defaults that fit the VEAF forum**: `issue` for `/bug`, `suggestion` for `/suggest`. So the
  production deployment configures nothing at all, and another one overrides two variables.
- **A missing tag is not immediately a fallback.** If the configured name matches nothing, the post
  is attempted **without** a tag — which succeeds on any forum that does not require one — and only
  a refusal falls back to the anchored thread. The log then names the tags the forum does have,
  which is the one line that makes this diagnosable without asking anybody.
- **The thread link is shown whenever a thread was opened**, forum or not. A link to a thread three
  lines below is redundant, not wrong, and one branch fewer is one behaviour fewer to test.

## Out of scope

- Choosing a tag from the report's content (a `question` tag for something that reads like a
  question). The command already says which kind it is; guessing beyond that would have to be
  right far more often than a model can promise.
