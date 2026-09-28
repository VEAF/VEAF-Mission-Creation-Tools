# FEAT-SUPPORT-LOG-ANALYSIS — explain a DCS log where the log actually is

Status: ✅ done · archived 2026-09-28

Origin: design session of 2026-09-05. David's second idea: an analyser that handles **any** DCS
problem — not only VEAF ones, though it should be especially good on VEAF missions — to help a
mission maker or a pilot, **without** creating an issue. Lot 2 of the five-lot programme described
in [`FEAT-SUPPORT-DIAGNOSTIC`](FEAT-SUPPORT-DIAGNOSTIC.md).

## Why it runs locally, and not on Discord

The obvious design is "drop your log in the channel". It does not survive contact with a real log.

| Measured 2026-09-05, on David's machine | |
|---|---|
| `dcs.log`, current | **11.1 MB** |
| Rotated archives, still compressed | up to 8.6 MB |
| Discord upload ceiling, account without subscription | ~10 MB (to confirm, but the order of magnitude decides it) |

His own log would not go through. And `veaf-logs` already has the file open, with the rules and the
*Diagnostic (erreurs + contexte)* profile applied. So the reduction happens on the machine and only
the excerpt travels — the programme's second principle, applied.

The Discord door stays open in lot 4 for a **pasted** excerpt, which is exactly what ticket 05 of
this lot produces.

## The knowledge already exists

[`veaf_logs/rules.json`](../../src/python/veaf-tools/veaf_logs/rules.json) is not a filter, it is a
catalogue: **13 recognised sources**, **8 families of native DCS subsystems** (Moteur, Graphismes,
Terrain, Monde, Son…), and **22 known-noise patterns**, each carrying a `help` text written for the
user — *"Modules tiers dont le modèle de dégâts n'est pas au format attendu. Cosmétique."*

That file is the **authority**. What it knows is rendered as it stands, with its verified wording.
The model chains the clues and puts them in context; where the catalogue is silent it says *pattern
not catalogued* instead of inventing a cause.

This is the decision that makes the lot safe to ship. The worst outcome is not "I do not know" — it
is *"it is your module X"* when it is not, told to a pilot who will spend his evening on it and has
no way to tell the guess from the fact.

## The loop that pays for itself

Every recurring pattern the analyser meets outside the catalogue comes back as a **proposed
`rules.json` entry**. The tool then gets better deterministically, offline, and for free — and the
next user gets the verified wording instead of a guess. That is the capitalisation David asked for
when he said this flow must not create issues.

## Cost

Free model, through the existing Worker, as with `/ask`. Debugging DCS is a volume activity with no
traceable output; it sits on the free side of the line by construction. Note the precedent: the
"every user brings their own API key" route was tried for the CLI chatbot and **abandoned** — PR
#453 replaced #452's user-key approach with a keyless, Worker-only one. Do not walk it again.

## Constraints

- The excerpt sent out must be **bounded and redacted**, reusing the redaction written in
  [`FEAT-SUPPORT-DIAGNOSTIC` ticket 01](FEAT-SUPPORT-DIAGNOSTIC.md).
- Search context pulled in around a hit must not resurrect what the categories set to ✕ — the same
  trap `FEAT-VEAF-LOGS-READABILITY` had to get right.
- `veaf-logs` is a PySide6 application; the coverage gate measures it only when the `logs` extra is
  installed. Local runs without it read ~5 points low.
- Both documentation languages.

## Open questions

1. **Discoverability for pilots.** `veaf-logs` is documented under `doc/mission-maker/` only, yet
   half the audience of this lot is pilots. They need a door of their own — ticket 06 opens it, the
   shape is David's call.

   **Answered by the implementation, 2026-09-05, and open to being overruled:** a **standalone page**
   (`doc/pilot/dcs-trouble.md`, *DCS se comporte mal*) rather than a section of `pilot/GUIDE.md`. The
   problem the ticket names is discoverability through the menu, and a section buried in a document
   about F10 menus is exactly as invisible as the mission-maker page it replaces. Moving it into
   `GUIDE.md` later is a copy-paste.

