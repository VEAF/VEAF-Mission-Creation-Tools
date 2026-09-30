# FEAT-SUPPORT-BOT-DEPLOY — the bot runs somewhere

Status: ✅ done — the code shipped in #926; deployed on the VEAF Docker host 2026-09-07 · archived 2026-09-28

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
| 01 | [The image can refresh its own clone](FEAT-SUPPORT-BOT-DEPLOY.md) | fix |
| 02 | [One command brings it up, and brings it back](FEAT-SUPPORT-BOT-DEPLOY.md) | feat |
| 03 | [A direct run, for the rehearsal](FEAT-SUPPORT-BOT-DEPLOY.md) | feat |
| 04 | [Say where it runs and how to touch it](FEAT-SUPPORT-BOT-DEPLOY.md) | docs |

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

---

## Tickets, in full

## 01 — The image can refresh its own clone

Status: ✅ done — merged in #926

Type: fix

### What to build

`git` in the image, and an entry point that clones the repository into the checkout volume the first
time it starts.

- `apt-get install --no-install-recommends git`, in the same layer as its cache cleanup.
- An entry point that clones **only when the volume holds no `.git`**, then `exec`s the module. A
  container restarted a hundred times clones once.
- A shallow clone (`--depth 1`, single branch): the service reads files, never history. The
  refresh — `git fetch --quiet --prune <remote> <branch>` then `git reset --hard` — works on a
  shallow clone and keeps it shallow.
- The clone URL comes from `VEAF_CLONE_URL`, **outside** the `SUPPORT_BOT_` prefix, defaulting to
  the public repository. That name is deliberate: `.env.example` may only hold `SUPPORT_BOT_*`
  variables the Python reads, and `tests/test_packaging.py` asserts that in both directions. This
  one belongs to the image, not to the service.

### `exec`, not a shell that lingers

The current entry point is exec form on purpose, so `docker stop` sends `SIGTERM` to Python itself
and the clean shutdown runs. A wrapper script must end with `exec python -m veaf_support_bot "$@"`;
without `exec`, the shell keeps PID 1, swallows the signal, and Docker kills the service at ten
seconds — losing whatever was mid-exchange.

### The test that would have caught this

A static check that the Dockerfile installs `git` is worth little; what settles it is asking the
built image:

```bash
docker run --rm --entrypoint git veaf-support-bot:ci --version
```

The `container` CI job builds the image already, so this is one more step there. Add with it a run
that mounts a real clone and asserts the service **publishes** `/bug` — the shape of hole this lot
exists to close is a command silently absent, which every current test tolerates.

### Definition of done

- [x] `git` present in the image, verified by running it in the built image in CI
- [x] Entry point clones once into an empty checkout volume, and never again
- [x] Shallow, single-branch clone; the refresh still works against it — and it names the remote
      `SUPPORT_BOT_CHECKOUT_REMOTE` says, since a clone that always said `origin` made every
      refresh fail on a deployment that overrode it
- [x] `exec` preserved, so `SIGTERM` still reaches Python
- [x] `VEAF_CLONE_URL` documented where the deployment is documented, not in `.env.example`
- [x] Quality gate clean

### What review added to this ticket

Three defects that were **introduced here**, not found here:

- the cleanup that clears a half-written clone deleted the contents of whatever the checkout path
  pointed at. Aimed at `/app/state` — the other writable volume — it would have erased the quota
  counters, the filed-issue ledger and the thread links, silently, on the next start. A directory
  is now only wiped when it *contains* a `.git`; the CI asserts a `/app/state` with a real file in
  it survives;
- the clone had **no timeout**, so a stalled connection would hold PID 1 for ever and `/ask` would
  never start — contradicting the sentence three lines above it in the same file;
- the health grace period was raised to 120 s to cover the clone, which broke the step asserting a
  dry run is called *unhealthy*: with that grace Docker answers `starting` for two minutes and
  `unhealthy` never. The three numbers are tied together, and the Dockerfile now says so.

---

## 02 — One command brings it up, and brings it back

Status: 🧑 waiting-human — written and merged in #926; nobody has run it on the host yet

Type: feat

### What to build

A `compose.yml` beside the service, building from this directory, so the host's whole procedure is
`git pull` then `docker compose up -d --build`.

What it has to declare, and why each line is there:

