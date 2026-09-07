# 05 — A request already made in other words

Status: ✅ done

Type: feat

## What David said, and why he is right

> *« tu dis "exactement les 3 mêmes champs" mais jamais un humain ne va taper exactement les mêmes
> mots ; il faut analyser le texte et en comprendre le sens pour pouvoir trouver si une issue
> existe »*

Two mechanisms were being conflated, and only one exists today:

| | What it does | State |
|---|---|---|
| `suggestion_key` | the **same form** submitted twice opens one issue | works, and must stay exact — a hash has to be reproducible after a restart |
| the prior-art sweep | a request **already made in other words** is recognised | does not work |

The sweep compares words. Ticket 01 of the suggestions lot measured why that fails over the
documentation: the vocabulary of the domain is everywhere. Over **open issues it is worse** — two
requests written by two humans share no identifier at all, only ordinary words.

The tracker proves it. Three open issues about the same subject:

```
#240  -cap un peu plus selectif
#187  Modifications du watchdog de CAP
#178  Gérer la destruction du -cap
```

Somebody writing *"je voudrais que la CAP arrête de tirer sur les pilotes en parachute"* may share
no word with any of them, while a human reader sees the connection instantly.

## What to build, and why it is free

Ask the model, **inside the call the flow already makes**.

Measured 2026-09-07: **10 open issues**, short titles, the whole list under 600 characters. The
`/suggest` flow already spends one model call asking the documentation whether the thing exists;
joining the titles to that prompt costs on the order of 200 tokens and answers both questions at
once:

> Here is a request. Here are the titles of the open issues. Does the documentation describe a way
> to do it already, and/or is this one of those issues?

One call, two answers, no extra spend. The text matching stays where it works: the identifiers of a
bug report, the lot names of `.backlog/`, the roadmap sections.

## What must not change

- **The idempotency key stays a hash of the exact content.** It answers a different question, and a
  fuzzy key could not be recomputed after a restart.
- **A match is still proposed, never applied**, with its evidence and a way to refuse it. A model
  saying *this is #240* is a proposal like any other.
- The sweep still runs when there is no model call to be had (quota spent, Worker down), and the
  issue still records which of the two happened.

## Definition of done

- [ ] The open issues' titles travel in the documentation call, not in a second one
- [ ] A reformulated duplicate is proposed, with the issue it matches and why
- [ ] A refusal still carries the suggestion on
- [ ] The deterministic sweep still covers `.backlog/` and `ROADMAP.md`
- [ ] With no model available, behaviour is unchanged and the issue says so
- [ ] Unit tests: a reformulation recognised, a false match refused, no model at all
- [ ] Quality gate clean
