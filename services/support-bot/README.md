# VEAF support bot — service

The long-running process behind the documentation assistant on the VEAF Discord.

It answers `/ask` on the VEAF Discord, in a public thread, from the documentation and nothing else.

---

## What it is, and what it is not

| | |
|---|---|
| **Shape** | A long-running service. Not a CLI, not a serverless Worker — the third shape in this repository. |
| **Home** | `services/support-bot/`, its own Python project with its own `pyproject.toml`. |
| **Release** | Deployed **independently** of the tools. Its version (`0.1.0`) is deliberately *not* the `veaf-tools` version, and it is **not** part of the lockstep between `pyproject.toml` and the two agent manifests. Nobody waits for a release to restart the bot. |
| **Dependencies** | One at run time: `discord.py` (which brings `aiohttp`). Everything else is standard library — plus, for `/bug` only, the modules read out of the checkout (see below). |

### What it does **not** do

Stated plainly, because a user who expects one of these will read its absence as a bug:

- **`/ask` does not read the sources.** Its corpus is `doc/`, 1.8 MB of documentation, and nothing
  else. A question whose answer only exists in a `.lua` or a `.py` file has no answer there.
- **`/bug` does not open an issue yet.** It collects, extracts and prepares — the preview and the
  click that files are [ticket 04](../../.backlog/FEAT-SUPPORT-BUG-INTAKE/tickets/04-draft-and-consent.md),
  and the GitHub App that opens it is
  [ticket 05](../../.backlog/FEAT-SUPPORT-BUG-INTAKE/tickets/05-github-app.md).
- **Neither command calls a model to prepare a bug report.** The whole `/bug` path is deterministic
  by design: the free Gemini tier is 20 requests a day, and a report must not depend on one.
- **`/ask` answers from the documentation, so a documentation gap is a wrong or missing answer.**
  The fix is to write the page. There is nothing to retrain, and no way to correct the bot other
  than correcting `doc/`. That is the point: `/ask` failing is a documentation ticket.

---

## How `/bug` works, and why it needs a checkout

`/bug` opens a **form** — five fields and up to three attachments — and turns it into a filled bug
report **without calling any model at all**. Every part of that report is a parse, a lookup or a
search:

| From | Extracted |
|---|---|
| the `doctor` block the reporter pasted | the tool version, the DCS version, the OS — or *"not stated"*, never a guess |
| a stack trace, in the form or in the attached log | the `file:line` it names, mapped onto the checkout |
| that location | the lines around it, and the callers of the function it sits in |
| an attached `dcs.log` | a bounded excerpt through `veaf_logs`, with what `rules.json` recognises, in the catalogue's own wording |
| an attached `.miz` | the mission's *shape* — theatre, date, weather, group counts, zone count — never its briefing or its group names |

Before anything is opened, the report is compared against **four places** — the open issues, the
recently closed ones, `.backlog/` and `ROADMAP.md` — by text matching, with no model involved. Three
of the four outcomes open nothing at all: *already reported* comments on the existing issue,
*already fixed* answers with the version that carries the fix, and *a lot is on it* names the lot. A
match is always **proposed with its evidence** — the reference, the score and the words the two
texts share — and the reporter can say his is different, after which the report is filed as usual. A
wrong "this is a duplicate" silences a real bug and the reporter will not insist, so the sweep
informs the decision and never takes it. With nobody to ask, the answer is *rejected*.

### Nothing is filed before the reporter clicks

What he is then shown is **the issue itself** — the exact title and body that would be created, not
a summary of them — with three buttons:

| Button | What it does |
|---|---|
| **File the issue** | the only path that reaches GitHub |
| **Edit** | reopens the form with his answers still in it, and re-runs the whole pass |
| **Cancel** | nothing is filed, and nothing is kept |

He typed three fields; twenty lines get published, under a machine account that does not carry his
name. The log excerpt, the extracted code and the environment are material he never wrote, so the
click is where he can see the difference and say *not that*.

The **comment** added to an existing issue goes through the same click. Recognising an issue as
his is not the same act as agreeing to publish twenty lines under it, and a comment on a public
tracker carries exactly what an issue carries.