2. **Where proposed catalogue entries go**: an automatic PR, a local file the user sends, or a
   message in a channel. Ticket 04 ships the detection; the delivery channel is undecided.

   **Still undecided, and recorded as deferred** in [ticket 04](FEAT-SUPPORT-LOG-ANALYSIS.md).
   The detection and the candidate entries ship; the proposals are shown in the *Explain* window and
   are copyable, so contributing one needs no new infrastructure. Nothing was wired, because each of
   the three routes costs something only David can weigh.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [A bounded, redacted excerpt out of what is on screen](FEAT-SUPPORT-LOG-ANALYSIS.md) | feat |
| 02 | [The Worker learns to serve more than one kind of client](FEAT-SUPPORT-LOG-ANALYSIS.md) | fix |
| 03 | [Explain: the catalogue first, ignorance admitted](FEAT-SUPPORT-LOG-ANALYSIS.md) | feat |
| 04 | [Unknown recurring patterns come back as proposed rules](FEAT-SUPPORT-LOG-ANALYSIS.md) | feat |
| 05 | [Prepare a report block the intake flow can read](FEAT-SUPPORT-LOG-ANALYSIS.md) | feat |
| 06 | [A door for pilots, not only mission makers](FEAT-SUPPORT-LOG-ANALYSIS.md) | docs |

---

## Tickets, in full

## 01 — A bounded, redacted excerpt out of what is on screen

Status: ✅ done

Type: feat

### The problem

An 11 MB log cannot be sent anywhere and cannot enter a model's context. But `veaf-logs` has
already done the hard part: the categories, the levels, the noise rules and the search context have
reduced the file to the handful of lines the user is looking at. Nothing turns that view into a
transmissible artefact — the tool exports nothing at all today, its only outputs being `Ctrl+C` and
`Ctrl+Shift+C` to the clipboard.

### What to build

A single function, used by the three tickets that follow: *from the current view, produce a bounded,
redacted, structured excerpt.*

- **Bounded**: a hard ceiling in characters, applied after selection, with the drop made visible
  (`… 412 lines omitted …`) rather than silent.
- **Structured**: each entry keeps its timestamp, source, level and subsystem — the model needs the
  shape, and so does a human reading the issue later.
- **Redacted**: the helper from
  [`FEAT-SUPPORT-DIAGNOSTIC` ticket 01](FEAT-SUPPORT-DIAGNOSTIC.md),
  applied here rather than reimplemented. Windows user paths, addresses, tokens.
- **Honest about what was hidden**: the excerpt states which categories were excluded, so nobody
  concludes from silence. A log filtered down to "no errors" because the user unticked ERROR must
  not read as a clean log.

### The trap next door

Context lines pulled in around a hit must not resurrect entries the categories set to ✕ — the
defect `FEAT-VEAF-LOGS-READABILITY` had to solve for search. The excerpt builder sits downstream of
the same machinery and inherits the same obligation.

### Definition of done

- [x] One entry point producing the excerpt from the current view state
- [x] Ceiling enforced, omissions stated in the output
- [x] Redaction applied, asserted on a Windows user path, an IPv4 address and a token-shaped string
- [x] Excluded categories declared in the excerpt header
- [x] Context lines never reintroduce an excluded category — asserted by a test that fails if the
      guard is removed
- [x] Unit tests on a synthetic log fixture, no GUI needed
- [x] `poetry run pytest`, ruff check + format, mypy clean

---

## 02 — The Worker learns to serve more than one kind of client

Status: ✅ done

Type: fix

### The problem

This lot is the first to add a second kind of client to the Worker, and the Worker's admission
control does not survive it.

