# FEAT-SUPPORT-BOT-DEPLOY — the bot runs somewhere

Status: ✅ done — the code shipped in #926; deployed on the VEAF Docker host 2026-09-07

Origin: decided 2026-09-07 with David. The five lots of the support programme are done and **nothing
runs**: the code is merged, the Worker is deployed, the `filed-by-bot` label exists, and no process
answers a single `/ask`. Until this lot lands, the three commands exist only in the repository.

## Where it runs, and why not on the game server

David's first thought was a Python script started at boot on `dcs.veaf.org` (Windows 11); his second
was the VEAF Docker host, and the second is right:

- **the service has nothing to do on the game machine.** It does not read the DCS log, does not talk
  to the game, needs no local access — only outbound calls to Discord, GitHub and the Worker.
  Putting it there adds a process, a 200 MB clone and a `git fetch` every fifteen minutes to the
  machine that has to hold 60 frames a second;
- **restarting.** Docker has `restart: unless-stopped` and the image already declares its
  `HEALTHCHECK`. A Windows scheduled task starts a process once and does not restart a dead one;
  that would need NSSM on top;
- **the token** does not sit in a file on the desktop of a server several people log into.

**Decided: the Docker host, built on place from git** — the host clones the repository and runs
`docker compose up --build`; updating is `git pull` and a rebuild. No registry, no publishing
credential, and the service lives in the repository it serves.

## The defect this lot has to fix first

**The image cannot run `/bug` or `/suggest` as it stands.** Measured 2026-09-07: it is built on
`python:3.13-slim` and installs three pip packages, so it has **no `git`** — while the service owns
a clone it refreshes itself (`git fetch --prune`, then `git reset --hard`). Without `git`, and
without a clone in the volume, `open_checkout` raises:

```
CheckoutUnavailable: … is not a git working tree (no .git)
```

and both commands are **not published at all**. Only `/ask` answers.

The CI does not catch it: the `container` job builds the image and checks that a misconfigured one
fails loudly (`docker run --rm` with no variables). It never exercises the path that needs a
checkout. An angle nobody looked at, not a regression — and the reason this lot starts with the
image rather than with a `compose.yml`.

## Constraints

- **The entry point stays in exec form.** `docker stop` sends `SIGTERM` straight to the process,
  which is what makes the clean shutdown run; a shell wrapper that forgets `exec` breaks it.
- **The clone is the container's**, created on first start into its own volume, shallow: the service
  reads `doc/`, the sources, `.backlog/`, `ROADMAP.md` and `CHANGELOG.md`, and never the history.
- **`state/` must survive.** Four files: the quota counters, the enrichment allowance, the filed
  issue ledger and the thread ↔ issue links. Losing the last one orphans every thread already
  opened — the issues stay and stop being answered.
- **The image's own variables are not the service's.** `.env.example` may only carry
  `SUPPORT_BOT_*` names that the Python actually reads (`test_packaging.py` asserts both
  directions), so the clone URL the entry point needs is named outside that prefix.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [The image can refresh its own clone](tickets/01-image-can-clone.md) | fix |
| 02 | [One command brings it up, and brings it back](tickets/02-compose.md) | feat |
| 03 | [A direct run, for the rehearsal](tickets/03-direct-run.md) | feat |
| 04 | [Say where it runs and how to touch it](tickets/04-docs.md) | docs |

## The first deployment, 2026-09-07

Up on the VEAF Docker host, built on place from a clone of `develop`. What the container reported
one minute in: `Up (healthy)`, `clone ready` on the checkout volume, `commands synced` with
`["ask", "bug", "suggest"]` on the guild, the gateway connected as *VEAF Tools Bot*, and the App's
private key readable at `/run/secrets/github_app_key`.

Two things the doing taught, both now in the service README:

- **the operator account has no root on that host, and needs none.** The only step that looked like
  it did was restricting the key to the container's `uid 10001`, which is a hardening, not a
  requirement: a `scp` leaves the file at `0644` and the unprivileged user reads it. Where the
  hardening is wanted without root, the daemon itself performs the `chown`;
- **nothing verifies at startup that the key can be read.** An unreadable one gives a bot that
  starts, reports itself healthy, answers `/ask`, and fails on the first report it tries to file —
  so the check belongs in the deployment procedure, run as the service's own user, and it is.

Announced on the Discord with a short French how-to pointing at the documentation's support page.
That link had to go to the `dev` build of the site: the page shipped after 6.19.0 (2026-09-02), so
`latest` does not carry it. **Worth revisiting at the next release** — the announcement should then
point at `latest`.
