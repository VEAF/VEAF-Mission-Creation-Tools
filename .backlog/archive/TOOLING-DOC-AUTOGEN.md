# Lot TOOLING-DOC-AUTOGEN — check the references against the code instead of generating them

Status: ✅ done

Origin: [`docs/exploration/DCS-SMS-EXPLOIT.md`](../../docs/exploration/DCS-SMS-EXPLOIT.md) §3.

**Branch** → [#660](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/660) → `develop`

> **This lot changed mechanism on 2026-08-05, before any code was written.** It was scoped as
> *generate two references*. Both premises turned out to be wrong, and generating would have destroyed
> curated content. It shipped as a **drift check** instead. The reasoning is kept because the wrong
> version is the tempting one and the next person will think of it again.

| # | Ticket | Status |
|---|--------|--------|
| 01 | Coverage check instead of an ALIASES generator | ✅ |
| 02 | Coverage check instead of an MCP catalogue generator | ✅ |
| 03 | CI freshness gate | ✅ |

## Why generation was wrong, on measurement

`docs-check` validates that links resolve and anchors exist; it cannot tell whether a reference still
*describes the code*. `DOC-AUDIT-PASS` had found a stale `addSubMenu` signature and a "6.5.25 / June
2026" header in `LUA_API_REFERENCE` — silent rot. `dcs-sms` regenerates its 141 CLI pages and fails a
`cli-docs-fresh` job when the committed result differs; that **mechanism** looked worth having.

Checking the two named targets first — which ticket 01 demanded — showed both were mis-scoped:

| Claimed | Measured |
|---|---|
| `ALIASES.md` is a rendering of `veaf-units.yaml` | **Wrong source.** That YAML holds *spawn* units and groups; the marker aliases live in `veafShortcuts.lua`, registered at runtime through `VeafAlias:new():setName(…)`. |
| …with no prose to lose | **There is prose**: thematic French sections, a hand-written description per alias, a Notes column. |
| The MCP catalogue page is derivable from `list_catalog()` | `AI_ASSISTANT_CATALOG.md` is 367 lines written **for mission makers in natural language**, and says outright you need not know the technical names — only 3 of the 29 appear. Its editorial frequency column and recipe-versus-`.miz` framing exist nowhere in the data. |

Generating either would have replaced a document people read with a table nobody needs. The PRD had
already argued exactly that for `LUA_API_REFERENCE`, then made the same mistake one paragraph later.

## What shipped instead

A **coverage check**: every name the code defines must be mentioned by the page documenting it. It
guards the risk that actually matters — a capability shipped and the documentation never following —
and is indifferent to how the surrounding prose is written. Both rules were proven by live drift found
while measuring:

| Source | Page | Found |
|---|---|---|
| 29 MCP actions | `doc/developer/mission-editing-mcp.{md,en.md}` | **`set_airbase_coalition`** missing from both — shipped by `FEAT-MCP-AIRBASES-WAREHOUSES`, never written up |
| 128 marker aliases | `doc/ALIASES.{md,en.md}` | **5** missing from both |

The *technical* MCP page is the right target, not the mission-maker one: it names 28 of 29, so it is
the document that means to be exhaustive.

## The `hidden` concept: investigated, nearly deleted, then repaired

The 5 undocumented aliases all carried `:setHidden(true)`, which looked like a deliberate exemption.
David asked what the flag was actually for. **The answer took three passes and the first two were
wrong:**

1. **"It is dead."** Its original consumer — the `veafShortcuts` F10 menu and its
   `if not a:isHidden() then` — was deleted in `ca962e4b` (23 June 2021). Nothing in the **Lua** had
   read it since. On that basis the concept was removed.
2. **Wrong: it has a Python consumer.** `veaf_shortcuts_scanner.py` greps `:setHidden(true)` out of
   the Lua to build the list the **`list_shortcuts` MCP action** serves to an AI assistant. The grep
   had only covered Lua. The removal was reverted.
3. **And that consumer was being bypassed.** `get_shortcuts()` prefers a pre-generated JSON over
   scanning, and the local `veaf-shortcuts.json` had drifted to 128 entries while the parser produced
   123 — so the exclusion never applied, `-login` *was* being offered to agents, and
   `test_surfaces_samlr_not_hidden_login` had been **red on this workstation while CI stayed green**.

So the defect was never the concept: **a stale generated artefact was silently overriding its own
generator.** Repaired — JSON regenerated (123), the red test green, a new test comparing the artefact
against a fresh scan when present, and the Lua comment corrected to name the consumer that exists
rather than the menu deleted in 2021.

The five are additionally **documented for humans**. The two audiences differ and conflating them was
the original error: not offering an auth command to an AI building a mission is sound; hiding it from a
public reference whose code is public protects nothing.

## Definition of Done

- The check reports zero on `develop`, having reported **12** before the fixes.
- Names are read with a regex, **not imported**: the CI job runs the module with plain `python` and no
  Poetry install, which keeps it seconds long. A pytest test asserts the regex and the real
  `list_catalog()` agree — **the cheap gate is itself gated by the expensive one**.
- CI triggers on the **sources**, not only on `doc/` — otherwise the gate is blind to the exact commit
  it exists to catch.

## Out of scope, and this stands

`LUA_API_REFERENCE.md` (118 KB), `MISSION_YAML_REFERENCE.md` (39 KB) and `PIPELINE_REFERENCE.md`
(31 KB) are prose explaining behaviour, caveats and in-game consequences — neither generated nor
coverage-checked, because their content is not a list of names. Extracting *signatures* from
`LUA_API_REFERENCE` and checking them against the source is a plausible later lot, and a different one.

> **Stale line in the original PRD**: its Definition of Done said "the Lua unit tests cannot run on
> this machine (no Lua 5.1 since FIX-LUA-RUNNER-VERSION-CHECK) — CI is the gate". That was true on
> 2026-08-06 and is **no longer**: Lua 5.1.5 is installed on `DAVID-BUREAU` and the 36 suites run
> locally.
