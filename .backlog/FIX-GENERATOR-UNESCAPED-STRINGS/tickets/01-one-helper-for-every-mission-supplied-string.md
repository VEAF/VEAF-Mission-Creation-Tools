# 01 — One helper for every mission-supplied string, and the reason for each site that keeps none

Status: ✅ done
Type: fix

## What was wrong

`lua_config_generator` wrote mission values into generated Lua by interpolating them into a
double-quoted literal: `f'{indent}    :setZoneCenterFromCoordinates("{coords}")'`. Whatever the value
contained went in raw. A DCS coordinate written with seconds contains a `"`, so it closed the literal
and the file stopped being Lua after that character.

**The helper already existed.** `veaf_libs/lua_literals.py` was written for exactly this in the
2026-07-01 security review (VMR-010 / VMR-012), and the generator already imports it — under the
private aliases `_emit_lua_string` and `_lua_long_string` — for briefings, radio-menu labels and
named points. The defect is not a missing helper; it is fifty-odd sites that never adopted it, next
to a dozen that did. So the work here was routing, not designing.

## The enumeration

Counted with an **AST walk**, not a regular expression over `lines.append(f…)`: an expression counts
when it is a `FormattedValue` sitting between an odd and an even `"` of the surrounding f-string's
literal parts. That catches concatenations, assignments and multi-line f-strings the line-based count
misses.

**59 expressions, in 54 statements** — the PRD said 31, which is what the line-based count sees.

After the change, **7 remain**, every one of them with a reason:

| Remaining site | Expression | Why it needs no escaping |
|---|---|---|
| `mission_identity_section` | `live_name` | Emits a line of **`mission.yaml`**, not Lua. Quoting it as a Lua literal would corrupt the scaffold. |
| `generate_mission_yaml_template` | `mid` | Same: a `mission.yaml` key, and a module id besides. |
| module `setConfig` block ×4 | `mod_id` | Not a YAML key: the loop runs over `_MODULE_INIT_ORDER` plus the ids `get_modules()` knows, so a value the mission maker invents is dropped before this line. A closed set the generator owns. |
| community-script block | `sid` | Same, from `get_community_script_files()`. |

The other 52 are routed. Two destinations, because the position decides:

* `_lua_text` → `lua_string`, for every value in an argument or a right-hand side. It prefers a long
  string when the value needs escaping, which keeps generated configuration readable — a briefing
  emerges as `[[…]]` rather than a wall of `\n`.
* `_lua_key` → `lua_quoted_string`, for the three `veafSecurity.password_*[…]` table keys **only**.
  A long string in an index position produces `t[[[value]]]`, which Lua's lexer reads as `t` called
  with the long string `[value` followed by a stray `]`. An index always gets the escaped `"…"` form.

## The site quoting cannot fix

`_emit_combat_zone_def` writes a v6-migration hint into a Lua **comment**. A `--` comment ends at the
first line break, so a zone name carrying one pushes the rest of itself out of the comment and into
the file as code — and there is nothing to quote inside a comment. `lua_literals.lua_comment_line`
folds the line breaks out; it sits beside the quoting helpers because it answers the other half of
the same question.

## Out of scope, found by the same sweep

The enumeration was run over the whole Python tree, not just the generator. Two sites outside it write
Lua the same way and are **not** touched here — they belong to the MCP editing surface rather than the
build:

* `veaf_mission_mcp/edit_veaf_config.py:56-57` — `module_id` is interpolated into both a regex and a
  generated `veaf.setConfig(…)` line.
* `veaf_mission_mcp/edit_veaf_config.py:126` — `_lua_value` escapes the backslash and the quote but
  **not the newline**, so a multi-line value still produces a broken literal.

One more, inside the generator but outside this family: a `settings:` key is written as a bare Lua
name (`veaf.config.{key} = …`), so a quote in one is a syntax error rather than a quoting problem.
Ticket 02's guard catches it, and it is what ticket 02's test uses to prove the guard fires.

## Tests

`test/python/veaf_libs/test_lua_config_escaping.py` drives one value — `quote " backslash \ newline`
plus a second line, the three characters that break a Lua string literal in one string — through
**52 free-text fields**, and asks two questions of each: does the file parse, and did the value arrive
whole. 104 of the 105 tests in the file were red before the change.

Both were proven able to fail:

| Sabotage | Effect |
|---|---|
| `{_lua_text(coords)}` back to `"{coords}"` | 4 red, including the end-to-end build test |
| `lua_string` strips `"`, `\` and newlines instead of quoting them | 5 red — the file still parses, the preservation test catches it |
| `lua_comment_line` returns its input | 2 red, the comment case only |
| `_lua_key` routed through `lua_string` | 4 red, the three table keys |
