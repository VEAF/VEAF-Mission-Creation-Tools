# Setting up the support bot — the steps only a human can do

Everything the support programme needs that **cannot be done from a keyboard by an agent**: creating
accounts, issuing credentials, granting permissions, and deploying. The code is written and tested
without any of it; nothing runs until these are done.

Work through it **in order**. Each part says when it becomes necessary, so nothing is created months
before it is used.

> **Interface labels are those of September 2026.** Discord, GitHub and Google all move their
> console layouts; if a label below does not exist any more, the step still describes what to look
> for.

> **Never paste a secret into a chat, an issue, a commit or a pull request.** Every value produced
> here goes into the service's environment and nowhere else. If one leaks, revoke it rather than
> hoping — each part says how.

---

## Part A — The Discord application

**Needed for:** `FEAT-SUPPORT-DISCORD-QA` (lot 3), the first lot that talks to users.

### A1. Create the application

1. Open <https://discord.com/developers/applications> and sign in with the account that will own the
   bot. Prefer an account the association controls, not a personal one — ownership is not
   transferable without pain.
2. **New Application**, name it (this name shows up in the member list), accept the terms.
3. In **General Information**, set the description and the icon. Both are visible to users.

### A2. Turn it into a bot and take the token

1. Left menu, **Bot**.
2. Under **Privileged Gateway Intents**: the bot answers slash commands, so it does **not** need
   *Message Content Intent*. Leave the three intents **off** unless the implementation says
   otherwise — an intent you do not need is a permission you must justify later.
3. **Reset Token**, then copy the value. **It is shown once.** Put it straight into the service
   environment as `SUPPORT_BOT_DISCORD_TOKEN`.
4. If it ever leaks: same screen, **Reset Token** — the old one dies immediately.

### A3. Invite it to the VEAF server

1. Left menu, **OAuth2** → **URL Generator**.
2. Scopes: tick **`bot`** and **`applications.commands`**. The second is what allows slash commands;
   without it `/ask` never appears.
3. Bot permissions, the minimum for lot 3:
   - Send Messages
   - Create Public Threads
   - Send Messages in Threads
   - Embed Links
   - Read Message History
   - Attach Files *(needed from lot 4 on, for the files relayed to an issue)*
4. Copy the generated URL, open it, pick the VEAF server, authorise.
5. You need **Manage Server** on the VEAF Discord to do this. If you do not have it, an admin does
   this step with the URL you give them — the URL contains no secret.

### A4. Decide where it lives

Choose the channel or channels where `/ask` is allowed, and tell me which — the service restricts
itself rather than answering everywhere. If a dedicated channel is created for it, its name goes in
the user documentation.

To read a channel's ID: **User Settings** → **Advanced** → turn on **Developer Mode**, then
right-click the channel → **Copy Channel ID**. The same gesture on the server name gives the server
(guild) ID.

**Values to hand over:** the bot token, the application ID, the server (guild) ID, and the
allowed channel IDs.

---

## Part B — The GitHub App

**Needed for:** `FEAT-SUPPORT-BUG-INTAKE` (lot 4), the first lot that writes to the repository.

A GitHub App rather than a personal token: rights scoped to this one repository, short-lived tokens
renewed automatically, revocable in one click, and issues signed by the bot without impersonating
anybody.

### B1. Create it

1. Open <https://github.com/organizations/VEAF/settings/apps> — the **organisation** settings, not
   your personal ones, so the app survives you.
2. **New GitHub App**.
3. **GitHub App name**: what will appear as the author of every issue it files. Choose it carefully,
   it is public and it is what a reporter will see.
4. **Homepage URL**: the repository URL is fine.
5. **Webhook**: leave **Active unticked**. Nothing else to do on this screen.

   *Why, in case you wonder later.* When someone answers an issue on GitHub, the bot has to learn
   about it so it can repost the answer into the Discord thread. There are two ways for it to learn.
   GitHub can **push** the news to the bot the moment it happens — that is the webhook, and it is
   instant, but it requires the bot to have a public address reachable from the internet: a domain
   name, an open port, a certificate. Behind a home router that means real network configuration.
   Or the bot can **ask** GitHub every few minutes what changed — no public address, no open port,
   works anywhere.

   For a bug report, a few minutes of delay changes nothing, so the bot asks. If the service ever
   ends up on a host with a public address and the delay starts to annoy, switching is a small
   change: tick Active, set the URL, generate the secret, and the relay stops polling.