**The header is the door.** `isAllowedClient`
([`poc/doc-chatbot/worker/src/index.js:282`](../../poc/doc-chatbot/worker/src/index.js)) reads:

```js
return cliHeader === "cli" || (!!origin && ALLOWED_ORIGINS.has(origin));
```

Any caller sending `X-VEAF-Client: cli` is admitted, whatever its origin — the browser allow-list is
bypassed entirely. The code documents this as non-secret and leans on the per-IP rate limit instead
([`worker_client.py:24`](../../src/python/veaf-tools/doc_chatbot/worker_client.py)). **This hole
predates the programme**; it is fixed here because this is the lot that starts relying on client
identity.

**The rate limit fails open.** `allowRequest`
([`src/index.js:98`](../../poc/doc-chatbot/worker/src/index.js)) counts per IP in KV — 10 per
minute, 100 per day — and its `catch` returns `true`. KV unavailable means no limit at all. The
read-then-write is not atomic and KV is eventually consistent, both acknowledged in comments; every
request without `CF-Connecting-IP` shares one `unknown` counter.

**And it will not survive the bot at all.** [`FEAT-SUPPORT-DISCORD-QA`](FEAT-SUPPORT-DISCORD-QA.md)
puts an entire Discord behind a **single IP**: 100 requests a day for everyone. That lot needs a
`discord` client mode whose quota is carried by the service, per Discord user. The groundwork is
here.

### What changes

- A declared client vocabulary (`web`, `cli`, `logs`, later `discord`) with per-client limits,
  instead of one header that opens everything.
- Admission that does not treat a self-declared header as proof.
- Rate limiting that **fails closed**, or degrades to a stricter local ceiling rather than to none.
- A route, or a mode, for log analysis: the request carries a bounded excerpt and the catalogue
  entries already matched locally, and gets back an explanation.
- A request body ceiling before `request.json()` — there is none today.

### Notes

- The Worker is deployed by hand (`npx wrangler deploy`); the CI workflow only rebuilds the KV
  index. Whatever ships here must be deployable without a pipeline, and say so.
- `poc/doc-chatbot/worker/test/unit.test.mjs` already covers `isAllowedClient`. Those tests move
  with the behaviour rather than being deleted.
- The free Gemini quota is the real ceiling behind all of this; per-client limits must keep the
  documentation widget working when another client misbehaves.

### Definition of done

- [x] Client modes declared, with a limit per mode
- [x] A self-declared header alone no longer grants browser-bypassing access
- [x] Rate limiting fails closed; a KV outage cannot remove the limit
- [x] Body size ceiling enforced before parsing
- [x] A log-analysis mode accepting an excerpt plus matched catalogue entries
- [x] Unit tests extended, including the fail-closed path and the body ceiling
- [x] Deployment steps written down in the Worker README, which is stale and gets refreshed here

---

## 03 — Explain: the catalogue first, ignorance admitted

Status: ✅ done

Type: feat

### The problem

A pilot or a mission maker looks at a wall of DCS log lines and cannot tell which one matters. The
tool knows more than it says: `rules.json` carries 22 known-noise patterns each with a `help` text,
13 sources and 8 native subsystem families — but that knowledge only drives colouring and hiding,
never an explanation.

### What to build

An *Explain* action on the current view. It works in two layers, and the order between them is the
whole design:

1. **The catalogue answers first.** Every entry matched by `rules.json` is rendered with its own
   verified wording, as-is. No model involved, no cost, works offline.
2. **The model puts it in context second.** It receives the bounded excerpt from
   [ticket 01](FEAT-SUPPORT-LOG-ANALYSIS.md) plus the catalogue matches, and it chains: what happened
   first, what is a consequence of what, which line is the one to act on. Where the catalogue is
   silent it answers **"pattern not catalogued"** rather than proposing a cause.

The free model, through the Worker mode added in [ticket 02](FEAT-SUPPORT-LOG-ANALYSIS.md).

### Why the order matters

