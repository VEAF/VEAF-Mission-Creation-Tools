# FEAT-BOT-FORUM-TAGS — the post the forum actually accepts, and a link to find it

Status: ✅ done — merged 2026-09-08 in #945, after #943 shipped the forum itself. · archived 2026-09-28

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
| 01 | [Apply the tag the forum requires](FEAT-BOT-FORUM-TAGS.md) | ✅ |
| 02 | [The summary message links to the follow-up thread](FEAT-BOT-FORUM-TAGS.md) | ✅ |

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

---

## Tickets, in full

## 01 — Apply the tag the forum requires

Status: ✅ done
Type: feat

### The refusal, as it was actually hit

Production, 2026-09-08, first `/bug` after the forum was configured:

```
"event": "bug.forum_failed", "error": "HTTPException: 400 Bad Request (error code: 40067):
A tag is required to create a forum post in this channel"
```

`ForumChannel.create_thread` takes `applied_tags`; the bot passed none.

### The fix

- `SUPPORT_BOT_FORUM_TAG_BUG` (default `issue`) and `SUPPORT_BOT_FORUM_TAG_SUGGESTION` (default
  `suggestion`), both optional, empty meaning "post with no tag".
- `SupportBotClient` publishes them the way it publishes the forum id — the exchange already knows
  which flow it serves through `_event_prefix` (`bug` / `suggest`), so it can pick its own.
- `_open_forum_post` matches the name against `forum.available_tags`, case-insensitively, and
  passes `applied_tags=[tag]`.

### Decide before implementing

**What happens when the name matches nothing.** Not a fallback: post without a tag, which is what
every forum that does not require one accepts. Only Discord's refusal falls back to the anchored
thread. The warning must name the tags the forum *does* have — that one line is what turns "the
forum does not work" into "the tag is called *bugs*, not *bug*" without anybody reading code.

**Do not fetch the forum twice.** `available_tags` comes off the channel object already resolved;
re-fetching per report would spend a call for nothing.

### Tasks

- [x] Config: two variables, their defaults, `redacted()`, `.env.example`.
- [x] The client publishes them, keyed by flow.
- [x] `_open_forum_post` resolves the name and applies the tag.
- [x] An unmatched name posts without a tag, and says which tags exist.
- [x] Tests: tag applied for `/bug`; the `/suggest` tag is the other one; case-insensitive match;
      unmatched name still posts, with the available names in the log; a forum refusing the
      untagged post falls back to the anchored thread.
- [x] README and `.env.example`: what to configure, and what a forum that requires a tag needs.

### Acceptance criteria

- [x] A `/bug` on a forum with a required tag opens a post tagged `issue`.
- [x] A `/suggest` on the same forum opens one tagged `suggestion`.
- [x] No configuration is needed for the VEAF forum, whose tags already carry those names.
- [x] Nothing about the anchored-thread fallback changes.
- [x] `poetry run pytest` green, coverage gate held; ruff, ruff format, mypy clean.

---

## 02 — The summary message links to the follow-up thread

Status: ✅ done
Type: feat

### Why

The ephemeral message that closes a `/bug` or a `/suggest` says what was filed and links the
**issue**. It never linked the **thread**, because the thread was three lines below it in the same
channel. Now that it is a post in a forum, nothing tells the reporter where his report went.

Asked by David on 2026-09-08, right after the first production try.

### The fix

One extra line at the end of the summary, when a thread was opened — forum or anchored, no branch
between them:

- One shared key, `filed.followup`, in French and English. Two were planned, one per flow; the
  sentence turned out to be the same in both, and a second key would only have been two ways to
  say it that could drift apart.
- Appended in `BugIntake._file` and `SuggestIntake`'s filing step, where `handle` is already in
  scope and already tested for `opened`. Only when an issue exists: a thread whose filing failed
  is told so in the thread itself, and linking to it from the summary would read as success.

The url is `ThreadHandle.url`, which the issue body already carries — nothing new to plumb.

### Tasks

- [x] The text key, both languages.
- [x] `/bug`: appended after the outcome, before the hypothesis note.
- [x] `/suggest`: appended to what `_say` renders.
- [x] Tests: the link is in the summary when a thread was opened; it is absent when none was.

### Acceptance criteria

- [x] Filing a report through `/bug` shows the thread's link in the private answer.
- [x] The same for `/suggest`.
- [x] A report filed with no thread at all shows no dangling label.
- [x] `poetry run pytest` green; ruff, ruff format, mypy clean.

---
