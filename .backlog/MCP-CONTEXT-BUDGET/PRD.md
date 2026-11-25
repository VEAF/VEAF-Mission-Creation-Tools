# MCP-CONTEXT-BUDGET — a local model at ~65 000 tokens runs a whole mission through the MCP

Status: 🧑 waiting-human — done in the code; waits for David's run with the local model (llama-server), then the PR

Origin: David, 2026-11-25. He prepares a tutorial for pilots who are not developers: they generate DCS missions with `veaf_mission_mcp`, driven by a local model (Inkling-2-Mini, Q4, `llama-server`, 24 GB cards).
No setting, no workaround may be asked of them.

## What was measured (2026-11-25)

The reference chain — authoring guide, known limitations, catalogue, `scaffold_mission` (`standard`, Caucasus), adapting the skeleton, `create_combat_zone`, `validate_mission`, `build_mission`, `inspect_built_mission` — replayed over stdio against the MCP, every call's text counted:

| Item | Characters |
|---|---|
| `describe_authoring_guide` | 41 555 |
| `describe_known_limitations` (short listing) | 13 008 |
| `list_catalog` | 14 701 |
| Reading the skeleton (8 `read_mission_file`) | 68 759 |
| `build_mission` (whole log) | 14 004 |
| Seven `describe_action` | 15 841 |
| **Whole chain** | **177 186** (44 000 to 59 000 tokens) |

On David's machine, a context of 49 152 tokens filled while reading the skeleton; one of 81 920 reached 82 363 before `validate_mission`.

## Decision (David, 2026-11-25: "go, a à f tels quels")

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Compact JSON in one block, and a ceiling on every response in the compact profile](tickets/01-compact-and-capped-responses.md) | ✅ |
| 02 | [A shorter catalogue, limitations listing, file slice and build log](tickets/02-shorter-listings.md) | ✅ |
| 03 | [The guide and the mission prompts read by section](tickets/03-guide-and-prompts-by-section.md) | ✅ |
| 04 | [`adapt_scaffold`: steps 1 to 5 of the guide in one action](tickets/04-adapt-scaffold.md) | ✅ |
| 05 | [A budget test on the reference chain: 60 000 characters at most](tickets/05-budget-test.md) | ✅ |
| 06 | [Documentation, changelog](tickets/06-docs.md) | ✅ |

## Constraints

- Nothing regresses for a large-context client (Claude Desktop): behaviour added, not replaced. The whole guide, a whole prompt, the whole catalogue stay one explicit parameter away.
- One PR for the lot, `pr-code-review` before the merge.

## Definition of Done

- The reference chain stays under 60 000 characters of tool output, schema of the tools included, pinned by a test.
- The guide's post-scaffold section and the mission prompts send the model to `adapt_scaffold` instead of asking it to rewrite the files.
- Docs in both languages, CHANGELOG under `[Unreleased]`.

## Outcome — 2026-11-25

The same chain replayed over stdio after the lot (scaffold copied, build and inspection real): **56 329 characters**, tool schemas included (14 000 to 19 000 tokens), against 177 186.
The largest answers left: `list_catalog` 10 202, the guide's `combat-zone-vs-qra` section 7 549, the guide's default answer 7 515, `build_mission` 5 826.
In process, `test_context_budget.py` counts 56 721 and fails at a budget of 50 000.
Not verified here: the run with the local model itself, which is David's.

## Second round — 2026-11-25, after the first local run

David's run (Inkling-2-Mini UD-IQ4_XS, `llama-server` b12728, 65 536 tokens) reached the build, then overflowed: one unfiltered `describe_units` on the built `.miz` was 74 417 characters, cut to 16 000, about 9 500 tokens at the 2 characters a token measured on JSON; the model itself generated 20 147 tokens.
Decided with David (relayed by the local-model session): two profiles, `standard` the default and unchanged for large-context clients, `compact` chosen by `VEAF_MCP_PROFILE` in the MCP configuration; in compact, an 8 000-character ceiling (16 000 for a schema), 60-character catalogue summaries, 7 000-character prompt pages, 6 000-character file slices; `describe_units` tells how to filter; `create_combat_zone` tells to use alias carriers (the run placed literal T-72B3).
Compact chain, in process: 54 634 characters.