The worst failure of this feature is not silence, it is a plausible wrong answer: *"it comes from
your module X"* when it does not. The reader has no way to tell a guess from a verified fact, and
will spend his evening on it. Rendering the catalogue verbatim, and marking everything else as
uncatalogued, is what keeps the two apart on screen.

It also has to work with no network: the catalogue layer alone is a useful answer, and that is the
degraded mode.

### Notes

- The rendering must visually separate *verified catalogue text* from *model commentary*. Not a
  disclaimer at the bottom — nobody reads those — but a distinction the eye catches per block.
- VEAF entries deserve depth: the excerpt carries the VEAF source and level parsing
  (`^VEAF(-[A-Z0-9]+)?\|(?P<lvl>[A-Z])\|`) that generic DCS lines do not have.
- No network, no `logs` extra installed, empty selection: all three must produce something sane.

### Definition of done

- [x] An *Explain* action on the current view, in `veaf-logs`
- [x] Catalogue matches rendered verbatim from `rules.json`, before any model output
- [x] Model output visually distinct, and stating "not catalogued" instead of guessing
- [x] Offline degraded mode: catalogue only, no error dialog
- [x] Unit tests on the assembly and on the degraded path, with the Worker mocked
- [x] `poetry run pytest`, ruff check + format, mypy clean
- [x] `--cov-fail-under` raised to stay within ~2 points of measured coverage

---

## 04 — Unknown recurring patterns come back as proposed rules

Status: ✅ done

Type: feat

### The idea

David's constraint on this flow was explicit: it must **not** create issues. That leaves a question
— if nothing is captured, the analyser never gets better, and every user pays for the same
"pattern not catalogued" answer.

The answer is to capitalise on the catalogue rather than on the tracker. A pattern that shows up
repeatedly and matches nothing in `rules.json` is a **missing catalogue entry**, and a proposed
entry is worth more than an issue: once merged, the next user gets a verified explanation with no
model call, offline, for free.

### What to build

- Recognise, inside one analysis, patterns that recur and match no rule — normalised so that
  addresses, identifiers and timestamps do not make two occurrences of the same message look
  different.
- Produce a **candidate entry** in `rules.json` shape: `id`, `label`, `help`, `match`, whether it is
  noise, which family it belongs to.
- Never apply it silently. A proposed rule is a proposal; the catalogue stays hand-curated, which
  is precisely what makes it trustworthy.

### Open question — the delivery channel

Undecided, and it is David's call (open question 2 of the PRD):

| Route | What it costs |
|---|---|
| Automatic PR on the repository | traceable and reviewable; needs a credential in a desktop tool, which is a hard no as written |
| A local file the user can send | zero infrastructure; depends on someone bothering |
| A message to a Discord channel | fits the programme, but only exists from lot 3 onwards |

The detection and the candidate-entry generation ship here regardless; the transport is wired once
the route is chosen.

#### Recorded as deferred, 2026-09-05

**No transport was wired, and that is deliberate.** The three routes are still exactly as costed
above and the choice is David's, not the implementer's: an automatic PR needs a credential in a
desktop tool, which the ticket itself calls a hard no; a local file depends on someone bothering;
and the Discord channel does not exist before lot 3. Picking one to close a checkbox would have
built the wrong one.

What ships is the proposal, rendered where the user already is: the *Explain* window shows the
candidate entries under **PROPOSITIONS DE RÈGLES**, in `rules.json` shape, and the whole analysis is
copyable. Someone who wants to contribute one can paste it into an issue today with no new
infrastructure — which is also, in practice, route 2 minus the file.

Measured on the real logs, the volume this has to carry is small: 1 to 5 proposals per log across
the live `dcs.log` and its 18 rotated archives.

### Definition of done

- [x] Recurrence detection over normalised messages, unit-tested on a fixture where the same error
      appears with varying identifiers