A draft nobody answers **expires** after eight minutes and says so — an abandoned draft must never
turn into an issue later. Both waits, the prior-art proposal and the draft, fit inside the fifteen
minutes Discord keeps an interaction alive, because the last thing the exchange does is write the
outcome onto that same message. And every way this step can fail — a silence, a refusal, Discord
refusing to show the draft at all — leaves the tracker untouched: the irreversible direction is the
one that needs a click.

The preview is bounded to what a Discord message holds, and what it had to leave out is **stated**,
with the count of lines and characters that go into the issue anyway. A fenced block the cut ran
through is closed, so the rest of the message still renders.

An unsatisfying `/ask` answer carries a **Report a bug** button that opens the same form, pre-filled
with the question and the answer. What was expected and the steps stay empty on purpose: the
exchange is the observation, the report is still his to make.

**Everything published is redacted first**, through the same `veaf_libs.redaction` the `doctor`
command uses — the quoted body of a text file, the member names of an attached archive, the file
name the reporter's own machine gave it, the bytes of an attachment carried whole into the issue,
and every field of the form. Each of those **fails closed**: what the helper cannot reach is
described rather than published. What that helper recognises is
personal data by *context* and by *known shape*: a home directory, an address, an IP, a credential.
It deliberately has no rule for a bare account name, so a reporter who types his own name into
*"what happened"*, or uploads `mission by Someone.miz`, publishes it — in a report he is filing
himself, about himself. A `.miz` is not redacted but **summarised**: its published fields are chosen
one by one, which is the stronger guarantee.

And **everything read is data**: no line a reporter or a log wrote ever selects a code path.
`tests/test_intake_hostile.py` holds both halves in place — it assembles the same report twice, once
with instruction-shaped text spliced into every field, and requires identical decisions; and it
carries personal data through every publishing path and requires none of it out the other end.

### The checkout, and how it stays fresh

Turning a trace into `mission_builder/v5_converter.py:412` is only worth doing if the file on disk
is the file the reporter is running, so the service keeps its **own clone** and refreshes it on a
timer (`SUPPORT_BOT_CHECKOUT_*`). Three consequences, all deliberate:

- **The clone must be the service's.** A refresh runs `git fetch` then `git reset --hard`, so
  pointing it at a working copy somebody edits throws that person's work away.
- **A failed refresh is survivable.** The previous revision keeps working; the checkout is marked
  stale and says so.
- **Every location carries the revision it came from** — `at 4f2a1c9ab, refreshed 12 min ago` — so a
  reader can tell whether to trust it. That is what makes staleness harmless rather than misleading.
  A location the revision **contradicts** is not merely labelled, it is called out: a line past the
  end of the file, or a function name the trace claims and the file disagrees with, is reported as
  coming from another build. A published failure names the git command and its exit code and never
  what git printed, which is where the remote's address lives.
- **The refresh, the reduction and the assembly run off the event loop**, in a worker thread, and
  the refresh is serialised: none of that work awaits anything, and a `/bug` that held the loop
  would take `/ask` and the Discord heartbeat down with it.

With no `SUPPORT_BOT_CHECKOUT_PATH`, `/bug` is **not published at all**. A command in the picker
that answers "I cannot do this" is a promise the service does not keep.

### Where the service ends and `veaf-tools` begins

The service is a separate project and its image carries only `veaf_support_bot` and `discord.py`.
`/ask` handled that by generating a checked-in snapshot of the documentation index. `/bug` cannot:
it already needs the repository on disk to read source lines, so the checkout **is** the dependency.

`veaf_support_bot/toolkit.py` is the only door through it. It puts
`<checkout>/src/python/veaf-tools` on `sys.path`, checks that the module it got really came from
that root, and turns any failure into a stated missing section rather than a lost report. Vendoring
a copy instead would create a second source of truth about a tree the service is already reading
live.

---

## How `/ask` works

1. The interaction is **acknowledged within three seconds** — Discord's whole budget — before the
   quota is read or the Worker is called.
2. The acknowledgement becomes the visible **question message** in the channel.
3. A **public thread** is opened on it, and the answer is posted and edited there. Public on
   purpose: the answer serves the next person who asks the same thing, and anyone passing by can
   correct the bot. On a documentation assistant that is the only correction loop that catches a
   wrong answer — no technical guard notices that the documentation changed in 6.19.
