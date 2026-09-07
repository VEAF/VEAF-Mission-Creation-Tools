# FIX-SUPPORT-BOT-DEBTS — four things the support bot owes

Status: ⬜ ready

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
| 01 | [The forms speak the user's language](tickets/01-modal-i18n.md) | David, first real run, 2026-09-07 |
| 02 | [*He said no* and *he said nothing* are not the same answer](tickets/02-tri-state-confirm.md) | Two agent reviews of lot 5 |
| 03 | [More than one role may open the hypothesis](tickets/03-several-roles.md) | Review of lot 4, ticket 08 |
| 04 | [`/bug` runs on the same tight token budget `/suggest` was fixed for](tickets/04-bug-token-budget.md) | Finding 50 of lot 4's review, uncorrected |
| 05 | [A request already made in other words](tickets/05-duplicate-by-meaning.md) | David, first real run |
| 06 | [*It already exists* needs a page to point at](tickets/06-exists-needs-a-source.md) | David, first real run |
| 07 | [Do what the message promised: record the second voice](tickets/07-observation-on-the-existing-issue.md) | David, first real run |
| 08 | [Four rough edges the first real run showed](tickets/08-first-run-finish.md) | David, first real run |

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
