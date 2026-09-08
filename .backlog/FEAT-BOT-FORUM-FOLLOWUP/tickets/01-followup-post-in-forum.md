# 01 — Open the follow-up as a post in a configured forum

Status: ✅ done
Type: feat

## What it changes

`ModalExchange.open_followup_thread` — the one place `/bug` and `/suggest` open the room a
maintainer's answer comes back into — tries the configured forum first and keeps the anchored
thread as its fallback.

Everything downstream is untouched, and that is the point: a forum post **is** a `discord.Thread`
for the library, so posting the issue's address into it, relaying comments, renaming it `✅ …` on
close and archiving it all keep working with no change at all.

## The pieces

- `SupportBotConfig.discord_forum_channel_id`, from `SUPPORT_BOT_DISCORD_FORUM_CHANNEL_ID`,
  defaulting to `0`.
- `SupportBotClient.followup_forum_id` publishes it. The exchange reads it off the client rather
  than having it threaded through `register_bug_command` → `BugModal` → `ModalExchange` and the
  same three for `/suggest`: it is one deployment-wide setting, and this adapter already reaches
  the client to resolve a thread.
- `ModalExchange._open_forum_post` resolves the channel — `get_channel`, then `fetch_channel`,
  because the bot runs on `Intents.none()` and its channel cache is empty — checks it is a forum,
  and opens the post with the thread's name as both its title and its opening message.
- `FORUMABLE`, named next to `THREADABLE` so a test can stand in front of the branch that tells a
  forum from a text channel.

## Tasks

- [x] Config: field, reader, `redacted()`, `.env.example` (the packaging test enforces that last one).
- [x] The forum path, with every failure returning an empty handle rather than raising.
- [x] The client publishes the id.
- [x] Tests: the post is opened and the channel stays clean; cold cache fetches; warm cache does
      not; and four fallbacks — no forum configured, unreachable, not a forum, refused.
- [x] Test that both ways refused costs the follow-up and nothing else.
- [x] README: how the follow-up is placed, both variable tables, and *Create Posts* in the
      registration steps.

## Acceptance criteria

- [x] With the forum configured, a `/bug` follow-up is a post in it and **no anchor message** is
      left in the channel the command was used in.
- [x] With it unset, the behaviour is byte-for-byte what it was.
- [x] No failure of the forum path can raise past `open_followup_thread`.
- [x] `poetry run pytest` green, coverage gate held; ruff, ruff format and mypy clean.