4. The answer cites the pages it used, as links. The Worker cannot tell the service which passages
   it retrieved, so the **model** is asked to declare the titles it used and every declared title is
   checked against the real `doc/` tree. A title the corpus does not have is dropped. The bot can
   therefore show *fewer* sources than it used — never one that does not exist.
5. No page cited reads as "the documentation may not cover this", with a route to the support page.
6. The answer carries a **Report a bug** button for an hour, which opens `/bug`'s form pre-filled
   with the exchange. An answer that did not help is where somebody gives up, and it is also where a
   real bug most often surfaces first.

If the bot cannot open a thread — usually a missing **Create Public Threads** permission — it says
so and answers in the channel anyway. Losing the answer would be worse.

**Nothing gets past step 1 without an answer.** Once the interaction is acknowledged, Discord shows
"the bot is thinking" until something edits the response, so every later step runs under one guard:
an upstream failure, a refusal from Discord itself, or a bug of ours all end as a sentence in the
thread. The whole exchange is also bounded — 60 seconds by default — because a deferred interaction
token dies after fifteen minutes, and an answer that arrives after that is an answer nobody sees.

---

## Running it

Both ways run the same module, `python -m veaf_support_bot`, with the same environment. There is no
"container mode" in the code, which is what makes the direct run a real rehearsal of the deployment.

### Configuration

Everything comes from the environment; nothing is read from a file in the repository, and no secret
is committed. Copy [`.env.example`](.env.example) — it documents every variable — to `.env` and fill
it in. That file is ignored by the repository's **root** `.gitignore`, which is where the rule has to
live: the root file ignores every nested `.gitignore`, so one placed here would look right and do
nothing.

Three variables are **required**: `SUPPORT_BOT_DISCORD_TOKEN`, `SUPPORT_BOT_DISCORD_GUILD_ID` and
`SUPPORT_BOT_WORKER_SECRET`. A missing or malformed one stops the process **at startup**, with a
message listing *every* problem at once and exit code **78** (`EX_CONFIG`) — a supervisor can tell
"this deployment is wrong, restarting will not help" from "it crashed, try again".

```text
CRITICAL veaf-support-bot.cli the support bot cannot start: 3 configuration problem(s)
  - SUPPORT_BOT_DISCORD_TOKEN is required but not set
  - SUPPORT_BOT_DISCORD_GUILD_ID is required but not set
  - SUPPORT_BOT_WORKER_SECRET is required but not set
```

#### Every variable

