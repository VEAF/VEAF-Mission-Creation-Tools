# DOC-VALIDATION-MESSAGES — 96 of the 98 messages the tools print are documented nowhere

Status: 🧑 waiting-human

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

## Decision, 2026-09-19 — shape 3, laid out as shape 1 {#decision}

**Option 3 then 1, as recommended, with the tail explicitly left alone.**

Messages are grouped into **families**, one page each, under a new `Build messages` section of the
Mission Maker menu. Within a page, each message gets an explicit anchor derived from its locale key
(`validate.side_missing_countries` → `{#validate-side-missing-countries}`), so a future `--explain`
flag, or the message text itself, can link straight to it without depending on a heading wording.

### How "generates real support traffic" was decided, having no telemetry

The project has no counter on its messages. What it does have is a backlog where a lot gets opened
when somebody is stuck, so the proxy used here is: **a message is in scope when the repository can
show it cost someone something**, or when it leaves the mission maker with nowhere to go.

| Criterion | Example |
|---|---|
| A lot was opened from a real report about it | `FIX-EXTRACT-GENERATED-ARTIFACTS` (Tripack, 2026-09-03), `DOC-CTLD-TOOLS-DOWNLOAD`, `FIX-DEFAULT-COMMUNITY-NOISE` |
| DCS refuses the mission, or the editor refuses the route | `validate.side_missing_countries` (the reported case), `validate.route_no_locked_time` |
| The feature dies at runtime, with nothing said in game | `validate.missing_group`, `validate.tum_zones_missing` |

That yields **33 messages across 6 pages**, not 98. The rest is deliberately untouched: it is
mostly progress reporting (`builder.creating_mission`, `builder.injecting_scripts`) or a message
whose one sentence is already the whole answer.

### What is *not* done, and why

**No `docs-check` rule requiring every message to be documented**, per the PRD's own warning. It
would turn the remaining 65 into an obligation discharged by stubs, which is the failure mode
`CHORE-TESTING-DOC-COUNTS` already met here. The question is worth reopening once these six pages
have been in front of readers.

**No generated page.** A generated table cannot say what a message *is not*, and that is where the
support time goes — in the reported case, ruling out the mission maker's neutral statics took
reading the validator.

## Outcome — measured 1 → 36, and four messages that cannot be printed {#outcome}

### The re-measurement, and why the opening figure moved

The opening measurement's detector compared an **unbroken** message string against raw markdown.
Documentation wraps at a hundred columns and quotes messages inside blockquotes, so a message
quoted verbatim in a page would not have been detected at all. The detector was therefore fixed
(whitespace normalised, blockquote markers stripped) and **both** states were measured with it:

| | before (`origin/develop`) | after |
|---|---|---|
| `validate.*` / `builder.*` keys | 98 | 98 |
| Documented, French | **1** | **36** |
| Documented, English | **1** | **36** |

The before figure is 1, not the PRD's 2: the original count added the French and the English hit of
the *same* message, `builder.active_modules`. Nothing else was ever documented, in either language.

36 rather than the 33 planned — a few messages (`builder.modules_conflict`,
`builder.incompatible_modules`, `validate.presets_no_aircraft`…) are quoted in passing on a page
that covers their family.

### Four messages the tools cannot actually print

Found while checking each message against its producer, which is the part of this work that had to
happen anyway:

| Key | Why it is dead |
|---|---|
| `builder.declared_group_missing` | Referenced nowhere; the build reports that situation through `validate.missing_group` |
| `builder.orphan_lua_module` | Referenced nowhere (its twin `builder.orphan_pipeline_file` is live) |
| `builder.injecting_scripts` | Referenced nowhere |
| `builder.mandatory_community_kept` | Referenced, but behind `MANDATORY_COMMUNITY_SCRIPTS`, now an empty `frozenset` — the branch cannot be taken |

None of them is documented here: documenting a message nobody can receive is worse than leaving it
out. **Deleting the four keys is left out of this lot deliberately** — it is a code change in a
documentation lot, and the fourth needs a decision (is MiST meant to be mandatory again, or is the
empty set the intent?) that belongs with whoever owns the module list. Worth its own chore.

Two other claims were corrected against the code rather than paraphrased from the message:

- `builder.mandatory_module_enable` goes through `logger.error`, which raises `typer.Abort`, so it
  **stops the build** — and it only fires on the expanded form carrying an `enable`/`enabled` key,
  not on `UNITS: false`.
- info-level messages are printed on a transient status line that immediately rewrites itself, so
  they can scroll past unseen. Said on the index page and where it matters, since two of the CTLD
  messages are info-level.

### The assistant check — what was and was not done

**Not done as specified, and the reason is concrete:** rebuilding the retrieval index needs a
Gemini API key, which this workstation does not hold (`.dev.vars` absent, `GEMINI_API_KEY` unset).
Asking the live assistant today would only measure the *old* index and prove nothing.

What was verified instead, from here:

1. **The index rebuild is automatic**, contrary to the caveat carried over from the previous lot —
   that one is about the Worker *code*. `.github/workflows/docs-chatbot-index.yml` fires on a push
   to `develop` touching `doc/**`, rebuilds the embeddings and upserts them into KV. So merging
   this lot re-indexes the new pages without anyone doing anything.
2. **The new folder is picked up**: `collectMarkdown` recurses into subdirectories.
3. **The answer survives chunking**: the indexer's own `chunkMarkdown` (lifted verbatim from
   `build-index.mjs` rather than re-implemented) splits `coalitions.md` into 7 chunks, and the three
   passages that answer the reported question land in three of them — the message and the "not in
   `mission.yaml`" correction in chunk 1, the neutral-statics rebuttal in chunk 2, the country table
   in chunk 5. The retriever keeps the top 6, so none of them is out of reach.

**Asked after the merge, and it failed — for a reason that is not this lot.** The index workflow ran green a minute after #967 merged; the assistant still answered with the invented `mission.yaml` key. `docs-chatbot-index.yml` writes to wrangler's **local** store and prints `Success!`, and has done since the chatbot's first commit, so the live index predates `TUTORIAL.md` (2026-08-31). Tracked as [FIX-CHATBOT-INDEX-UPLOADS-LOCALLY](../FIX-CHATBOT-INDEX-UPLOADS-LOCALLY/PRD.md); this lot stays 🧑 until the question can be asked against a real index.

## Definition of done

- [x] The shape above is decided and recorded here
- [x] The messages that generate real support traffic are documented, FR **and** EN, in the `nav`,
      with explicit English anchors (`{#...}`) per the repository's documentation rules
- [x] Each page says what the message means in Mission Editor terms, how to reproduce it, the ways
      out, and what it is *not*
- [x] `poetry run docs-check` green
- [x] Re-measure the 2-of-98 figure at closing time and record the new one here
- [ ] Spot-check that the documentation assistant now answers the reported coalition question
      correctly, since grounding it was the point — **the one item left**, and the only reason
      this lot is 🧑 rather than ✅. It needs the index CI rebuilds on merge; see the outcome
      section for what was verified in its place
