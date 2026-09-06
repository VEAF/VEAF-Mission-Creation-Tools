# 01 — Does it already exist? Answer that first

Status: ✅ done

Type: feat

## What to build

Before anything is drafted, four sources are consulted and each produces its own answer in the
thread:

| Source | How it is consulted | Verdict it can return |
|---|---|---|
| `doc/` | the documentation assistant is **asked** | it exists and is documented — here is the answer and its pages |
| open issues | text matching, from the bug lot | it is already requested |
| `.backlog/<LOT>/` | text matching, from the bug lot | a lot already covers it, at this status |
| `ROADMAP.md` | text matching, from the bug lot | it is parked, ordered, or explicitly cancelled with its reasons |

None of the four opens an issue on its own, and none of them closes the flow on its own either: a
match is shown with its evidence and the user says whether it is what he meant.

## Why the documentation is asked rather than searched

The original shape of this ticket had the sources swept by text matching, like the bug lot's
duplicate sweep, and the PRD stated the sweep would cost no model call. **Measured on the real tree,
that does not work**, and the measurement is worth keeping:

| word | pages containing it | pages with it in a heading |
|---|---|---|
| `csar` | 24 / 144 (17%) | 6 |
| `combat` | 69 / 144 (48%) | 20 |
| `zone` | 87 / 144 (60%) | 20 |

The words that name a feature are everywhere in the documentation, because the pages cross-reference
each other — which is what makes the documentation good. No threshold separates *the page describing
CSAR* from *the twenty-four pages mentioning CSAR*. Three scorings were written and measured before
this was accepted: plain overlap scored 82% on `add`, `radio` and `way`; rarity weighting still
matched a request for SMS alerts against the support page, on `bot` and `serveur`, at 57%; requiring
the word in a heading changed neither. The bug sweep works because two reports of the same bug share
identifiers a reporter pasted — `veafSpawn.lua`, `KeyError`. A suggestion has none.

*"Does the documentation describe a way to do this?"* is the question `/ask` already answers, from
the same corpus, with its sources and under its quota. So the flow asks it. **Decided 2026-09-06**
with David, against three alternatives: showing leads instead of a verdict, a dedicated model call,
and dropping the documentation source altogether.

## What this costs, and what it changed

One model call per suggestion, on the free Gemini tier measured at 20 requests a day for the whole
Google project — shared with `/ask` and the site. The PRD's "no model call at all" is wrong and is
corrected there.

The **source tree is no longer swept**. A user cannot read Lua to find out whether his idea exists,
so the sources were never an answer *to him*; and matching them was measurably worse than matching
the documentation (a request about rescue helicopters scored 75% against
`v5_pipeline_converters.py`). The useful half of that verdict survives without pretending: when the
documentation is silent, the filed issue carries a line saying so, so a maintainer who knows the
feature exists reads it as the documentation gap it is.

## The failure mode to guard

A wrong *"it already exists"* silences a real idea, and the user will not argue with a bot. So the
answer is always shown **with its pages**, the user can say *that is not what I meant*, and the flow
continues to a real suggestion. What he answers is recorded either way: a rejection of an answer the
documentation actually gave is worth reading later.

*"The documentation could not be consulted"* is a third outcome, distinct from *"the documentation
says nothing"* — the Worker can be down and the quota can be spent. An issue that confuses the two
tells its reader the documentation was checked when it was not.

## Definition of done

- [x] The documentation is asked whether the request already exists, reusing the `/ask` Worker path
- [x] Three verdicts — it exists, it is silent, it could not be asked — each distinguishable
- [x] The answer carries the pages it cited, validated against the real tree so none is invented
- [x] Unit tests: the three verdicts, the absence keyword against prose containing it, and the
      instruction never reaching the retrieval query
- [x] The issues, `.backlog/` and `ROADMAP.md` sweep reused unchanged from the bug lot
- [x] Every match shows its evidence and can be rejected, after which the flow continues
- [x] Quality gate clean
