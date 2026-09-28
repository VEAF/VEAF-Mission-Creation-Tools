# DOC-VALIDATION-MESSAGES — 96 of the 98 messages the tools print are documented nowhere

Status: ✅ done · archived 2026-09-28

Opened 2026-09-19, out of [FIX-WHAT-THE-MISSION-MAKER-CAN-ACT-ON](FIX-WHAT-THE-MISSION-MAKER-CAN-ACT-ON.md),
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

**Asked after the merge, and it failed — for a reason that is not this lot.** The index workflow ran green a minute after #967 merged; the assistant still answered with the invented `mission.yaml` key. `docs-chatbot-index.yml` writes to wrangler's **local** store and prints `Success!`, and has done since the chatbot's first commit, so the live index predates `TUTORIAL.md` (2026-08-31). Tracked as [FIX-CHATBOT-INDEX-UPLOADS-LOCALLY](FIX-CHATBOT-INDEX-UPLOADS-LOCALLY.md); this lot stays 🧑 until the question can be asked against a real index.

### The assistant, asked — 2026-09-19 {#assistant-asked}

The first attempt, straight after this lot merged, still produced the invented `mission.yaml` key.
That was not this lot: the rebuild workflow had been writing to wrangler's local store since
2026-08-08, so the index was six weeks stale. Fixed in
[FIX-CHATBOT-INDEX-UPLOADS-LOCALLY](FIX-CHATBOT-INDEX-UPLOADS-LOCALLY.md) (#968), whose first
run reported `Resource location: remote` and `Index verified`.

Asked again, on the real index:

> **Q.** *Camp 'red' : les pays [68 (USSR)] possèdent des unités mais ne figurent pas dans
> coalitions.red. Qu'est-ce que ça veut dire et que dois-je faire ?*
>
> **A.** …DCS ouvrira l'écran CHANGING COALITIONS […] **deux options** : ajouter l'identifiant
> numérique à `coalitions.red` — *"n'écrire que le nombre seul (68), jamais le nom"* — dans
> l'éditeur DCS puis ré-extraire ; ou réaffecter les objets à un pays déjà listé.

No `mission.yaml` key, both ways out, the right place to fix it, and it cites the new page's own
section. And the false lead that started all of this:

> **Q.** *Est-ce que mes objets statiques neutres peuvent être la cause de ce message sur le camp
> red ?*
>
> **A.** *Non […] les objets statiques comptent bien comme des unités pour ce contrôle […] mais un
> objet neutre appartient au camp `neutrals`, et le contrôle est fait camp par camp.*

That is the whole chain closed: message → page → retrieval → answer.

## Definition of done

- [x] The shape above is decided and recorded here
- [x] The messages that generate real support traffic are documented, FR **and** EN, in the `nav`,
      with explicit English anchors (`{#...}`) per the repository's documentation rules
- [x] Each page says what the message means in Mission Editor terms, how to reproduce it, the ways
      out, and what it is *not*
- [x] `poetry run docs-check` green
- [x] Re-measure the 2-of-98 figure at closing time and record the new one here
- [x] Spot-check that the documentation assistant now answers the reported coalition question
      correctly, since grounding it was the point — **done 2026-09-19**, after
      [FIX-CHATBOT-INDEX-UPLOADS-LOCALLY](FIX-CHATBOT-INDEX-UPLOADS-LOCALLY.md) made the
      rebuild actually upload. See *The assistant, asked* below

---

## Tickets, in full

## 01 — The index page, and the shape the others follow

Status: ✅ done

Type: docs · Files: `doc/mission-maker/build-messages/README.md` + `.en.md`, `mkdocs.yml`

### What it is

The page a mission maker lands on with a message in hand. It has to do three things and no more:

1. **Say where the message came from** — `build` prints most of them and builds the `.miz` anyway;
   `validate` prints the same checks and exits non-zero. A reader who thinks the build failed when
   it did not will go looking for a `.miz` that is right there.
2. **Route to the family page**, through a table of every covered message.
3. **Say what to do when the message is not here** — 65 of the 98 are not, and pretending otherwise
   is worse than admitting it. Point at `SUPPORT.md`.

### Definition of done

- [x] Both languages, in the `nav` with `nav_translations`
- [x] The table lists every message the lot covers, each linking to its explicit anchor
- [x] States plainly that the list is not exhaustive, and where to go otherwise
- [x] No version number written by hand; PowerShell examples use `.\veaf-tools.exe`
- [x] `poetry run docs-check` passes

---

## 02 — Coalitions and countries — the reported case

Status: ✅ done

Type: docs · Files: `doc/mission-maker/build-messages/coalitions.md` + `.en.md`

### What it is

The page that would have answered the mission maker of `FIX-WHAT-THE-MISSION-MAKER-CAN-ACT-ON`.

Messages: `validate.side_missing_countries`, `validate.side_without_country`,
`builder.coalition_placeholder_injected`, `builder.coalition_country_unexpected`.

### What it has to carry, beyond the message text

- **In Mission Editor terms.** The message names `coalition.red.country` and `coalitions.red`. The
  reader sees objects on a map and a coalition column in the editor. Two tables in the `.miz`
  describe the same fact — which countries a side owns, and what each of them fields — and the
  message fires when only the second is populated.
- **A country table.** The reader is handed a number. Since PR #966 the message names the country
  too, but the page is where the mapping lives, and where someone reading an older message, a log,
  or a `.miz` by hand can resolve an id.
- **What it is not.** The reported reader was convinced his **neutral statics** were the cause.
  They were not, and the reason is worth stating exactly, because half of it is counter-intuitive:
  statics *do* count as units for this check, but a neutral object belongs to the `neutrals` side,
  and the check runs per side. A message about `red` can only be about a red-side object.
- **The ways out, with the trade-off.** Assign the country to the side, or re-assign the objects to
  a country already listed — which is why the message prints both lists.
- **Where the fix happens.** Not in `mission.yaml`, which has no `coalitions` key — that was the
  assistant's exact mistake. It is the Mission Editor, or `src/mission/mission` in the folder.

### Definition of done

- [x] Both languages, in the `nav` with `nav_translations`
- [x] One explicit anchor per message, derived from its locale key
- [x] The country table is generated from the repository's own data, not typed by hand
- [x] The neutral-statics false lead is addressed head on
- [x] `poetry run docs-check` passes

---

## 03 — References to things the Mission Editor does not have

Status: ✅ done

Type: docs · Files: `doc/mission-maker/build-messages/missing-references.md` + `.en.md`

### What it is

The largest family, and the one that costs a session in DCS rather than a minute at the console:
`mission.yaml` names a group, a zone, a unit or an airfield that is not in the `.miz`. The build
prints a framed summary at the end and produces the mission anyway; the feature then does nothing
in game, silently.

Messages: `builder.reference_issues_header`, `validate.missing_group` /
`builder.declared_group_missing`, `validate.missing_trigger_zone`,
`validate.missing_trigger_zone_optional`, `validate.missing_unit`, `validate.unknown_airfield`,
`validate.undeclared_subzone`.

### What it has to carry, beyond the message text

- **Why the build did not stop.** Deliberate: blocking would deny the maker the `.miz` they need in
  order to place the missing object.
- **The `section` in the message is a `mission.yaml` path**, and the page says which sections are
  checked — ASSETS, QRA, COMBATZONE, SANCTUARY, `cap_missions`, `combat_missions` — because a
  reader who does not know that will search the wrong file.
- **The two traps that are not typos.** `cap_missions` groups are looked up with the
  `OnDemand-` prefix the runtime adds, so the editor group is named `OnDemand-<name>`; a SANCTUARY
  `polygon_units` entry may name a **group** as well as a unit.
- **Optional versus mandatory.** An AIRWAVES `trigger_zone_name` with an explicit centre and radius
  degrades to a warning and the mission still works; a QRA or COMBATZONE zone does not.
- **What it is not.** Not a VEAF script failure, and not something a rebuild fixes.

### Definition of done

- [x] Both languages, in the `nav` with `nav_translations`
- [x] One explicit anchor per message, derived from its locale key
- [x] The checked `mission.yaml` sections are listed, matching `group_validation.py`
- [x] `poetry run docs-check` passes

---

## 04 — The Lua files in your mission folder

Status: ✅ done

Type: docs · Files: `doc/mission-maker/build-messages/lua-files.md` + `.en.md`

### What it is

The family born of a real report: Tripack, 2026-09-03, building `Snowfox_20260903.miz`
(`FIX-EXTRACT-GENERATED-ARTIFACTS`). The build finds a `.lua` in `src/scripts/` it did not expect
and says so — and the reader cannot tell from the message whether they broke something.

Messages: `builder.unexpected_lua_file`, `builder.generated_artifact_in_sources`,
`builder.generated_artifact_spawn_data_hint`, `builder.custom_loader_hint`,
`builder.custom_lua_included`, `builder.mist_injected_for_custom_scripts`,
`validate.custom_script_missing`.

### What it has to carry, beyond the message text

- **The three kinds of Lua file** the build distinguishes in `src/scripts/`: the ones it expects,
  the ones you declared in `custom_scripts:`, and the ones it generated itself. Each message maps
  to one of the three, and the right action differs.
- **Where a generated artifact comes from** — an extraction of an already-built mission handing the
  build its own output back — and why declaring it in `custom_scripts:` is the one thing not to do.
- **The v5 residue case.** A script that loads other scripts is a v5 loader; v6 wants
  `custom_scripts:` instead.
- **What it is not.** None of these stop the build, and none of them mean a file was lost.

### Definition of done

- [x] Both languages, in the `nav` with `nav_translations`
- [x] One explicit anchor per message, derived from its locale key
- [x] The list of expected file names matches `_EXPECTED_SCRIPTS` and `GENERATED_LUA_ARTIFACTS`
- [x] Links to the existing custom-scripts card rather than re-teaching it
- [x] `poetry run docs-check` passes

---

## 05 — Routes DCS refuses, and holed mission tables

Status: ✅ done

Type: docs · Files: `doc/mission-maker/build-messages/routes-and-tables.md` + `.en.md`

### What it is

Two small families that share a property: the message is about data **DCS itself** will reject or
choke on, so the reader has no way to guess the rule from the editor.

Messages: `validate.route_no_locked_time`, `validate.route_contradictory_locks`,
`validate.holed_sequence` / `builder.mission_table_renumbered`, plus the two
"configured but nothing to apply it to" warnings `validate.presets_no_aircraft` and
`validate.waypoints_no_aircraft`.

### What it has to carry, beyond the message text

- **The waypoint lock rule, in editor words.** *Locked time* is the ETA checkbox on a waypoint,
  *locked speed* the speed one. The editor refuses a route with no locked time at all, and one
  whose locked speed sits between two locked times. Found on 2026-08-22 by David, on a mission the
  validator had just called sound (`FIX-VALIDATE-CONTRADICTORY-WAYPOINT-LOCKS`).
- **Where a holed table comes from** — a hand edit or a third-party tool — and that the build
  closes the hole, so the message is an invitation to check, not a failure. The version that did
  *not* say so cost a debugging session: three holes surfaced at three unrelated subsystems under
  `'int' object has no attribute 'get'`, naming none of them.
- **What it is not.** Not something VMCT wrote. These are warnings on data that arrived that way.

### Definition of done

- [x] Both languages, in the `nav` with `nav_translations`
- [x] One explicit anchor per message, derived from its locale key
- [x] The lock rule is stated as the editor's checkboxes, not as `ETA_locked` / `speed_locked` alone
- [x] `poetry run docs-check` passes

---

## 06 — Modules and community scripts

Status: ✅ done

Type: docs · Files: `doc/mission-maker/build-messages/modules.md` + `.en.md`

### What it is

The family with the most evidence behind it: `builder.ctld_no_config` alone is named in four
backlog lots, two of which (`DOC-CTLD-TOOLS-DOWNLOAD`, `FIX-DEFAULT-COMMUNITY-NOISE`) exist purely
because readers could not tell whether the message meant they had broken something.

Messages: `builder.ctld_no_config`, `builder.ctld_no_config_by_default`,
`builder.ctld_logistics_unmanaged_and_empty`, `builder.ctld_logistics_merged`,
`builder.community_sounds_missing`, `validate.tum_zones_missing`, `validate.incompatible_module` /
`builder.incompatible_modules`, `builder.mandatory_module_enable`, `builder.orphan_lua_module`.

### What it has to carry, beyond the message text

- **Community scripts are opt-out.** That single fact explains most of this page: a module can be
  in your mission although `mission.yaml` never mentions it, which is exactly why a warning about
  it reads as an accusation.
- **The two CTLD messages are different situations** with different right answers — you asked for
  CTLD and have no config, versus you never asked for CTLD at all.
- **TUM aborts at start-up** without its territory zones, so this warning is the only notice you
  get before the module is simply absent in game.
- **What it is not.** None of these mean a module failed to load, and `builder.ctld_no_config_by_default`
  means nothing is wrong at all.

### Definition of done

- [x] Both languages, in the `nav` with `nav_translations`
- [x] One explicit anchor per message, derived from its locale key
- [x] The opt-out default is stated once, up front, and linked from the messages that depend on it
- [x] `poetry run docs-check` passes

---

## 07 — Re-measure, and ask the assistant the original question

Status: ✅ done

Type: chore

### What it is

The lot's own acceptance test. The point was never the page count.

**Re-measure** with the same method as the opening measurement — for each `validate.*` /
`builder.*` key, take the longest literal run of the message (rich markup and `{placeholders}`
removed, 12 characters minimum) and look for it anywhere under `doc/`. Record the new figure in the
PRD next to the old one.

**Then ask the assistant** the question that opened this whole thread: what the coalition message
means and what to do about it. The documentation chatbot retrieves from an index built off `doc/`,
so the pages have to be indexed before the check means anything.

⚠️ Known constraint carried over from `FIX-WHAT-THE-MISSION-MAKER-CAN-ACT-ON`: the Worker is
deployed by hand and the index is rebuilt by hand. If neither can be done from here, say so
explicitly rather than reporting a check that was not run — and record what *was* verified instead.

### Definition of done

- [x] The new figure measured and written into the PRD — **1 → 36**, both languages, with a
      detector fixed to see a message quoted across wrapped lines
- [x] The assistant asked the coalition question, and it answers correctly — see the PRD's
      *The assistant, asked*. It took FIX-CHATBOT-INDEX-UPLOADS-LOCALLY first: the first attempt
      failed because the index had been stale since 2026-08-08

---