- [x] Candidate entries generated in `rules.json` shape, with a valid `match` regex
- [x] Generated regexes validated before being offered — an unanchored or catastrophic pattern is
      rejected rather than proposed
- [x] Nothing is written to `rules.json` automatically
- [x] The chosen delivery route implemented, or explicitly recorded as deferred with the reason
- [x] `poetry run pytest`, ruff check + format, mypy clean

---

## 05 — Prepare a report block the intake flow can read

Status: ✅ done

Type: feat

### The idea

The moment the analyser says *pattern not catalogued* is the moment the user is both most motivated
to report and best equipped to do it: he has the log open, the filter applied, and he has just
learned the problem is unknown. Making him start again from a blank Discord message throws all of
that away.

### What to build

A *Prepare a report* action that assembles, in one block:

- the output of `veaf-tools doctor` ([`FEAT-SUPPORT-DIAGNOSTIC` ticket 01](FEAT-SUPPORT-DIAGNOSTIC.md)),
- the bounded, redacted excerpt from [ticket 01](FEAT-SUPPORT-LOG-ANALYSIS.md),
- the catalogue matches and what the analysis concluded, including what it could not explain.

Copied to the clipboard, ready to paste into `/bug`. That block **is the contract** between this
lot and [`FEAT-SUPPORT-BUG-INTAKE`](FEAT-SUPPORT-BUG-INTAKE.md): versioned, parseable,
and documented on both sides.

It also settles the 11 MB problem for good — what travels is an excerpt the machine already bounded,
not a file nobody can upload.

### Notes

- This is a **paste**, not a transmission. Sending straight to the service would require pairing a
  desktop install with a Discord account, an authentication mechanism the project does not have and
  that this programme deliberately does not build.
- The block must survive a round trip through Discord's Markdown — code fences, no character that
  breaks the rendering, a length that does not exceed a message.
- If it does exceed it, the block says so and states what was trimmed, rather than being silently
  cut at the boundary.

### Definition of done

- [x] A *Prepare a report* action producing the assembled block on the clipboard
- [x] Block format versioned and documented, in a place the intake lot can point to
- [x] Fits a Discord message, or states its own truncation
- [x] Redaction verified on the assembled block, not only on its parts
- [x] A round-trip test: the block is parsed back and yields the fields the intake flow expects
- [x] `poetry run pytest`, ruff check + format, mypy clean

---

## 06 — A door for pilots, not only mission makers

Status: ✅ done

Type: docs

### The problem

This lot targets *a mission maker or a pilot*. But `veaf-logs` is documented in
[`doc/mission-maker/LOGS.md`](../../doc/mission-maker/LOGS.md) and nowhere else: a pilot with a
crashing DCS has no reason to open the mission-maker section, and will never learn the tool exists.
Half the intended audience cannot find the feature.

### What to write

- A pilot-facing entry point — a section in [`doc/pilot/GUIDE.md`](../../doc/pilot/GUIDE.md), or
  a page of its own — saying: *DCS misbehaves, here is a tool that reads its log and explains it.*
  Written for someone who has never run a VEAF command line.
- The analysis feature documented where the tool itself is documented, including what it does
  **not** do: it explains, it does not repair, and outside the catalogue it says so.
- The link from the support page created in
  [`FEAT-SUPPORT-DIAGNOSTIC` ticket 03](FEAT-SUPPORT-DIAGNOSTIC.md).

The shape of the pilot door is open question 1 of the PRD — section or standalone page is David's
call, and worth asking before writing.

### Notes

- Both languages in lockstep, both in the `nav` with their `nav_translations` entry.
- Explicit English anchors on anything linked from another page.
- PowerShell examples, `.\veaf-logs.exe`.

### Definition of done

- [x] A pilot-facing entry point exists and is reachable from the menu, both languages
- [x] The *Explain* and *Prepare a report* actions documented, with their limits stated
- [x] Cross-links with the support page, both directions
- [x] `poetry run docs-check` passes

---