### B2. Permissions — grant exactly these

Under **Repository permissions**:

| Permission | Level | Why |
|---|---|---|
| Issues | **Read and write** | file issues, comment, read prior art |
| Metadata | Read-only | mandatory, granted automatically |
| Contents | Read-only | read `.backlog/` and the sources for the prior-art sweep |

Everything else stays **No access**. **Subscribe to events** can be left entirely unticked — those
events are only delivered through a webhook, and we are not using one.

**Where can this GitHub App be installed?** → *Only on this account*.

### B3. Issue the credentials

1. Create the app. On the page that follows, note the **App ID**.
2. Scroll to **Private keys** → **Generate a private key**. A `.pem` file downloads. **It is shown
   once**; store it where the service can read it, and nowhere else.
3. Left menu, **Install App** → install it on **VEAF/VEAF-Mission-Creation-Tools** only, not on all
   repositories.
4. After installing, the URL of the installation settings page ends with a number: that is the
   **Installation ID**. Note it.

**Values to hand over:** App ID, Installation ID, and the `.pem` private key.

If anything leaks: same settings page, delete the private key and generate a new one. The app keeps
working under the new key; the old one is dead.

---

## Part C — The Gemini API key

**Needed for:** `FEAT-SUPPORT-BUG-INTAKE` (lot 4), where an agent reads the sources to place a
hypothesis in the issue it files.

The programme originally put a paid Claude model here, on the reasoning that the rare, high-value
event was worth paying for. That changed on 2026-09-05: the Anthropic API is **not** covered by the
VEAF's Max Non-Profit plan, so it would have been a separate subscription, a payment method and a
recurring justification — for something that will run a handful of times a month. Everything now
runs on Gemini's free tier, which the documentation chatbot has used in production since June.

### C1. Create a key for the service

1. Open <https://aistudio.google.com/apikey>, signed in with an account the association controls.
2. **Create API key**. When it asks which project to attach it to, choose **Create project** and
   name it for the bot — do **not** reuse the project that already carries the Worker's key.

   That is not tidiness. Gemini's free-tier rate limits apply **per project, not per key**, so two
   keys in one project share one quota: a burst of curiosity on `/ask` would eat the allowance the
   website's chatbot needs for the rest of the day. A separate project also means either key can be
   revoked without taking the other down. Daily counters reset at midnight Pacific time, which is
   around 09:00 in Paris all year.
3. Copy the key once, into the service environment.

### C2. Watch the quota rather than a bill

There is no invoice to cap here, so the thing to watch is the **free-tier quota**, which is shared
by everything the association runs on that key. The service enforces its own per-user and daily
ceilings on top, so a burst of curiosity cannot exhaust in an afternoon what the documentation
chatbot needs for the rest of the day.

### C3. The ceiling, and the figure I still need

**50 analyses per day**, all users together, set on 2026-09-05. Beyond that the bot answers "come
back tomorrow" rather than eating the quota the website's chatbot needs.

That number shapes the design rather than just configuring it. The free tier is counted in
**requests per day**, and an agent left to explore a checkout spends ten to twenty of them per
analysis — which would put fifty analyses out of reach on any plausible free-tier figure. So the
service pre-assembles the context itself, with no model involved, and spends **at most three calls**
per analysis on concluding.

**What I still need:** the actual RPD figure for your project. It is on AI Studio's *Rate limits*
page, under the project you just created. If it turns out to be low enough that even three calls
per analysis do not fit fifty a day, the ceiling comes down or the provider question reopens — with
figures, not intuition.

---

## Part D — Deployment

The service skeleton has landed, so this is now real. Two things must happen before the bot can
answer anything, and the first one is easy to forget.

### D1. Deploy the Worker — nothing new is live until you do

The Worker is deployed **by hand**; the CI workflow only rebuilds the search index. So the
hardening that closed the open-proxy hole, and the client modes the bot needs, are merged in the
repository and **not in production**.

