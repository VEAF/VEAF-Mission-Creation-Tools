# FEAT-ASSIST-AUTHORING — checklists an instructor can write without knowing DCS internals

**Status:** 🔄 in-progress — opened 2026-08-02, scoped with David the same day. Tickets 01, 02, 03, 06 and 07 done as of 2026-08-03, 04 built and awaiting one cockpit run; 05 needs modules nobody here owns. Ticket 08 added 2026-08-03 out of using 04 by hand.

## The problem

[FEAT-ASSIST-CHECKLISTS](../FEAT-ASSIST-CHECKLISTS/PRD.md) shipped an engine that works. Writing a
checklist for it does not: a step needs `element: PTR-ELEC-TMB-MPWR-510` and `argument: 510` and
`equals: 1.0`, and getting those three right means opening `clickabledata.lua` and `clickable_defs.lua`
inside a DCS installation and reading Lua. An instructor who knows the aircraft cold has no reason to
know any of that, and the six steps of the shipped F-16C checklist cost more research than they look
like.

The whole point of the engine is that a checklist is data. If only a developer can write that data,
the feature has one author.

## What an instructor writes

The same file, with one extra field and no technical knowledge:

```yaml
steps:
  - label: MAIN PWR sur MAIN PWR
    control: bouton power sur main pwr
```

`control` is free text naming a cockpit control and the position it should be in. A resolution pass
fills in the technical fields **in the same file**, in place:

```yaml
  - label: MAIN PWR sur MAIN PWR
    control: bouton power sur main pwr
    # ── filled in by `veaf-tools resolve-checklist`, do not hand-edit ──
    element: PTR-ELEC-TMB-MPWR-510
    argument: 510
    equals: 1.0
    tolerance: 0.05
    resolved_from: bouton power sur main pwr
```

**One file, not two.** David's call, and it is the right one: a generated second file would have to
be kept in sync with the first, and the instructor would end up maintaining the one they understand
least. Here the instructor owns the file, edits `control` when they want, and re-running the
resolution touches **only** the steps where `resolved_from` is missing or no longer matches `control`.
Everything already resolved is frozen, so the diff of a re-run is exactly the steps that changed.

## Is it resolvable? Measured, yes — with one hard spot

`clickabledata.lua` for the F-16C, parsed on 2026-08-02:

- **284 elements**, every one of them with its animation argument recoverable;
- **131 (46 %)** name their positions in their own hint: `MAIN PWR Switch, MAIN PWR/BATT/OFF`,
  `Throttle, OFF/IDLE`;
- the prototype of each is known, so its value range is too.

So "throttle sur idle" → element and argument is a solved problem. **The value is not**, and this is
the hard spot: the order of the positions in a hint is not reliable.

| Hint | Real order |
|---|---|
| `MAIN PWR Switch, MAIN PWR/BATT/OFF` | +1 / 0 / **−1** — descending |
| `DIGITAL BACKUP Switch, OFF/BACKUP` | 0 / 1 — ascending |

A resolver that infers the value from the rank in the list is wrong roughly half the time, silently.
That single fact shapes the whole design below.

## Who resolves

Three layers, and **the build never depends on a language model**:

1. **A deterministic command** does the matching against the extracted index — normalise, match
   words, score. It handles the ordinary case and is reproducible: a checklist must rebuild
   identically in two years.
2. **It fails loudly with its candidates** when a name is ambiguous, unknown, or when the value
   cannot be derived. "bouton power" matches no hint containing "power"; that is a question for a
   human or an assistant, once, not a guess.
3. **In-game verification** settles what neither can: reading the real argument with the control in
   the wanted position, which [ticket 10](../FEAT-ASSIST-CHECKLISTS/tickets/10-switch-position.md)
   made possible. `a_cockpit_perform_clickable_action` can even throw the switch, so the loop can run
   without a pilot touching anything.

## Where the procedures come from

| Source | For | Notes |
|---|---|---|
| `Macro_sequencies.lua` | the five modules shipping an autostart | ED's own order and wording, already used for the F-16C |
| [Heatblur's official F-14 manual](https://f14.manuals.heatblur.se/f14bu.html) | F-14B(U) | HTML, public, and already in `CONTROL — POSITION` form: *"ENG CRANK switch — Set to R"*, *"Right throttle — Advance to IDLE at 20% RPM"* |
| Chuck's Guides | anything without either | Only as a **source of the procedure**, per the call already recorded in FEAT-ASSIST-CHECKLISTS: the sequence is a technical fact from the aircraft manual and using it is fine; his text and screenshots are not copied and the PDF does not enter the repo |

David has no Chuck's guide for the F-14B(U) — his is the 2023 F-14B — which is moot, because the
official manual is better and covers the exact variant.

## Out of scope

- Generating whole checklists unattended. The resolution proposes; a human ships.
- Aircraft whose module is not installed on the machine running the extraction. The index is derived
  data, versioned like `dcsUnits.yaml`, and only grows when someone with the module regenerates it.
- Translating an instructor's `control` text. It is a lookup key, not pilot-facing; `label` is what
  the pilot reads and it already takes inline translations
  ([ticket 09](../FEAT-ASSIST-CHECKLISTS/tickets/09-inline-translations.md)).

## Known limit carried over

`argument` steps read through **Export.lua's** environment, which runs on the pilot's machine. On a
dedicated server they very likely never self-validate — untested, and the API's own shape argues for
it: `GetDevice(0):get_argument_value(arg)` takes no unit, so there is nothing to designate a given
client with. The practical rule for instructors, to be written in the documentation: **`argument` for
solo and local training, `param` and `confirm` for a mission meant for the server.** A bomb run stays
automatic everywhere, since altitude, speed and heading come from the `Unit` API.

## Tickets

| # | Ticket | Depends on |
|---|---|---|
| 01 | [Extract the cockpit-control index, per aircraft](tickets/01-control-index.md) | — |
| 02 | [The instructor format: `control`, enriched in place](tickets/02-instructor-format.md) | 01 |
| 03 | [`resolve-checklist`: match, or fail with candidates](tickets/03-resolver.md) | 01, 02 |
| 04 | [Verify a resolved checklist in game](tickets/04-in-game-verification.md) | 03 |
| 05 | [The five aircraft that ship an autostart](tickets/05-autostart-aircraft.md) | 03 |
| 06 | [F-14B(U), from Heatblur's official manual](tickets/06-f14b-manual.md) | 03 |
| 07 | [Document it for instructors](tickets/07-documentation.md) | 05, 06 |