| Variable | Required | Default | What it is |
|---|---|---|---|
| `SUPPORT_BOT_DISCORD_TOKEN` | **yes** | — | The bot token. **Secret.** Anyone holding it *is* the bot. |
| `SUPPORT_BOT_DISCORD_GUILD_ID` | **yes** | — | The one guild served. Commands are published there and nowhere else. |
| `SUPPORT_BOT_WORKER_SECRET` | **yes** | — | **Secret.** Sent as `X-VEAF-Auth`; must equal the Worker's `DISCORD_CLIENT_SECRET`. |
| `SUPPORT_BOT_WORKER_ENDPOINT` | no | the production Worker `/chat` | Override to test against a preview deployment. |
| `SUPPORT_BOT_WORKER_CLIENT` | no | `discord` | Sent as `X-VEAF-Client`; the Worker quotas this mode apart from the CLI and the website. |
| `SUPPORT_BOT_QUOTA_STATE_FILE` | no | `state/quota.json` | Where the per-user counters live. Must be writable **and** must survive a restart. |
| `SUPPORT_BOT_QUOTA_USER_WINDOW_SECONDS` | no | `60` | Length of the per-user burst window. |
| `SUPPORT_BOT_QUOTA_USER_PER_WINDOW` | no | `3` | Questions one user may ask inside that window. |
| `SUPPORT_BOT_QUOTA_USER_PER_DAY` | no | `15` | Questions one user may ask in a UTC day. |
| `SUPPORT_BOT_QUOTA_GLOBAL_PER_DAY` | no | `200` | Questions the **whole bot** may ask in a UTC day. |
| `SUPPORT_BOT_HEALTH_HOST` | no | `127.0.0.1` (`0.0.0.0` in the image) | Interface the health endpoint binds. |
| `SUPPORT_BOT_HEALTH_PORT` | no | `8081` | Port it binds. `0` asks the OS for an ephemeral one, which `--healthcheck` then cannot probe. |
| `SUPPORT_BOT_LOG_LEVEL` | no | `INFO` | `CRITICAL`, `ERROR`, `WARNING`, `INFO` or `DEBUG`. |
| `SUPPORT_BOT_LOG_FORMAT` | no | `json` | `json` for a collector, `text` for a terminal. |
| `SUPPORT_BOT_HEARTBEAT_SECONDS` | no | `60` | Interval between heartbeat log lines. |
| `SUPPORT_BOT_SHUTDOWN_GRACE_SECONDS` | no | `10` | Bounds the **whole** shutdown sequence, not each step. |
| `SUPPORT_BOT_CHECKOUT_PATH` | no | *(unset)* | A clone of this repository, **owned by the service**. Unset means `/bug` is not published at all. |
| `SUPPORT_BOT_CHECKOUT_REMOTE` | no | `origin` | Remote that clone is refreshed from. |
| `SUPPORT_BOT_CHECKOUT_BRANCH` | no | `develop` | Branch it is reset onto. |
| `SUPPORT_BOT_CHECKOUT_REFRESH_SECONDS` | no | `900` | Shortest gap between two refreshes; `0` pins the revision. |
| `SUPPORT_BOT_ATTACHMENT_MAX_BYTES` | no | `26214400` (25 MB) | Largest single file one bug report may carry. |
| `SUPPORT_BOT_ATTACHMENT_TOTAL_BYTES` | no | `62914560` (60 MB) | Largest total across one bug report. |
| `SUPPORT_BOT_GITHUB_APP_ID` | no* | *(unset)* | The GitHub App's id. Unset means `/bug` prepares reports and files nothing. |
| `SUPPORT_BOT_GITHUB_INSTALLATION_ID` | no* | *(unset)* | The App's installation on the one repository it serves. |
| `SUPPORT_BOT_GITHUB_PRIVATE_KEY` | no* | *(unset)* | **Secret.** The App's key, PEM, inline with `\n` escapes. |
| `SUPPORT_BOT_GITHUB_PRIVATE_KEY_FILE` | no* | *(unset)* | **Secret.** The same key as a file. Exactly one of the two. |
| `SUPPORT_BOT_GITHUB_REPOSITORY` | no | `VEAF/VEAF-Mission-Creation-Tools` | Where issues are filed. |
| `SUPPORT_BOT_GITHUB_LEDGER_FILE` | no | `state/filed-issues.json` | What was already filed, so a retry never opens a second issue. Must survive a restart. |
| `SUPPORT_BOT_GITHUB_MACHINE_LABEL` | no | `filed-by-bot` | Label marking an issue as machine-filed. Must already exist in the repository. |
| `SUPPORT_BOT_DRY_RUN` | no | `false` | Start everything except the connection to Discord. |

\* **The four starred rows stand or fall together.** None of them is required, and with none of
them set `/bug` still collects, reads and shows a complete report — it simply says nothing was
opened. Set *any one* of the first three and the service **refuses to start** until the others are
set too: a half-configured App is a bot that takes bug reports for a week and quietly fails to file
every one of them, and that failure belongs at startup (exit `78`) rather than in the first report.

[`.env.example`](.env.example) carries the same list with the reasoning; `tests/test_packaging.py`
fails when the two drift apart, in either direction.

### Registering the Discord application

Once, at <https://discord.com/developers/applications>:

1. **New Application**, then **Bot** → **Reset Token**. That token is `SUPPORT_BOT_DISCORD_TOKEN`.
2. Leave every **Privileged Gateway Intent** off. The bot reads slash-command options and nothing
   else — not message content, not the member list — and `tests/test_discord_adapter.py` asserts it
   never asks for them.
3. **OAuth2 → URL Generator**: scopes `bot` and `applications.commands`; bot permissions **Send
   Messages**, **Create Public Threads** and **Send Messages in Threads**. Invite it to the VEAF
   guild with the generated URL.
   - Without *Create Public Threads* the bot still answers, in the channel, saying why.
   - Without *Send Messages in Threads* it opens a thread it cannot write in. Grant both.
