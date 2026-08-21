# FEAT-SPAWN-OPTION-VALIDATION — a mistyped option is silently ignored

Status: ✅ done

Shipped in 6.15.18. Closed outright: every claim is covered by unit tests and nothing needs DCS.

Origin: [#33](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/33), open since 2021.

## This PRD was wrong about the starting point

It said `veafSpawnParser.lua` has no unknown-option path, *"grepped for 'unknown option', 'invalid' and
'unrecognized': zero"*. The mechanism exists, and has since **UXPILOT-003** (archived ✅): the collector
lives in `veaf.parseMarkerText`, keys come back in `options.unknownParameters` with a nearest-match
`suggestion` from `veaf.nearestMatch`, and `veafSpawnCore` reports them to the placing pilot in a single
i18n message. The grep missed it because nothing is called "unknown option" — the code says
`reportUnknownKeys` and "typo hints".

**What was actually missing:** `reportUnknownKeys = true` appeared **once** in the whole runtime. Seven
other marker specs never switched it on, so `_spawn` was the only command in the product that told a
pilot about his typo. That is the real gap, and it is exactly what the DoD's *"every marker command
benefits, not only `_spawn`"* asked for — without knowing the rest already existed.

## Measured before touching anything

Switching the flag on blindly would warn pilots about **valid** options wherever a spec's rules do not
declare everything its command accepts. Measured by forcing the flag on and running a corpus of **228
valid marker texts** harvested from the test suites:

| Spec | Keys flagged on valid commands | Verdict |
|---|---|---|
| `veafCasMission`, `veafMove`, `veafRadio`, `veafTransportMission`, `veafGroundAI` | 0 (only the suites' deliberate `banana`) | switched on |
| `ArtilleryUnitHandler.OrderSpec` | 9 of 9 orders — the bare verbs `aim` / `fire` read as keys | switched on **after** the repair below |
| `veafShortcuts.AliasParameterSpec` | **52** | left off, deliberately |

`veafShortcuts` is excluded by design, not by omission: an alias carries the parameters of the command it
expands into (`size`, `defense`, `freq`, …) and declares only the three it consumes itself. A test pins
the exclusion so it reads as a decision rather than an oversight.

## The repair a command verb needed

`_spawn`-style keyphrases escape the collector because it skips keys starting with `_`. A bare verb does
not, which is why every artillery order was flagged. `veaf.prepareMarkerSpec` now adds each
`commands[].match` to the known-key set — a verb names the command, it is not an option someone
mistyped. An empty match is skipped, since `veafShortcuts` uses `match = ""` to mean "always".

**A gain nobody asked for:** an artillery order written with a comma instead of the semicolon it requires
now reports `'aim,'` with `aim` suggested. It used to lose the rest of the order in silence, which is
also the honest answer to "why a semicolon?" — the order travels as the *value* of an `order` key inside
a marker already split on commas.

## Scope, as decided

Collect unrecognised keys while parsing and name them on screen, with the module that refused.

**Warn and ABORT**, David's arbitration 2026-08-21 — not "warn and run anyway" as this PRD first
proposed. That proposal was written believing nothing existed; `_spawn` has aborted since UXPILOT-003
with its reason recorded in the code (*"a typo must never silently spawn something the pilot did not
intend"*), and two behaviours in one product is worse than either one. The marker is left in place so the
pilot can fix it.

The report moved out of `veafSpawnCore` into `veaf.reportUnknownParameters`, or the block would have been
copied six times. Its i18n keys moved with it, `spawn.*` → `marker.*`, and the module name became a
parameter instead of being baked into the sentence.

## Definition of done

- [x] An unknown option is named on screen — and the command aborts, per David's arbitration, so the
      recognised options deliberately do **not** apply
- [x] Every marker command benefits, not only `_spawn` — six specs switched on, the seventh excluded
      with a measured reason
- [x] Tests: an unknown option is reported, and valid options are never reported (the witness) — the
      228-text corpus above is that witness, and `veafShortcuts`' exclusion is pinned by a test
