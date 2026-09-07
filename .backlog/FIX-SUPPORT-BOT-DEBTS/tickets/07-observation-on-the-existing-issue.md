# 07 — Do what the message promised: record the second voice

Status: ⬜ ready

Type: feat

## Where this comes from

Until today `/suggest` spoke the bug flow's prior-art sentences, which say:

> *« Si c'est bien le même problème, ton observation y sera ajoutée plutôt que d'ouvrir un second
> ticket. »*

`/bug` does exactly that — it drafts a comment, asks a second time, and posts it on the existing
issue. `/suggest` opened nothing and commented nothing: the sentence was a promise it did not keep,
and somebody accepting the match would have believed his view recorded when it was dropped.

Found by David on the first real run. **The wording was fixed immediately** — a suggestion now says
plainly that no issue will be opened. This ticket is the other half: doing what the sentence used to
promise, because it is worth doing.

## Why it is worth doing

A suggestion is only wanted or not, and David alone decides. *A second person asking for the same
thing* is the only signal of priority a suggestion will ever carry — and today it is thrown away
entirely: the asker is told the subject is tracked elsewhere, and nothing anywhere records that one
more person needed it.

## What to build

The same shape as the bug flow's duplicate comment, and the same guard:

- the comment is **drafted and shown**, and posted only on a second click. It publishes somebody's
  words on a public tracker; recognising an issue as one's own is not the same act as agreeing to
  publish under it;
- it carries what a maintainer needs and nothing more: the problem as the asker stated it, and who
  asked. Not the whole feature request template — the issue already holds one.

The machinery exists: `IssueFiler.comment_on` and `comment_draft_of`. Both are typed on `BugReport`
and need the same generalisation `file_prepared` got.

## Definition of done

- [ ] An accepted duplicate offers to add the observation, and posts only on the click
- [ ] Every other answer — refusal, silence, expiry — posts nothing
- [ ] The comment names the asker and states his problem, without repeating the template
- [ ] `comment_on` serves both flows through one mechanism
- [ ] Unit tests: accepted and posted, accepted and declined, unanswered
- [ ] Quality gate clean
