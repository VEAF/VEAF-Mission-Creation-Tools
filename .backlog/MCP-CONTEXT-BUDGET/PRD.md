# MCP-CONTEXT-BUDGET — a local model at ~65 000 tokens runs a whole mission through the MCP

Status: 🔄 in-progress

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
| 01 | [Compact JSON in one block, and a 16 000-character ceiling on every response](tickets/01-compact-and-capped-responses.md) | 🔄 |
| 02 | [A shorter catalogue, limitations listing, file slice and build log](tickets/02-shorter-listings.md) | 🔄 |
| 03 | [The guide and the mission prompts read by section](tickets/03-guide-and-prompts-by-section.md) | 🔄 |
| 04 | [`adapt_scaffold`: steps 1 to 5 of the guide in one action](tickets/04-adapt-scaffold.md) | 🔄 |
| 05 | [A budget test on the reference chain: 60 000 characters at most](tickets/05-budget-test.md) | 🔄 |
| 06 | [Documentation, changelog](tickets/06-docs.md) | 🔄 |

## Constraints

- Nothing regresses for a large-context client (Claude Desktop): behaviour added, not replaced. The whole guide, a whole prompt, the whole catalogue stay one explicit parameter away.
- One PR for the lot, `pr-code-review` before the merge.

## Definition of Done

- The reference chain stays under 60 000 characters of tool output, schema of the tools included, pinned by a test.
- The guide's post-scaffold section and the mission prompts send the model to `adapt_scaffold` instead of asking it to rewrite the files.
- Docs in both languages, CHANGELOG under `[Unreleased]`.
