# 01 — Apply the tag the forum requires

Status: ✅ done
Type: feat

## The refusal, as it was actually hit

Production, 2026-09-08, first `/bug` after the forum was configured:

```
"event": "bug.forum_failed", "error": "HTTPException: 400 Bad Request (error code: 40067):
A tag is required to create a forum post in this channel"
```

`ForumChannel.create_thread` takes `applied_tags`; the bot passed none.

## The fix

- `SUPPORT_BOT_FORUM_TAG_BUG` (default `issue`) and `SUPPORT_BOT_FORUM_TAG_SUGGESTION` (default
  `suggestion`), both optional, empty meaning "post with no tag".
- `SupportBotClient` publishes them the way it publishes the forum id — the exchange already knows
  which flow it serves through `_event_prefix` (`bug` / `suggest`), so it can pick its own.
- `_open_forum_post` matches the name against `forum.available_tags`, case-insensitively, and
  passes `applied_tags=[tag]`.

## Decide before implementing

**What happens when the name matches nothing.** Not a fallback: post without a tag, which is what
every forum that does not require one accepts. Only Discord's refusal falls back to the anchored
thread. The warning must name the tags the forum *does* have — that one line is what turns "the
forum does not work" into "the tag is called *bugs*, not *bug*" without anybody reading code.

**Do not fetch the forum twice.** `available_tags` comes off the channel object already resolved;
re-fetching per report would spend a call for nothing.

## Tasks

- [x] Config: two variables, their defaults, `redacted()`, `.env.example`.
- [x] The client publishes them, keyed by flow.
- [x] `_open_forum_post` resolves the name and applies the tag.
- [x] An unmatched name posts without a tag, and says which tags exist.
- [x] Tests: tag applied for `/bug`; the `/suggest` tag is the other one; case-insensitive match;
      unmatched name still posts, with the available names in the log; a forum refusing the
      untagged post falls back to the anchored thread.
- [x] README and `.env.example`: what to configure, and what a forum that requires a tag needs.

## Acceptance criteria

- [x] A `/bug` on a forum with a required tag opens a post tagged `issue`.
- [x] A `/suggest` on the same forum opens one tagged `suggestion`.
- [x] No configuration is needed for the VEAF forum, whose tags already carry those names.
- [x] Nothing about the anchored-thread fallback changes.
- [x] `poetry run pytest` green, coverage gate held; ruff, ruff format, mypy clean.