```bash
cd poc/doc-chatbot/worker && npx wrangler deploy
```

Until this runs, the live Worker is the old one: any caller sending `X-VEAF-Client: cli` still gets
in, and there is no `discord` mode for the bot to use.

### D2. Set the shared secret between the Worker and the bot

The `discord` client mode is **refused until a secret exists on the Worker side**. Generate a long
random value, keep it, and set it in both places. It is a shared password: any long random string
does, as long as the Worker and the bot hold the same one. To generate one in PowerShell:

```powershell
[Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Max 256 }))
```

Copy that value, then paste it when the next command asks for it:

```bash
cd poc/doc-chatbot/worker && npx wrangler secret put DISCORD_CLIENT_SECRET
```

The same value goes into the service environment, so the bot can present it. It is a secret: it
never goes in the repository, and it is rotated by re-running the command and updating the service.

### D3. Run the service

Both modes run the same module with the same environment, so the documented command is a rehearsal
of the deployment rather than a second code path.

```bash
poetry run python -m veaf_support_bot
```

```bash
docker run -d --name support-bot -p 8081:8081 --env-file services/support-bot/.env veaf-support-bot
```

Copy `services/support-bot/.env.example` to `.env` and fill it. That file is already ignored by git
— checked by a test, not by a comment.

**Required:**

| Variable | What it is |
|---|---|
| `SUPPORT_BOT_DISCORD_TOKEN` | the bot token from part A. Anyone holding it *is* the bot |
| `SUPPORT_BOT_DISCORD_GUILD_ID` | the single server it serves. Right-click the server → Copy Server ID, with Developer Mode on |

**Optional, shown with their defaults:** `SUPPORT_BOT_WORKER_ENDPOINT` (production Worker),
`SUPPORT_BOT_WORKER_CLIENT` (`discord`), `SUPPORT_BOT_HEALTH_HOST` (`127.0.0.1`, the image sets
`0.0.0.0`), `SUPPORT_BOT_HEALTH_PORT` (`8081`), `SUPPORT_BOT_LOG_LEVEL` (`INFO`),
`SUPPORT_BOT_LOG_FORMAT` (`json`), `SUPPORT_BOT_HEARTBEAT_SECONDS` (`60`),
`SUPPORT_BOT_SHUTDOWN_GRACE_SECONDS` (`10`), `SUPPORT_BOT_DRY_RUN` (`false`).

A missing or malformed variable stops the process **at startup**, listing every problem at once and
exiting with code **78**, so a supervisor can tell a wrong deployment from a crash. The token is
never printed, not even when a value is refused.

### D4. Check it is alive

It answers `/healthz`, `/readyz` and `/status` on the health port, writes one heartbeat line per
minute, and the container carries its own health check. Watch for the heartbeat rather than for the
process: a bot that is up and doing nothing looks identical to a working one from the outside, and
that is the failure mode of every self-hosted bot.

`SIGTERM` runs a real shutdown, bounded end to end — a client holding a socket can no longer keep
the process alive past its grace period.

### D5. Three decisions still yours

- **Where it runs.** A VEAF machine alongside DCSServerBot, or a separate host. The code does not
  care; the design session weighed both.
- **How it is restarted** when it dies, because it will.
- **Who else can restart it**, so the bot does not stay down for a week while you are away.

> The `/ask` command and its quotas are being built now; this section gains the variables they
> introduce when that lands.

---

## Checklist

Copy this into the thread when you have done a part, so I know what to wire in.

- [ ] **A** — Discord application created, bot invited to the server, channels chosen
      → token, application ID, guild ID, channel IDs
- [ ] **B** — GitHub App created, installed on the repository only, permissions as listed
      → App ID, Installation ID, private key
- [ ] **C** — Gemini key created in its **own project**, separate from the Worker's
      → key, and the RPD figure shown on AI Studio's Rate limits page
- [ ] **D1** — Worker deployed (`npx wrangler deploy`), without which none of the hardening is live
- [ ] **D2** — shared secret set on the Worker and in the service environment
- [ ] **D3** — service running, `.env` filled from `.env.example`
- [ ] **D5** — host chosen, restart policy decided, a second person able to restart it