4. Right-click the server → **Copy Server ID** (Developer Mode must be on). That is
   `SUPPORT_BOT_DISCORD_GUILD_ID`. Commands are published to that guild only, so they appear
   immediately instead of taking up to an hour to propagate, and the bot stays un-invitable
   elsewhere.

### Registering the GitHub App

The bot files issues under **its own identity**, not under anybody's account. A personal access
token would be a long-lived credential on the host carrying every right its owner has, whose leak
nobody would notice; reusing an existing one would make the bot's writes indistinguishable from a
maintainer's and impossible to revoke separately.

Once, at <https://github.com/settings/apps/new> (or the organisation's *Settings → Developer
settings → GitHub Apps*):

1. **Name** it something a reader will recognise on an issue — it is the author line every filed
   issue carries. **Homepage URL**: this repository.
2. **Uncheck "Active" under Webhook.** The bot never receives events; it only calls out.
3. **Repository permissions — grant exactly these, and nothing else:**

   | Permission | Level | What it is for |
   |---|---|---|
   | **Issues** | **Read and write** | create the issue, comment on an existing one, apply `bug` and `filed-by-bot`, and list issues for the prior-art sweep |
   | **Metadata** | **Read-only** | mandatory; GitHub selects it automatically and it cannot be removed |

   Leave **every other repository permission at *No access*** — Contents included: the sweep reads
   `.backlog/` and `ROADMAP.md` from the **local checkout**, never through the API, so the App never
   needs to read the code. Leave **every organisation permission** and **every account permission**
   at *No access*, and subscribe to **no events**.
4. **Where can this GitHub App be installed?** → *Only on this account*.
5. **Create GitHub App**, then **Generate a private key**. The `.pem` GitHub downloads is
   `SUPPORT_BOT_GITHUB_PRIVATE_KEY_FILE` (or, pasted with `\n` escapes,
   `SUPPORT_BOT_GITHUB_PRIVATE_KEY` — set one, never both). The **App ID** on that same page is
   `SUPPORT_BOT_GITHUB_APP_ID`.
6. **Install App** → pick **Only select repositories** → `VEAF/VEAF-Mission-Creation-Tools`. The
   number at the end of the resulting settings URL
   (`.../settings/installations/<number>`) is `SUPPORT_BOT_GITHUB_INSTALLATION_ID`.
7. Create the `filed-by-bot` label in the repository. **The bot does not create labels** — inventing
   taxonomy in a public tracker is a maintainer's decision — so without it the issue is filed with
   `bug` alone and says in the thread that the label could not be applied.

What sits on the host afterwards is a private key that **can do nothing on its own**: it signs a
nine-minute JWT, which mints an installation token that expires in an hour and is renewed on the
call that needs it. Revoking the installation ends all of it in one click.

#### What the issue looks like

- **In the reporter's language.** This departs from the repository's English-only rule for technical
  content and matches what the tracker actually contains — the regulars report in French. What the
  reporter typed, what his log said, what his mission is called are **never translated and never
  reworded**: they are quoted verbatim inside a fence they cannot escape.
- **In the shape of `.github/ISSUE_TEMPLATE/bug_report.yml`** — version, component, what happened,
  what was expected, steps, context. The form has been used by **0 of the last 60 issues**; the
  machine fills it every time. `tests/test_issue_body.py` reads the YAML and fails if a label moves.
- **Labelled `bug` and `filed-by-bot`**, so machine-filed issues are findable and countable.
- **Attributed** to the Discord author, with a link back to the thread.
- **No hypothesis.** The body says so in as many words: everything in it is read, parsed or quoted.

#### Filed once, whatever happens twice

| What happens twice | What stops a second issue |
|---|---|
| Two clicks arriving together | a lock per report key — the second waits and reads the first one's result |
| A retry after a timeout | the ledger, which already holds the issue number |
| A restart between the `POST` and the answer, or a ledger that is corrupt, missing or unwritable | a hidden marker inside the issue body; the recovery search runs for every report with no known number, so it needs nothing local to be intact |

