# Setting up the support bot — the steps only a human can do

Everything the support programme needs that **cannot be done from a keyboard by an agent**: creating
accounts, issuing credentials, granting permissions, and deploying. The code is written and tested
without any of it; nothing runs until these are done.

Work through it **in order**. Each part says when it becomes necessary, so nothing is created months
before it is used.

> **Interface labels are those of September 2026.** Discord, GitHub and Anthropic all move their
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
   environment as `DISCORD_BOT_TOKEN`.
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

**Values to hand over:** `DISCORD_BOT_TOKEN`, the application ID, the server (guild) ID, and the
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
5. **Webhook**: needed for the GitHub → Discord relay (lot 4, ticket 06). Two options:
   - the service is reachable from the internet: tick **Active**, set the URL, and generate a
     **webhook secret** — keep it, it goes into the environment as `GITHUB_WEBHOOK_SECRET`;
   - it is not reachable: untick **Active** for now, and the relay polls instead. Tell me which,
     because it changes what gets built.

### B2. Permissions — grant exactly these

Under **Repository permissions**:

| Permission | Level | Why |
|---|---|---|
| Issues | **Read and write** | file issues, comment, read prior art |
| Metadata | Read-only | mandatory, granted automatically |
| Contents | Read-only | read `.backlog/` and the sources for the prior-art sweep |

Everything else stays **No access**. Under **Subscribe to events**, if the webhook is active:
**Issues** and **Issue comment**, nothing else.

**Where can this GitHub App be installed?** → *Only on this account*.

### B3. Issue the credentials

1. Create the app. On the page that follows, note the **App ID**.
2. Scroll to **Private keys** → **Generate a private key**. A `.pem` file downloads. **It is shown
   once**; store it where the service can read it, and nowhere else.
3. Left menu, **Install App** → install it on **VEAF/VEAF-Mission-Creation-Tools** only, not on all
   repositories.
4. After installing, the URL of the installation settings page ends with a number: that is the
   **Installation ID**. Note it.

**Values to hand over:** App ID, Installation ID, the `.pem` private key, and the webhook secret if
you set one.

If anything leaks: same settings page, delete the private key and generate a new one. The app keeps
working under the new key; the old one is dead.

---

## Part C — The Anthropic API key and the budget

**Needed for:** `FEAT-SUPPORT-BUG-INTAKE` (lot 4). This is the only paid part of the programme —
`/ask` and the log analyser run on the free tier.

### C1. Create a scoped key

1. Open <https://console.anthropic.com/>, sign in with an account the association controls.
2. **API keys** → **Create key**. Name it after the service so it can be revoked without collateral.
3. Copy it once, into the environment as `ANTHROPIC_API_KEY`.

### C2. Set a spending limit at the provider, not only in the code

The service enforces its own per-user quota and daily ceiling, but that is our code guarding our
code. Set a hard limit at the provider too, so a bug on our side cannot become an invoice:

1. **Settings** → **Billing** / **Limits**.
2. Set a **monthly spend limit**. It cuts everything off when reached, abruptly — which is exactly
   what you want as a last resort, and why the in-service ceiling exists to be hit first.

### C3. Two figures I need from you

These are decisions, not settings I can pick for you:

- **The monthly budget.** Order of magnitude from the design session: 0.20 to 1 € per report
  analysed. The observed volume of user reports is close to zero — the last one filed by a user
  dates from January 2026 — so the real risk is curiosity on announcement day, not sustained load.
- **The daily ceiling of the service**, which must sit below the provider limit so the bot degrades
  gracefully instead of being cut off mid-sentence.

Tell me both and I wire them in as defaults.

---

## Part D — Deployment

**To be completed** once the service skeleton lands: the runtime, the exact environment variable
list, the container image name and the run commands come from that lot, and inventing them now would
mean rewriting this section.

What is already decided: the service runs **either directly or in a container**, both supported, and
it is deployed **independently of the tools release** — nobody waits for a version to restart the
bot.

What you will need to decide when we get there:

- **Where it runs.** A VEAF machine alongside DCSServerBot, or a separate host. The design session
  weighed both; the code does not care.
- **How it is restarted** when it dies, because it will.
- **Who else can restart it**, so the bot does not stay down for a week when you are away.

---

## Checklist

Copy this into the thread when you have done a part, so I know what to wire in.

- [ ] **A** — Discord application created, bot invited to the server, channels chosen
      → token, application ID, guild ID, channel IDs
- [ ] **B** — GitHub App created, installed on the repository only, permissions as listed
      → App ID, Installation ID, private key, webhook secret or "polling"
- [ ] **C** — Anthropic key created, provider spend limit set
      → key, monthly budget, daily service ceiling
- [ ] **D** — deployment target chosen *(section written once the service skeleton lands)*
