# 03 — put #946 back in the relay

Status: ⬜ ready

The code fix does not repair the live link: #946's entry is already gone from
`/app/state/relay-links.json`, and nothing recreates it. This is the one-off repair, plus the
procedure written down so the next operator does not have to rediscover it.

## Where the thread id comes from

The thread is not lost: the issue body carries its address, which is what `filing.py` puts there.
On #946 it reads `discord.com/channels/471061487662792715/1546930226301509713` — the first number is
the guild, the second **is** the thread. `channel_id` is the forum channel from the service's own
configuration (`1545700692713537656`); `post_to_thread` never reads it, it is kept so a cold cache
can still resolve the thread after a restart.

## The entry

```json
{
  "issue": 946,
  "channel_id": 1545700692713537656,
  "thread_id": 1546930226301509713,
  "lang": "fr",
  "last_comment_id": 5590879617,
  "closed": true,
  "closed_since": 1788896964.0
}
```

`last_comment_id` is David's comment of 2026-09-08 19:46:32 — the last one the relay actually
carried over before it announced the closure. Everything after it is the backlog, and David asked
for it to reach the thread: ten comments, five a round, so two rounds and a `relay.more` notice
between them.

`closed: true` is deliberate and does the rest of the work. The issue reads `open`, so ticket 01's
reopening branch fires on the first round: the thread is told the issue was reopened, the `✅` comes
off its name, it is un-archived, and only then do the ten comments arrive. Writing `false` here
would leave a thread still named `✅` and archived, quietly filling with messages.

`closed_since` is the real closure moment, 2026-09-08 19:49:24 UTC. It is one day inside the
seven-day window, so the link survives; a stale value here would have the round forget it again on
the spot.

## The procedure

The service rewrites the whole file at every link of every round, and runs as uid 10001, so the edit
happens with the container **stopped** and through a throwaway root container on the same volume —
not `docker cp`, which would leave the file owned by root and unwritable by the service.

1. `docker inspect veaf-support-bot --format '{{range .Mounts}}{{.Name}} {{.Destination}}{{"\n"}}{{end}}'`
   to get the state volume's real name (the Compose project prefixes it).
2. `docker compose stop`
3. Run an `alpine` container with that volume on `/state`, edit `relay-links.json`: add the entry
   above, and remove `938`, `940` and `944` while there — ticket 02 would drop them on its own, but
   the file is open anyway.
4. `chown 10001:10001 /state/relay-links.json` in that same container.
5. `docker compose up -d`, then check the next round: `relay.round` with `reopened: 1`.

## Definition of done

* the thread carries the reopening notice, has lost its `✅` and is un-archived;
* the ten comments have arrived, in order;
* `relay-links.json` holds one entry, `946`;
* the procedure is in `services/support-bot/README.md`, under the relay section.

## Blocked on

David: the state volume lives on the VEAF Docker host, which this session cannot reach. Steps 1–5
are his to run.