The key is derived from the report itself — the reporter, his five fields, the names and sizes of
his attachments — so the same report always produces the same key and a restart can recompute it
from nothing else.

#### The one thing the API cannot do: attach a file

**GitHub has no REST endpoint that attaches a file to an issue.** The one the web interface uses is
a session endpoint, not part of the API, and no App can call it. The alternatives that *are* API
reachable — committing the file to the repository, or publishing it as a release asset — both need
`Contents: write` on a **public** repository and would publish a stranger's log there permanently.

So the service does the honest thing instead:

- a **text** attachment small enough is carried **whole, inside the issue**, as a comment. It lives
  as long as the issue does and is not a link to anything;
- everything else — a `.miz`, a `.zip`, an 11 MB `dcs.log` — is listed in a manifest with its name,
  its size and its SHA-256, and the issue **says plainly that the bytes were not published**. The
  bounded excerpt and the mission's shape are in the body either way.

A Discord attachment URL is **never** written into an issue: those expire within days, and an issue
whose evidence is a dead link is an issue with no evidence.

### The other half: the Worker Secret

`SUPPORT_BOT_WORKER_SECRET` is a **shared** secret. Pick a value, then set it on both sides:

```powershell
cd poc\doc-chatbot\worker
npx wrangler secret put DISCORD_CLIENT_SECRET
```

Until that Secret exists on the Worker, the `discord` client mode is **refused outright** — it is
groundwork, not an open door. The bot then answers every question with "the documentation assistant
is refusing questions from this bot", which says plainly that retrying will not help.

### The quotas, and where to change them

| Ceiling | Default | Why that number |
|---|---|---|
| Per user, per minute | 3 | A burst guard. Below the 5 the Worker grants this mode, so the user meets the bot's message — which names the reset time — rather than the Worker's bare refusal. |
| Per user, per UTC day | 15 | Same reasoning against the Worker's 40. |
| Whole bot, per UTC day | 200 | The **only** bound on total spend: the Worker counts per user and cannot see the bot's total. Every question costs one Gemini embedding call, on a free tier shared with the documentation website and `veaf-tools ask`; the documentation index alone uses about 900 of the 1000 daily embeddings on a day it is rebuilt. |

Change them with the `SUPPORT_BOT_QUOTA_*` variables above. Raise the global one deliberately: it is
what stops a bad day from taking the website's chatbot down with it.

A refused question **says so**, with the reason and when the ceiling lifts, rendered as a Discord
timestamp so every reader sees it in their own timezone. A bot that simply goes quiet is
indistinguishable from a bot that is broken.

The counters are kept in `SUPPORT_BOT_QUOTA_STATE_FILE` so a restart is not a way to get a fresh
allowance. **Mount a volume at `/app/state`** in a container, or the counters die with the container.
When the file cannot be read or written — a corrupt file, a volume that went away, a bind mount the
service cannot write to — it does not carry on with counters nobody keeps: it drops to **2 questions
per minute *and* a tenth of the daily ceiling, for the whole bot** (20 a day at the defaults, capped
by what one user gets in a healthy day, so 15), says so at `ERROR`, and shows `"degraded": true` in
`/status`. Stricter on every axis, never "unlimited".

The daily half of that matters as much as the minute: what puts the service here is a *local* fault
that lasts until somebody notices, not a passing outage. A window ceiling alone would be 2880
questions a day — fourteen times what the healthy path allows, and payable by one person.

### Directly

Examples use PowerShell, the default shell on Windows. On Linux, `export NAME=value` replaces
`$env:NAME = "value"`.

```powershell
cd services\support-bot
poetry install
$env:SUPPORT_BOT_DISCORD_TOKEN = "..."
$env:SUPPORT_BOT_DISCORD_GUILD_ID = "..."
$env:SUPPORT_BOT_WORKER_SECRET = "..."
poetry run python -m veaf_support_bot
```

`poetry run veaf-support-bot` is the same entry point under its installed name. For a readable
terminal run, add `$env:SUPPORT_BOT_LOG_FORMAT = "text"`.

Stop it with `Ctrl+C`: that runs the shutdown sequence below.

### In a container

```powershell
docker build -t veaf-support-bot services\support-bot
docker run -d --name support-bot -p 8081:8081 `
  --env-file services\support-bot\.env `
  -v support-bot-state:/app/state `
  veaf-support-bot
