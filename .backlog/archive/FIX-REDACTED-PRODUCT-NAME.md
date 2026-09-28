# FIX-REDACTED-PRODUCT-NAME — the redactor ate the product's own name

Status: ✅ done — the two tickets are done; PR #941 merged 2026-09-07 · archived 2026-09-28

Origin: David, 2026-09-07, reading issue **#940** — the first `/suggest` filed from the Docker
deployment:

> **Que \<user\>-tools.exe propose une UI graphique comme ctld-tools.exe**

`veaf-tools` had become `<user>-tools`. And the first line of the body:

```
<!-- <user>-support-bot:report=24f4efdc3289b9105d22637c7d6c5f5f -->
```

## The cause, and why it appeared tonight

The redactor replaces the current account's name wherever it occurs — a rule measured into
existence: on 1489 real `ERROR` records the name survived **56 times** in `…\Temp\pytest-of-David\…`
after the `C:\Users\<user>` three segments earlier had been redacted.

The container runs as **`veaf`**: `useradd --system --uid 10001 … veaf`, in the image's own
Dockerfile. So `getpass.getuser()` answers `veaf`, and the pattern

```python
re.compile(rf"(?<![<\w]){re.escape(name)}(?![>\w])", re.IGNORECASE)
```

matches `veaf` inside `veaf-tools`: the `-` is not a word character, so the guard against chewing
through longer identifiers does not apply. `veafSpawn.lua` is safe — `S` *is* a word character —
which is why nothing showed until a name with a hyphen was published.

Nothing showed before tonight either, for a simpler reason: until this evening the service ran under
David's own Windows account, whose name resembles nothing in the domain.

## Why it is worse than a cosmetic defect

The **idempotency marker** goes through the same redaction as everything else on its way out — a
deliberate floor, since four leaks reached review by trusting a caller to redact. So the marker is
corrupted too, and `filing.py` searches for `veaf-support-bot:report=`, which no longer exists in
what was filed.

The consequence is that a report filed by this deployment **cannot be recognised again**: a retry, a
double click or a restart opens a second issue, which is the one thing the marker exists to prevent.

## What this is not

Not a reason to loosen the redaction. Every leak this rule catches is somebody's name on a public
tracker, and the 56 survivals measured are the argument for keeping it.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [The container does not run under the product's name](FIX-REDACTED-PRODUCT-NAME.md) | fix |
| 02 | [A name the product itself uses is not an account name to redact](FIX-REDACTED-PRODUCT-NAME.md) | fix |

## Definition of done

- a report filed from the container says `veaf-tools`, and carries a marker the recovery search finds;
- a reporter whose Windows account is named `veaf` gets an unmangled report;
- the redaction still replaces a real account name, including the 56-survival case that made the
  rule exist;
- tests for both, and the quality gate of both projects.

---

## Tickets, in full

## 01 — The container does not run under the product's name

Status: ✅ done

Type: fix

### What to build

The image creates its unprivileged account as `veaf`. Rename it to something the domain never says —
`appuser`. One line of `Dockerfile`, plus the `chown` beside it.

The uid stays **10001**: it is what a deployment `chown`s the GitHub App's private key to, and the
README tells operators to do exactly that. Changing the name is invisible to them; changing the
number would silently make the key unreadable, which is the failure that starts a bot answering
`/ask` and failing every report.

### Why not simply rely on ticket 02

Because they close different holes. Ticket 02 stops the redactor from eating a word the product
uses; this one stops the service from *being named after one*. A deployment that renames its user
back to `veaf` would resurrect the bug through a path ticket 02 cannot see — the account name is
whatever the machine says it is.

And it is the immediate fix: the image is rebuilt on merge, so the deployment is repaired within
minutes without waiting for the tools' own release.

### Done when

- the container's account is `appuser`, uid unchanged at 10001;
- a report filed from it says `veaf-tools`, and its marker is intact;
- the CI's container job still passes, including the step that reads the mounted key.

---

## 02 — A name the product itself uses is not an account name to redact

Status: ✅ done

Type: fix

### What is wrong

`_PLACEHOLDER_WORDS` already refuses to redact `user`, `ip`, `email` and `redacted`: names so
generic that replacing them would shred the text they are meant to protect. `veaf` belongs in that
list for the same reason, in this repository more than anywhere — it is the first word of the tool,
the scripts, the Discord, the bot and half the file names.

This is not hypothetical beyond the container. **A mission maker whose Windows account is named
`veaf`** — on a VEAF server, or on a machine set up for the association — would file a report where
every `veaf-tools` reads `<user>-tools`, and where `doctor`'s own paste block is mangled the same
way.

### What to build

Add the product's own words to the set the account-name rule refuses to act on, and say in the
comment why the list exists: not "generic words", but **words whose replacement costs more than the
name it protects**.

What must not change: the home-directory rule. `C:\Users\veaf\…` is still redacted to
`C:\Users\<user>\…` — that is a *path*, the account name is unambiguous there, and it is the rule
that catches the real leak. Only the bare-literal pass gives way.

That distinction is the whole of the ticket: a name in a path is personal data; the same letters in
`veaf-tools.exe` are the product.

### Done when

- an account named `veaf` leaves `veaf-tools` alone;
- `C:\Users\veaf\Saved Games\…` is still redacted;
- an account named `David` is still replaced everywhere, including the 56-survival case
  (`…\Temp\pytest-of-David\…`) that made the literal pass exist;
- tests for each of the three.

---
