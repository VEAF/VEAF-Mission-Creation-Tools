# FEAT-BOT-FORUM-FOLLOWUP — the follow-up of a report belongs in a forum

Status: ✅ done — merged 2026-09-08 in #943. The forum id is set on the Docker host's `.env` · archived 2026-09-28
and takes effect at the next `docker compose pull && docker compose up -d`.

## Why this lot exists

David created a **forum channel** on the VEAF Discord for everything that concerns the tools:
bug reports, suggestions, and discussions between humans on the subject. The support bot did not
know about it — a `/bug` or a `/suggest` follow-up was a thread hanging off a public anchor message
posted in whichever channel the command was typed in.

That anchor exists for a technical reason and nothing else: a thread cannot hang off an ephemeral
response, so the bot has to make *something* public to thread off. A forum needs no anchor, and it
gives a follow-up two things the thread never had — a title of its own, and a state visible from the
channel list without opening anything.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Open the follow-up as a post in a configured forum](FEAT-BOT-FORUM-FOLLOWUP.md) | ✅ |

## Decisions taken before implementing

- **`/bug` and `/suggest` move; `/ask` does not.** A question and its answer live for ten minutes
  and would fill the forum with threads nobody reopens. They keep their thread in the channel the
  question was asked in.
- **The forum is a setting, not a rewrite.** `SUPPORT_BOT_DISCORD_FORUM_CHANNEL_ID`, unset by
  default, so any other deployment — and the test suite — keeps the anchored thread.
- **Every failure falls back to the anchored thread.** A wrong id, a channel that is not a forum, a
  missing *Create Posts*, a forum that requires a tag: all of them warn and open the old thread. A
  misconfiguration must never cost a follow-up, and it must never cost the report.

## What the forum being shared with humans does *not* change

The forum holds discussions between people as well as the bot's follow-ups, which raises the
question of whether the bot would answer in a thread it did not open. It does not: `_maybe_followup`
in `discord_bot.py` looks the thread up in the `/ask` memory and returns in silence when it finds
nothing. Verified before implementing, not assumed.

## Out of scope

- Forum **tags** on the posts the bot opens. Worth doing if the forum ever needs bugs told apart
  from suggestions at a glance, but a tag the forum does not have would make Discord refuse the
  post — so it is a lot of its own, with the tag ids as configuration.
- Moving the `/ask` thread, for the reason above.

---

## Tickets, in full

## 01 — Open the follow-up as a post in a configured forum

Status: ✅ done
Type: feat

### What it changes

`ModalExchange.open_followup_thread` — the one place `/bug` and `/suggest` open the room a
maintainer's answer comes back into — tries the configured forum first and keeps the anchored
thread as its fallback.

Everything downstream is untouched, and that is the point: a forum post **is** a `discord.Thread`
for the library, so posting the issue's address into it, relaying comments, renaming it `✅ …` on
close and archiving it all keep working with no change at all.

### The pieces

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

### Tasks

- [x] Config: field, reader, `redacted()`, `.env.example` (the packaging test enforces that last one).
- [x] The forum path, with every failure returning an empty handle rather than raising.
- [x] The client publishes the id.
- [x] Tests: the post is opened and the channel stays clean; cold cache fetches; warm cache does
      not; and four fallbacks — no forum configured, unreachable, not a forum, refused.
- [x] Test that both ways refused costs the follow-up and nothing else.
- [x] README: how the follow-up is placed, both variable tables, and *Create Posts* in the
      registration steps.

### Acceptance criteria

- [x] With the forum configured, a `/bug` follow-up is a post in it and **no anchor message** is
      left in the channel the command was used in.
- [x] With it unset, the behaviour is byte-for-byte what it was.
- [x] No failure of the forum path can raise past `open_followup_thread`.
- [x] `poetry run pytest` green, coverage gate held; ruff, ruff format and mypy clean.

---