```

The volume is not optional in production: it is where the per-user quota counters live, and without
it `docker rm` hands everyone a fresh allowance. (In `cmd.exe` the line-continuation character is
`^`, not the backtick.)

The image binds the health endpoint on `0.0.0.0` (a container's loopback is unreachable from the
host), runs as an unprivileged user, and declares a Docker `HEALTHCHECK` that calls the service's
own `--healthcheck` probe. `docker stop` sends `SIGTERM` straight to the process — the entry point is
in exec form, with no shell in between — so the clean shutdown actually runs.

---

## Knowing whether it is alive

A self-hosted Discord bot dies silently: the process is up, the container says *running*, and the
only symptom is that nobody gets an answer. The VEAF has no supervision for this, so the service
makes itself checkable two ways.

### The HTTP endpoints

| Route | Meaning | Codes |
|---|---|---|
| `GET /healthz` | **Liveness** — the event loop still turns. Says nothing about readiness, on purpose: a transient un-readiness must not trigger a restart loop. | `200` |
| `GET /readyz` | **Readiness** — the Discord gateway is connected, so a question can actually be answered. What the container health check polls. | `200` / `503` |
| `GET /status` | The full picture, for a human: uptime, readiness, last heartbeat and its age, last error, and the day's quota spend. | `200` |

**Readiness means the gateway is connected**, and nothing weaker. A disconnection withdraws it, a
resumed session restores it, and a connection that ends for good takes the process down rather than
leaving a live container that will never answer again. A **dry run is therefore never ready** — it
answers nobody, and its container shows as *unhealthy*, which is exactly what should happen to one
left on in production.

```powershell
Invoke-RestMethod http://127.0.0.1:8081/status
```

```json
{
  "service": "veaf-support-bot", "version": "0.1.0",
  "ready": true, "not_ready_reason": null, "dry_run": false,
  "started_at": "2026-09-05T09:45:37.038+00:00", "uptime_seconds": 3.111,
  "ready_since": "2026-09-05T09:45:37.042+00:00",
  "last_heartbeat_at": "2026-09-05T09:45:40.072+00:00", "last_heartbeat_age_seconds": 0.077,
  "last_error": null,
  "details": {
    "day": "2026-09-05", "global_count": 12, "global_per_day": 200,
    "tracked_users": 4, "degraded": false, "degraded_reason": null,
    "degraded_count": 0, "degraded_per_day": 15
  }
}
```

`details` is the first thing to look at when the bot starts refusing: `global_count` against
`global_per_day` says whether the day's allowance is spent, and `degraded` says whether the counters
are being kept at all. When it is `true`, read `degraded_count` against `degraded_per_day` instead —
`global_count` stops moving while the counters are not kept, so it alone would show a bot answering
and a spend of zero. No Discord identity appears there — `/status` is an operator interface, not a
record of who asked what.

The endpoint binds `127.0.0.1` by default: it is an operator interface, not a public one. Point an
uptime monitor at `/readyz` through whatever already fronts the host.

### The heartbeat line

Every `SUPPORT_BOT_HEARTBEAT_SECONDS` (60 by default) the service logs
`"event": "service.heartbeat"`. That is what makes a log-based alert — *nothing from the bot for ten
minutes* — possible where nothing polls an endpoint.

### The logs

One JSON object per line on **stdout**, which is where a container supervisor collects them. Every
line carries an `event` key so alerts filter on a field rather than grep prose.

```json
{"ts": "2026-09-05T09:45:37.042+00:00", "level": "INFO", "logger": "veaf-support-bot.service",
 "message": "ready", "event": "service.ready", "health_port": 8081}
