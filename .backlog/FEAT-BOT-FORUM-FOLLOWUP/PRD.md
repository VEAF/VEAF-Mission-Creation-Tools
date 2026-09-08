# FEAT-BOT-FORUM-FOLLOWUP — the follow-up of a report belongs in a forum

Status: 🔄 in-progress

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
| 01 | [Open the follow-up as a post in a configured forum](tickets/01-followup-post-in-forum.md) | ✅ |

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
