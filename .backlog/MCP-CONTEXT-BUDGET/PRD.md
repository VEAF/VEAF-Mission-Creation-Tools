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
| 05 | [A budget test on the reference chain: 50 000 characters at most](tickets/05-budget-test.md) | ✅ |
| 06 | [Documentation, changelog](tickets/06-docs.md) | ✅ |

## Constraints

- Nothing regresses for a large-context client (Claude Desktop): behaviour added, not replaced. The whole guide, a whole prompt, the whole catalogue stay one explicit parameter away.
- One PR for the lot, `pr-code-review` before the merge.

## Definition of Done

- The reference chain stays under 50 000 characters of tool output, schema of the tools included, pinned by a test.
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

## Third round — 2026-11-25, after the fourth local run

Run 4 (compact profile, 7cdcda37) went through the whole chain and overflowed during the final answer (63 954 + 1 582 = 65 536). The call log (`E:\AI\mcp-calls.log`, the local-model session's proxy): 62 calls, 106 857 characters; 19 `describe_action` were 30 555 of them. Done: a `recipe` section of the guide, the calls of a simple mission each with its JSON, in the compact default answer; `create_combat_zone` takes `command` and names the carrier unit, moves a marker written in the group's name, and restores quotes escaped twice (the run wrote real backslashes before the marker's quotes); `adapt_scaffold` takes `language`. The empty `list_shortcuts` of the run came from the test copy, which held `src/python` only: without `src/scripts/veaf/veafShortcuts.lua` there is no `#command` alias. Compact chain, in process: 41 602 characters; the budget test now stops at 50 000.

Run 5 (compact, 572ae26d, a full copy with `src/scripts`): the mission built and the final answer fit, 40 000 of 65 536 tokens at the end; 38 calls, 73 141 characters, no error; carriers named `#command="-armor" CZ-Beslan-armor-1`, no backslash.
The model still read 7 guide sections and 15 schemas before its first action (about 46 000 characters): the compact default answer now says plainly that the recipe is enough for a simple mission.
The run's `describe_known_limitations` differed from the installed 6.39.1 because the development venv reports 6.36.0: three entries fixed since stay listed. The code and the branch's base are not in cause.
Run 6 (compact, 55634a78), asked for "a modern training mission" with a zone, a SA-8 and a QRA: the model loaded the Open Training prompt (12 pages, 77 622 of 113 885 characters) and filled 96 % of the context with a plan and questions, building nothing.
The compact default answer now opens on `start_here`: a request that says what the mission holds is a simple mission whatever word it uses, the recipe serves it, a mission prompt is loaded only when the user plainly wants one, with each prompt's weight; a missing detail gets a sensible value rather than a question.
A condensed Open Training prompt for the compact profile is not done: to weigh after a run on this commit.

Run 7 (compact, c1e607e8), a mission with player slots, a zone with a SA-8 and a QRA: everything built and checked, then the context overflowed by 78 tokens before the final answer. The model had read the catalogue first and gone to `describe_mission_prompt` before the guide's routing. Done: compact summaries in `list_catalog` for `describe_mission_prompt` and `describe_authoring_guide`; the compact guide's default answer without the first-message section, which contradicted `start_here`; a QRA step in the recipe; `list_payloads` by name only in compact; `type_contains` and `which` read as `name_contains` and `file`. The `opposition: level: 0` the run left with `scale_with_opposition` is not a QRA kept on the ground: `veafOpposition.configure` leaves `noAircraft` false, only a 0 fixed from the menu or the marker (`fixLevel`) switches the fighters off. Compact chain with a QRA, in process: 42 159 characters.

Run 8 (compact, 6b8696ce), the same request: the first complete final answer, with 731 tokens to spare; no mission prompt read, no question asked. The SA-8's carrier was a T-72B, copied from the recipe's example. Done: `create_combat_zone` without `units` places a carrier of the class the alias spawns (`alias_carrier_type`), and the recipe gives none; in compact, `build_mission` drops its step lines (5 083 → 4 064 characters on run 8's build) and `inspect_built_mission` counts its lists (2 878 → 1 281, `detail: true` lists them). Not done: `describe_action` schemas shortened in compact (their descriptions carry warnings a mission's correctness depends on); `set_airbase_coalition` limiting a base to some aircraft types (`warehouses.yaml` `airports:` would close the coalition's other bases: a design question). Compact chain with a QRA, in process: 38 826 characters.

Run 9 (compact, f48dcb23): complete, 6 720 tokens to spare (58 810 of 65 536); the SA-8's carrier an `Osa 9A33 ln`. Its heaviest item: five slices of `src/dynamic-slot-templates.yaml`, 31 384 characters, read to find the F/A-18C the request named. Done: `adapt_scaffold` `dynamic_slot_aircraft` keeps only the templates of the aircraft named, refused before writing when the catalogue lacks one; the recipe passes it; `module` is read as `module_id`.