```

`SUPPORT_BOT_LOG_FORMAT=text` switches to a readable one-line format for a terminal.

The bot token never appears in a log line or in a traceback: the configuration object redacts it in
both `repr` and the startup line, and a configuration error never echoes the value it refused — only
its shape (`is not an integer (got 47 characters)`). Pasting the token into `SUPPORT_BOT_DISCORD_GUILD_ID`
is an easy first-deployment slip, and that message is printed at `CRITICAL` on stdout, where a log
collector picks it up.

---

## Shutting down

`SIGTERM` (a container restart) or `SIGINT` (`Ctrl+C`) starts a sequence, in this order:

1. readiness drops — a probe sees `503` immediately, before anything is torn down;
2. the heartbeat stops;
3. work already in flight gets `SUPPORT_BOT_SHUTDOWN_GRACE_SECONDS` (10 by default) to finish;
4. anything still running is cancelled, and the log line says how many;
5. the health endpoint closes, and a final `"event": "service.stopped"` line reports the reason,
   the uptime and the number of cancelled tasks.

Step 3 is the point of the whole sequence: an `/ask` exchange is a thread opened, a placeholder
posted and an answer edited in. Killed halfway, it leaves a visibly broken exchange on the server
forever. Every exchange is registered with the drain, and the gateway is closed **after** it — a
closed connection cannot edit a message, so closing first would guarantee the abandoned placeholder
the sequence exists to avoid.

`SUPPORT_BOT_SHUTDOWN_GRACE_SECONDS` bounds the **whole** sequence, not each step: step 5 gets what
step 3 left of it. That matters because `docker stop` kills at ten seconds whatever the service
intends — a shutdown that can add up to twice the configured grace is one whose final line is never
written, and a bot that dies silently is the exact failure this service is built to make visible. A
health connection still open when the budget runs out has its socket cut, and the abort is logged
(`"event": "health.connections_aborted"`) rather than done quietly — that last step can add up to one
more second, for the event loop to collect the aborted sockets, so the true ceiling is the grace plus
a second.

---

## Dry run

`SUPPORT_BOT_DRY_RUN=true` starts every moving part except the connection to the outside world, and
needs no credentials. It is how the container is smoke-tested in CI.

Left on by accident it would be an invisible outage, so it is not quiet: a warning at startup, a
warning on **every** heartbeat, `"dry_run": true` in `/status`, and — since it answers nobody —
`/readyz` returning `503` with `"not_ready_reason": "dry-run"`, which makes the container
*unhealthy*.

---

## Working on it

```powershell
cd services\support-bot
poetry install
poetry run pytest
poetry run ruff check veaf_support_bot tests --fix
poetry run ruff format --check veaf_support_bot tests
poetry run mypy
```

Same tools and the same ruff settings as the rest of the repository; `mypy` is **stricter** here
(`disallow_untyped_defs`), because the package is new and starts clean. The repository-wide
commands in `CLAUDE.md` (`ruff check src/python/ test/python/ veaf_build/`, `mypy
src/python/veaf-tools/`, root `pytest`) do **not** cover this folder — the
[`Support Bot`](../../.github/workflows/support-bot-ci.yml) workflow does, and it also builds the
image and exercises the container.

### After changing a documentation page

The bot links the pages it cites from an index generated out of `doc/` and checked in. Renaming a
page, or changing its first heading, makes that index stale:

```powershell
poetry run python scripts
efresh_doc_pages.py
```

`tests/test_doc_pages.py` rebuilds the index from the real tree and fails when the checked-in copy
has drifted, so forgetting the command is a red test rather than a link that quietly 404s. The
workflow triggers on `doc/**` for that reason.

### The tests that matter most

`tests/test_wiring.py` asserts the **connections**, not the handlers: the command registered, the
callback reaching the handler with the asker and their locale, the exchange tracked so a shutdown
drains it, readiness published by the gateway, the counters built from the configuration and
enforced by the handler that actually runs. Four bugs have shipped green on this repository because
a suite called the handler and never the thing that branches to it.

Its last class cuts each of those wires and asserts the matching test turns red. A wiring test that
cannot fail is the same bug one level up.

### Why Python

The alternative was `discord.js` on Node, which is the better-trodden path for a Discord bot. Python
won on what this repository already has and what the lot needs next: a Worker client
([`worker_client.py`](../../src/python/veaf-tools/doc_chatbot/worker_client.py)) that already speaks
to the same chatbot backend, a logger and an i18n layer, the whole test and quality toolchain
configured, and — decisively — the `.miz` export machinery that lot 4 of the programme will need,
which exists only in Python. A second ecosystem would have bought a nicer Discord library and paid
for it in every other direction.
