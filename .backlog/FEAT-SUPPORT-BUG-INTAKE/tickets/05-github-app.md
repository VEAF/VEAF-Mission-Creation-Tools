# 05 — The issue is filed by a GitHub App, not by a person

Status: ✅ done

Type: feat

## What to build

A dedicated GitHub App as the bot's identity: rights scoped to this repository and to what it
actually needs, short-lived tokens renewed automatically, revocable in one click, and issues that
appear signed by the bot without impersonating anybody.

The alternatives were weighed and rejected. A personal access token means a long-lived credential
sitting on the host with broader rights than needed, whose leak goes unnoticed. Reusing an existing
token means it can no longer be revoked without breaking something else, and the bot's actions
become indistinguishable from David's.

## What the issue looks like

- Written **in the user's language**. This departs from the repository's English-only rule for
  technical content, and matches what the tracker actually contains — the regulars report in French.
  Quoted material — log lines, error messages, zone names — is never translated.
- Shaped like `.github/ISSUE_TEMPLATE/bug_report.yml`: version, component, what happened, expected,
  steps, context. The form has never been used by a human in 60 issues; the machine can fill it
  every time.
- Labelled `bug`, plus a triage label marking it as machine-filed, so these are findable and
  countable later.
- Attribution to the Discord author, and a link back to the thread — the two halves of
  [ticket 06](06-relay.md)'s bookkeeping.

## Notes

- The App's credentials live in the environment, never in the repository.
- Creation is idempotent per draft: a double click, a retry after a timeout, or a restart mid-flight
  must not produce two issues.
- A failure to create is reported in the thread with what to do, not swallowed.

## Definition of done

- [x] GitHub App used, with least-privilege scopes documented
- [x] Credentials from the environment only; renewal handled
- [x] Issue filled in the template's shape, in the user's language, quotes untranslated
- [x] Labelled `bug` plus a machine-filed marker
- [x] Discord author and thread link recorded on the issue
- [x] Creation idempotent across double click, retry and restart — asserted by tests
- [x] Creation failure surfaced to the user
- [x] Quality gate clean

## The permissions to grant, exactly

Installed on `VEAF/VEAF-Mission-Creation-Tools` **only**, webhook **inactive**, **no** events.

| Scope | Permission | Level |
|---|---|---|
| Repository | **Issues** | **Read and write** |
| Repository | **Metadata** | **Read-only** *(mandatory, selected by GitHub)* |
| Repository | everything else | **No access** |
| Organisation | everything | **No access** |
| Account | everything | **No access** |

`Contents` is deliberately **not** granted: the prior-art sweep reads `.backlog/` and `ROADMAP.md`
from the local checkout, never through the API, so the App never needs to read the code.

## What the ticket asked for and the platform does not allow

**Re-uploading the attachments to the issue.** GitHub has **no REST endpoint that attaches a file to
an issue** — the one the web interface uses is a session endpoint no App can call. The two
API-reachable substitutes (committing the file to the repository, publishing it as a release asset)
both need `Contents: write` on a **public** repository and would permanently publish a stranger's
`dcs.log` into it. Neither was built.

What was built instead: a **text** attachment small enough is carried *whole, inside the issue*, as
a comment — it lives as long as the issue does and is a link to nothing. Everything else is listed
with its name, its size and its SHA-256, and the issue says plainly that the bytes were not
published; the bounded excerpt and the mission's shape are in the body either way. **No Discord URL
is ever written into an issue.**

If David wants the raw files to survive, the options are: a dedicated branch written through
`Contents: write` (permanent, public, and a much broader permission), or asking the reporter for the
file through the ticket 06 relay when a maintainer actually needs it.

## The other thing to decide

The bot **does not create labels**. If `filed-by-bot` does not exist in the repository, the issue is
filed with `bug` alone and the reporter is told the label could not be applied. Letting a machine
invent taxonomy in a public tracker looked like a maintainer's decision rather than the bot's — the
label has to be created by hand, once.
