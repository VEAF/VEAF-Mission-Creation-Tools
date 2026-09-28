# FIX-SUPPORT-BOT-DEBTS — four things the support bot owes

Status: ✅ done — all eight tickets, shipped as four sequenced PRs (#934, #935, #936 and this one) · archived 2026-09-28

Origin: three debts recorded across lots 4 and 5 of the support programme, plus one found by David
on **2026-09-07, the first time the bot ran in front of a human**. Grouped because none of them is
worth a lot of its own, and all four are in the same service.

## Why these four together

They share a shape: each one is a place where the service does *almost* the right thing, and where
the gap only shows in use. None is a crash, none has a failing test today, and all four were written
down rather than fixed at the time — deliberately, to keep a lot shippable. This is the lot that
pays them.

| # | Ticket | Where it came from |
|---|--------|--------------------|
| 01 | [The forms speak the user's language](FIX-SUPPORT-BOT-DEBTS.md) | David, first real run, 2026-09-07 |
| 02 | [*He said no* and *he said nothing* are not the same answer](FIX-SUPPORT-BOT-DEBTS.md) | Two agent reviews of lot 5 |
| 03 | [More than one role may open the hypothesis](FIX-SUPPORT-BOT-DEBTS.md) | Review of lot 4, ticket 08 |
| 04 | [`/bug` runs on the same tight token budget `/suggest` was fixed for](FIX-SUPPORT-BOT-DEBTS.md) | Finding 50 of lot 4's review, uncorrected |
| 05 | [A request already made in other words](FIX-SUPPORT-BOT-DEBTS.md) | David, first real run |
| 06 | [*It already exists* needs a page to point at](FIX-SUPPORT-BOT-DEBTS.md) | David, first real run |
| 07 | [Do what the message promised: record the second voice](FIX-SUPPORT-BOT-DEBTS.md) | David, first real run |
| 08 | [Four rough edges the first real run showed](FIX-SUPPORT-BOT-DEBTS.md) | David, first real run |

## What the first real run added

Four of the eight came from one afternoon: 2026-09-07, David running the three commands against the
live Discord, the live Worker and the live tracker. Everything worked — `/ask` answered with its
sources, `/suggest` filed #928, `/bug` filed #929 with an automatic hypothesis that found a link
between three log lines nobody had connected.

What he saw *while* it worked is tickets 05 to 08, and one of them is a design correction rather
than a defect: **a duplicate is recognised by comparing words, and no human types the same words
twice.** That observation reframes the feature, and it is ticket 05.

## What this lot is not

Not a refactor, and not an occasion to revisit the design of either flow. Each ticket is bounded to
the gap it names, and 02 is the only one that touches shared code — which is precisely why it was
left out of lot 5 rather than smuggled into it.

## The one to be careful with

Ticket 02 changes a protocol both flows sit on. It is the reason this lot exists instead of a patch:
`ThreadExchange.confirm` returns a boolean, three states exist behind it, and every caller has to be
looked at rather than adapted mechanically.

---

## Tickets, in full

## 01 — The forms speak the user's language

Status: ✅ done

Type: fix

### What is wrong

The service translates everything it **says** — `texts.py` holds a French and an English catalogue at
parity, and a test fails when they drift. It translates nothing it **shows**. Measured 2026-09-07,
in `discord_bot.py`:

| Hard-coded in English | Count |
|---|---|
| Modal titles (`Report a bug`, `Suggest an improvement`) | 2 |
| Field labels across both modals | 11 |
| Placeholder text | 1 |
| Command descriptions, as Discord's picker shows them | 3 |

French is the service's **default** language, and its most visible surface is English-only. David
switched his client to French to check and nothing moved, which is how this was found: the first
time somebody used the bot who had not written it.

### What to build

The modal is constructed **when the command is typed**, so the interaction — and its locale — are in
hand. Pass the language to the constructor and pull every label from `texts.py`, like the rest.

- `BugModal` and `SuggestModal` take a `lang`, defaulting to the service's default.
- The eleven labels, two titles and one placeholder become catalogue entries. `test_texts.py`
  already fails on a key present in one language and missing in the other, so parity is enforced
  the moment they move there.
- Command **descriptions** are set at registration, once, before any interaction exists. They cannot
  follow a user's locale without `discord.py`'s translator machinery — see the open question.

### The one thing that must not change

The **values** of the component menu. They are the options of
`.github/ISSUE_TEMPLATE/feature_request.yml` and `bug_report.yml`, word for word, and
`tests/test_suggestion.py` asserts they still exist in those files. A translated value is a component
nobody can filter on.

Discord separates a choice's *displayed name* from its *value*, so a French label over an English
value is possible — but the names of choices are declared at registration, like the descriptions.

### Decided: the translator is in scope

The question was whether to adopt `app_commands.Translator` — the only way to localise command
descriptions and choice names, and a machinery of its own (a class, a locale table, a registration
hook) that the modals do not need.

**Decided 2026-09-07 by David, with a screenshot of the command picker:**

```
/ask      Ask a question about the VEAF Mission Creation Tools documentation
/bug      Report a bug — a short form, and the files you have
/suggest  Suggest an improvement — checked against what already exists
```

That is the first thing any mission maker sees of this bot, before typing anything, and it is the
one surface a per-interaction fix cannot reach: descriptions are registered once, before any
interaction exists. So the translator is in scope, and this ticket has two halves:

1. **the modals** — titles, labels, placeholders — from `texts.py`, using the locale of the
   interaction that opened them;
2. **the registered surface** — the three command descriptions, and the component choice *names* —
   through `app_commands.Translator`, whose table Discord stores and serves per client language.

The second half is also what makes a French label possible over an English component **value**,
which must stay word for word the issue templates' own.

### Definition of done

- [ ] Modal titles, field labels and placeholders come from `texts.py`, in both languages
- [ ] The language comes from the interaction, not from a constant
- [ ] Component **values** unchanged, and the tests asserting they match the templates still pass
- [ ] Command descriptions and choice names localised through `app_commands.Translator`
- [ ] Discord's picker shows French to a French client, verified in the client and not only in a test
- [ ] Unit tests: a modal built for `fr` and one for `en` carry different labels
- [ ] Quality gate clean

---

## 02 — *He said no* and *he said nothing* are not the same answer

Status: ✅ done

Type: fix

### What is wrong

`ThreadExchange.confirm` returns a **boolean**, and three states arrive as `False`:

| What happened | What the code knows |
|---|---|
| He clicked *No, mine is different* | `False` |
| He clicked nothing for 300 seconds | `False` |
| Discord refused to display the question | `False` |

The safe direction is right — an unanswered guess must never silence a report — but the *record* is
not: the issue body cannot say which of the three occurred. Lot 5 got as far as it could without
touching the protocol: the sentence no longer claims he disagreed, it says the request was
maintained, which is true in all three. A tri-state would let it say which.

### Why it was left out of lot 5

It touches code both flows sit on: the protocol in `exchange.py`, the gate in `priorart.py`, the
adapters in `intake.py` and `suggest.py`, and the view in `discord_bot.py`. Smuggling that into a
lot about `/suggest` would have made its diff unreviewable — and lot 5's diff was already over the
review limit and had to be split.

### What to build

A returned state rather than a boolean — `SAME`, `DIFFERENT`, `UNANSWERED` — with `UNANSWERED`
covering both the silence and the failure to display, since neither is an opinion.

Every caller has to be **read**, not adapted mechanically: what matters is that no path turns
`UNANSWERED` into agreement. The bug flow's duplicate comment is the sharp edge — it publishes on an
existing issue, and it must keep requiring an explicit *yes*.

### Definition of done

- [ ] Three states, and `UNANSWERED` produced both by a timeout and by a refused display
- [ ] Nothing treats `UNANSWERED` as agreement — asserted per caller
- [ ] The issue body distinguishes the three in its prior-art section, both languages
- [ ] Unit tests: one per state, per flow
- [ ] Quality gate clean

---

## 03 — More than one role may open the hypothesis

Status: ✅ done

Type: feat

### What is wrong

`SUPPORT_BOT_ENRICH_ROLE_ID` reads **one** role id. The decision it encodes — which role means
"VEAF member" — belongs to the association, and the association may well answer with two: *mission
maker* and, say, *staff*.

Recorded as a debt when lot 4 shipped: ten lines in `enrichment.py` and `config.py`.

### What to build

Accept a list where one value is accepted today, and keep the single value working: a deployment
that has one role must not have to learn a syntax.

- Comma-separated ids, whitespace tolerated.
- **Every id still validated as numeric**, with the same refusal at startup. That check exists
  because a mention (`<@&123…>`) or a role *name* compares unequal to every id the bot will ever
  see: the hypothesis would be refused for everybody, for ever, while each issue politely explained
  it is a members' extra — a configuration mistake behaving like a working feature.
- Empty still switches the hypothesis off entirely, which is the default.

### Definition of done

- [ ] One id, several ids, and empty all behave as documented
- [ ] A malformed id in a list is refused at startup, naming its shape and not its value
- [ ] `.env.example` and the README updated together
- [ ] Unit tests: one role, two roles, a member holding neither, a malformed entry
- [ ] Quality gate clean

---

## 04 — `/bug` runs on the same tight token budget `/suggest` was fixed for

Status: ✅ done

Type: fix

### What is wrong

A deferred Discord interaction token dies after **fifteen minutes**. `/bug` spends two waits inside
one: the prior-art proposal (`MATCH_EXPIRY_SECONDS = 300`) and the draft (`DRAFT_EXPIRY_SECONDS =
480`). 780 of 900 seconds, which `draft.py`'s own comment describes as *"leaves two minutes to write
the last message"* — before counting the preparation that precedes them: downloading an 11 MB log,
summarising a mission, walking a checkout for callers.

Finding 50 of lot 4's review. Recorded, not corrected.

The failure it produces is the worst kind: somebody lets the first question expire, takes his time
on the draft, clicks **File the issue** — and the token is dead. He has consented to something that
will never happen, and the service cannot even tell him, since telling him needs the same token.

### What to build

What lot 5 built for `/suggest`, in `SuggestIntake._may_ask`: measure the elapsed time and skip a
*verification* question when the consent click would no longer fit. The checks give way, never the
consent — and a skipped check is still computed and still recorded in the issue.

Read that implementation first; the point is one behaviour in two flows, not two variants.

### Definition of done

- [ ] `/bug` bounds its questions against the token's life, the consent click protected last
- [ ] A skipped sweep is still recorded in the issue, saying nobody was asked
- [ ] The numbers live in one place shared with `/suggest`, not copied
- [ ] Unit tests: a late exchange skips the question and still files; the click always fits
- [ ] Quality gate clean

---

## 05 — A request already made in other words

Status: ✅ done

Type: feat

### What David said, and why he is right

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

### What to build, and why it is free

Ask the model, **inside the call the flow already makes**.

Measured 2026-09-07: **10 open issues**, short titles, the whole list under 600 characters. The
`/suggest` flow already spends one model call asking the documentation whether the thing exists;
joining the titles to that prompt costs on the order of 200 tokens and answers both questions at
once:

> Here is a request. Here are the titles of the open issues. Does the documentation describe a way
> to do it already, and/or is this one of those issues?

One call, two answers, no extra spend. The text matching stays where it works: the identifiers of a
bug report, the lot names of `.backlog/`, the roadmap sections.

### What must not change

- **The idempotency key stays a hash of the exact content.** It answers a different question, and a
  fuzzy key could not be recomputed after a restart.
- **A match is still proposed, never applied**, with its evidence and a way to refuse it. A model
  saying *this is #240* is a proposal like any other.
- The sweep still runs when there is no model call to be had (quota spent, Worker down), and the
  issue still records which of the two happened.

### Definition of done

- [ ] The open issues' titles travel in the documentation call, not in a second one
- [ ] A reformulated duplicate is proposed, with the issue it matches and why
- [ ] A refusal still carries the suggestion on
- [ ] The deterministic sweep still covers `.backlog/` and `ROADMAP.md`
- [ ] With no model available, behaviour is unchanged and the issue says so
- [ ] Unit tests: a reformulation recognised, a false match refused, no model at all
- [ ] Quality gate clean

---

## 06 — *It already exists* needs a page to point at

Status: ✅ done

Type: fix

### What happened, in front of a human

First real `/suggest`, 2026-09-07. The bot announced:

> 📖 **La documentation semble déjà répondre à ta demande.**

and displayed, as that answer:

> *« La documentation ne décrit pas de moyen de dessiner une route pour qu'un convoi la suive. »*

The exact opposite of what it concluded. The model is instructed to answer the keyword `NOTHING`
when the documentation does not cover the subject; it answered **in prose** instead. The code sees
no keyword, infers there is an answer, and puts the question.

Sourcery had flagged the opposite risk on the same function — a prefix match loose enough to discard
a real answer. This is the other side: the model not honouring the keyword at all.

### What to build

**Require a citation.** Say *it already exists* only when the answer cites at least one
documentation page. In the case above it cited none — there was no *Pages citées* line in the
draft.

Why that criterion rather than a stricter reading of the prose: it does not depend on guessing what
a sentence means, and it matches the rule the whole service already runs on — a link the asker can
open is what lets him contradict the machine. An answer with no page to open is not an answer that
something exists.

Note what it changes: `test_an_invented_page_is_not_linked` accepts `EXISTS` with an empty link
list today, on the grounds that a title the corpus does not have is dropped. That case becomes
*silent* instead, which is the honest reading — the model named a page that does not exist.

### Definition of done

- [ ] `EXISTS` requires at least one validated page
- [ ] An answer with no citation is treated as silence, and the issue says the documentation is
      silent rather than that it answered
- [ ] The keyword path still works, decoration and all
- [ ] Unit tests: prose with no source, prose with a source, the keyword, an invented page only
- [ ] Quality gate clean

---

## 07 — Do what the message promised: record the second voice

Status: ✅ done

Type: feat

### Where this comes from

Until today `/suggest` spoke the bug flow's prior-art sentences, which say:

> *« Si c'est bien le même problème, ton observation y sera ajoutée plutôt que d'ouvrir un second
> ticket. »*

`/bug` does exactly that — it drafts a comment, asks a second time, and posts it on the existing
issue. `/suggest` opened nothing and commented nothing: the sentence was a promise it did not keep,
and somebody accepting the match would have believed his view recorded when it was dropped.

Found by David on the first real run. **The wording was fixed immediately** — a suggestion now says
plainly that no issue will be opened. This ticket is the other half: doing what the sentence used to
promise, because it is worth doing.

### Why it is worth doing

A suggestion is only wanted or not, and David alone decides. *A second person asking for the same
thing* is the only signal of priority a suggestion will ever carry — and today it is thrown away
entirely: the asker is told the subject is tracked elsewhere, and nothing anywhere records that one
more person needed it.

### What to build

The same shape as the bug flow's duplicate comment, and the same guard:

- the comment is **drafted and shown**, and posted only on a second click. It publishes somebody's
  words on a public tracker; recognising an issue as one's own is not the same act as agreeing to
  publish under it;
- it carries what a maintainer needs and nothing more: the problem as the asker stated it, and who
  asked. Not the whole feature request template — the issue already holds one.

The machinery exists: `IssueFiler.comment_on` and `comment_draft_of`. Both are typed on `BugReport`
and need the same generalisation `file_prepared` got.

### Definition of done

- [ ] An accepted duplicate offers to add the observation, and posts only on the click
- [ ] Every other answer — refusal, silence, expiry — posts nothing
- [ ] The comment names the asker and states his problem, without repeating the template
- [ ] `comment_on` serves both flows through one mechanism
- [ ] Unit tests: accepted and posted, accepted and declined, unanswered
- [ ] Quality gate clean

---

## 08 — Four rough edges the first real run showed

Status: ✅ done

Type: fix

### Where these come from

David ran `/ask`, `/suggest` and `/bug` for real on 2026-09-07, against the live Discord, the live
Worker and the live tracker. Everything worked. These four are what he saw while it did — none is a
failure, all four are visible to whoever uses the bot next.

### 1. A component nobody can filter on

Issue #929 was filed as component **`Other`**, while the code it located was
`src/scripts/community/AIEN.lua` — Lua that runs in a mission, so `Lua runtime scripts
(in-mission)`. Cause: `COMPONENT_RULES` in `bugreport.py` knows `src/scripts/veaf/` and nothing else
under `src/scripts/`. Everything community-shipped falls into the catch-all.

One line. But the component drives a label, so today those reports are unfilterable.

### 2. English sentences in a French issue

In the body of #929, among French headings:

> *« 1202 of 10455 records kept by the Diagnostic profile; 38 of them match no catalogue entry. »*

and, in the attachment manifest:

> *« non publié ici : 1840576 bytes, past the 24000 an issue can carry — see the excerpt above »*

Both are written in `attachments.py`, outside the translation catalogue. Same family as the modal
labels of ticket 01: the service translates what it *says* through `texts.py` and hard-codes
everything else.

### 3. Two counters that contradict each other on sight

The same section says **1202 records kept**, then `[veaf-logs] 48 entrées sur 10455 indexées (1202
retenues, 1154 omises par la limite de taille)`. They measure different things — entries rendered in
the excerpt, records kept by the profile — and side by side they read as an inconsistency. Name
them, or show one.

### 4. The idempotency marker is visible in the Discord preview

Every draft opens with:

```
<!-- veaf-support-bot:report=ad7bd4fe8e96c2232cc9da0f52e32b89 -->
```

Invisible on GitHub, where it is an HTML comment and where the recovery search greps for it. Discord
renders it as text, so the preview starts with a line nobody can read. The marker must stay in the
**issue**; it has no reason to be in the preview.

### Definition of done

- [ ] `src/scripts/` maps to the Lua component, with its label, and the rule covers what is under it
      rather than one directory
- [ ] The log digest and the attachment manifest speak the reporter's language
- [ ] The two counters are named for what they count, or reduced to one
- [ ] The preview does not show the marker; the filed issue still carries it, and the recovery
      search still finds it
- [ ] Unit tests per point, the marker one asserting both halves
- [ ] Quality gate clean

---
