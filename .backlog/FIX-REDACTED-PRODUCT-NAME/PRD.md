# FIX-REDACTED-PRODUCT-NAME — the redactor ate the product's own name

Status: 🔄 in-progress — the two tickets are done; the PR is open

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
| 01 | [The container does not run under the product's name](tickets/01-rename-the-container-user.md) | fix |
| 02 | [A name the product itself uses is not an account name to redact](tickets/02-product-words-are-not-accounts.md) | fix |

## Definition of done

- a report filed from the container says `veaf-tools`, and carries a marker the recovery search finds;
- a reporter whose Windows account is named `veaf` gets an unmangled report;
- the redaction still replaces a real account name, including the 56-survival case that made the
  rule exist;
- tests for both, and the quality gate of both projects.
