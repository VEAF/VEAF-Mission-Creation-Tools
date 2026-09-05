# 05 — The issue is filed by a GitHub App, not by a person

Status: ⬜ ready

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

- [ ] GitHub App used, with least-privilege scopes documented
- [ ] Credentials from the environment only; renewal handled
- [ ] Issue filled in the template's shape, in the user's language, quotes untranslated
- [ ] Labelled `bug` plus a machine-filed marker
- [ ] Discord author and thread link recorded on the issue
- [ ] Creation idempotent across double click, retry and restart — asserted by tests
- [ ] Creation failure surfaced to the user
- [ ] Quality gate clean
