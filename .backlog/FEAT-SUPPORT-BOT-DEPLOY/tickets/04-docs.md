# 04 — Say where it runs and how to touch it

Status: ⬜ ready

Type: docs

## What to write

The service README's *Where it runs* section currently says **nowhere**, and asks whoever deploys it
to replace that paragraph with the answer. This ticket is that replacement:

- the host, and that it is the VEAF Docker host rather than the game server — **with the reason**,
  because the obvious place is the game server and somebody will suggest it again;
- the procedure, in the order it is done: clone, fill `.env`, `docker compose up -d --build`;
- what to check afterwards: the heartbeat line, `/readyz`, and the fact that `/bug` and `/suggest`
  are only published when the checkout is usable — the failure mode this lot exists for;
- how to update: `git pull`, rebuild, and that a restart costs nothing because everything that has
  to survive is on a volume;
- `VEAF_CLONE_URL`, which belongs to the image and not to `.env.example`.

For the mission makers: **nothing**. `/suggest` and `/bug` are documented on the support page
already; where the process runs is not their business.

## Definition of done

- [ ] *Where it runs* answers the question instead of asking it
- [ ] The Docker procedure, end to end, runnable by somebody who has not read this lot
- [ ] Why not the game server, in one paragraph
- [ ] What to look at when it does not answer
- [ ] `poetry run docs-check` passes if anything under `doc/` moved
