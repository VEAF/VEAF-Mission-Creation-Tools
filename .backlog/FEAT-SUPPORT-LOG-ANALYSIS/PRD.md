# FEAT-SUPPORT-LOG-ANALYSIS — explain a DCS log where the log actually is

Status: ✅ done

Origin: design session of 2026-09-05. David's second idea: an analyser that handles **any** DCS
problem — not only VEAF ones, though it should be especially good on VEAF missions — to help a
mission maker or a pilot, **without** creating an issue. Lot 2 of the five-lot programme described
in [`FEAT-SUPPORT-DIAGNOSTIC`](../FEAT-SUPPORT-DIAGNOSTIC/PRD.md).

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
  [`FEAT-SUPPORT-DIAGNOSTIC` ticket 01](../FEAT-SUPPORT-DIAGNOSTIC/tickets/01-doctor-command.md).
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

   **Still undecided, and recorded as deferred** in [ticket 04](tickets/04-proposed-catalogue-entries.md#recorded-as-deferred-2026-09-05).
   The detection and the candidate entries ship; the proposals are shown in the *Explain* window and
   are copyable, so contributing one needs no new infrastructure. Nothing was wired, because each of
   the three routes costs something only David can weigh.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [A bounded, redacted excerpt out of what is on screen](tickets/01-bounded-excerpt.md) | feat |
| 02 | [The Worker learns to serve more than one kind of client](tickets/02-worker-multi-client.md) | fix |
| 03 | [Explain: the catalogue first, ignorance admitted](tickets/03-explain-catalogue-first.md) | feat |
| 04 | [Unknown recurring patterns come back as proposed rules](tickets/04-proposed-catalogue-entries.md) | feat |
| 05 | [Prepare a report block the intake flow can read](tickets/05-report-block.md) | feat |
| 06 | [A door for pilots, not only mission makers](tickets/06-doc-pilot-door.md) | docs |