| Declaration | Why |
|---|---|
| `build: .` | Decided: built on place from git, no registry and no publishing credential |
| `restart: unless-stopped` | The service dies silently otherwise — the process is up, the container says *running*, and nobody gets an answer |
| a volume on `/app/state` | Four files must survive a restart; without it `docker rm` hands everyone a fresh quota and orphans every followed thread |
| a volume on the checkout | So the clone is made once, not on every start |
| `env_file: .env` | The service reads the environment and never a file, which is why the container is the natural home for it |
| the health port | Only if something local watches it; nothing has to reach the service from outside |

`.env` stays out of the image — `tests/test_packaging.py` already asserts it never reaches a layer.

### What this deliberately does not do

No reverse proxy, no exposed port on the internet: nothing calls this service from outside. It calls
Discord, GitHub and the Worker, and answers `/readyz` to whatever runs beside it.

### Definition of done

- [x] `compose.yml` builds and starts the service with state and checkout on named volumes
- [x] The App's private key comes through a compose **secret**, not the environment, so it stays out
      of `docker inspect` — and is ignored by git and excluded from the build context, since the
      documented place for it is a tracked directory
- [ ] `docker compose up -d` on a clean host produces a bot that answers, given a filled `.env`
- [ ] A killed container comes back on its own
- [ ] The state files are still there after `docker compose down && up -d`
- [x] Quality gate clean

The three unchecked boxes need the host. What is written cannot be proven here: Docker is not
installed on the machine this was written on.

**One thing the file cannot do, and says so:** `restart: unless-stopped` acts on *exits*, not on
health. Outside Swarm, Docker marks a container `unhealthy` and leaves it running — so the failure
this service is shaped around, the process alive with the Discord gateway gone, is recovered by
nobody. Watching for it needs an uptime monitor on `/readyz` or a supervisor that recreates
unhealthy containers.

---

## 03 — A direct run, for the rehearsal

Status: ✅ done — merged in #926

Type: feat

### What to build

`scripts/run.ps1`: read the same `.env` the container would, put it in **one process's**
environment, and start the module.

The gap it fills: the service reads its configuration from the environment and never from a file —
its own decision — so the container is started with `--env-file` and a direct run has no equivalent.
The README's instructions set the variables one at a time, which is fine for three variables and
unusable for sixteen.

- Process scope only. Nothing is written to the machine's environment, where every other program
  could read the bot token.
- A malformed line is **named**, not skipped in silence: a missing token reads exactly like a token
  nobody pasted, and the two are debugged differently.
- The exit code is propagated. **78** (`EX_CONFIG`) means this deployment is wrong and restarting
  will not help; anything else non-zero is a crash. Verified 2026-09-07: an incomplete `.env` gives
  78 and lists all five problems at once.
- `-Python` for a host with no Poetry, `-Healthcheck` to probe a running service.

### Why keep it once Docker is the target

Two uses that Docker does not cover. Watching the bot work on a developer machine — Docker is not
installed on DAVID-BUREAU — and the README's own claim that a direct run is a real rehearsal of the
deployment, since it is the same module with the same environment.

### Definition of done

- [x] Reads `.env`, process scope, no interpolation
- [x] Propagates the exit code, 78 included
- [x] Documented where the direct run is documented
- [x] Quality gate clean

### The defect review found in it

**It printed the content of any line it could not parse.** On a file that holds only secrets, that
is the secret: pasting a multi-line PEM — the form `.env.example` documents, so the mistake is the
ordinary one — wrote the key body to stderr, one warning per line, into the log the boot procedure
redirects. Measured in review.

It now reports a line number and nothing else, refuses a `-----BEGIN` line *before* the parse
reaches the key's body, and rejects a name that is not a variable name, since a base64 padding `=`
parses as an assignment and would have created a variable **named** after key material.

---

## 04 — Say where it runs and how to touch it

Status: ✅ done — merged in #926

Type: docs

### What to write

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

### Definition of done

- [x] *Where it runs* answers the question — with the honest answer, which is still **not deployed
      yet**: the section it replaces existed because "how to start it" had been written as if
      somebody already had
- [x] The Docker procedure, end to end, with the two tables of what to paste and what is already
      decided
- [x] Why not the game server, in one paragraph
- [x] What to look at when it does not answer — including that a first start can show `unhealthy`
      while the clone runs, and that a container *looping* is the opposite case: a configuration
      error whose exit code means restarting will not help
- [x] `poetry run docs-check` passes

---
