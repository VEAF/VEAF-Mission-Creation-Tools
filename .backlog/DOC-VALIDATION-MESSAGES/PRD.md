# DOC-VALIDATION-MESSAGES — 96 of the 98 messages the tools print are documented nowhere

Status: ⬜ ready

Opened 2026-09-19, out of [FIX-WHAT-THE-MISSION-MAKER-CAN-ACT-ON](../FIX-WHAT-THE-MISSION-MAKER-CAN-ACT-ON/PRD.md),
which fixed one message and taught the assistant to admit ignorance. This lot is the reason it had to
admit it.

## The measurement

Counting the `validate.*` and `builder.*` keys in the locale files, and looking for each message's
longest literal run anywhere under `doc/`:

| | |
|---|---|
| Messages the tools can print | **98** |
| Whose wording appears anywhere in the documentation | **2** |

A mission maker who meets one of the other 96 has nowhere to look. Searching the site finds nothing,
and the documentation assistant — which can only read `doc/` — has nothing to ground an answer in. It
is the most common shape of question the project gets ("the build printed this, what do I do?") and
the documentation answers it twice out of ninety-eight times.

## Why this is worth a lot of its own

The message text itself already says *what* is wrong; it is written for someone who knows the model.
What is missing is the rest of what the reader needs, and it does not fit in a message:

- **what it means in Mission Editor terms** — the message speaks of `coalition.red.country`, the
  reader sees an object on a map;
- **how to reproduce the situation**, so they recognise theirs;
- **the two or three ways out**, with the trade-off between them;
- **what it is not**, which is where the support time actually goes. The reported case was a mission
  maker convinced his *neutral statics* were the cause; ruling that out took reading the validator.

## Shape to decide before writing

This needs a decision, not just typing, and the decision belongs to whoever picks the lot up:

1. **One reference page per family** (coalitions, waypoints, presets, radio, scripts…) with an
   explicit anchor per message, and the message keys as anchors so a future tool can link straight to
   them. Heavier, but it reads as documentation rather than as a dump.
2. **One flat page**, one section per message, generated from the locale files so a new message
   cannot ship undocumented. Cheaper and self-guarding, but a generated page reads like a table and
   teaches little.
3. **Only the messages people actually hit.** There is no telemetry, but there is a support history
   — the Discord Q&A and the bug intake the bot already handles. Start from what was really asked.

Recommendation: **3 then 1** — write the dozen that generate support traffic as real prose with
anchors, and leave the tail alone until it costs someone something. Generating 98 stubs nobody reads
would satisfy the count and change nothing for the reader, which is the failure mode
`CHORE-TESTING-DOC-COUNTS` already met once on this repository.

**Not recommended: a `docs-check` rule requiring every message to be documented.** It would turn the
tail into an obligation and reward stub pages. Worth revisiting only once the dozen exist.

## Definition of done

- [ ] The shape above is decided and recorded here
- [ ] The messages that generate real support traffic are documented, FR **and** EN, in the `nav`,
      with explicit English anchors (`{#...}`) per the repository's documentation rules
- [ ] Each page says what the message means in Mission Editor terms, how to reproduce it, the ways
      out, and what it is *not*
- [ ] `poetry run docs-check` green
- [ ] Re-measure the 2-of-98 figure at closing time and record the new one here
- [ ] Spot-check that the documentation assistant now answers the reported coalition question
      correctly, since grounding it was the point
