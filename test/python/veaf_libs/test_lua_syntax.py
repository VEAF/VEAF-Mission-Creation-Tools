"""Tests for the pure-Python Lua 5.1 syntax check that guards the generated config.

Two opposite failure modes matter, and each has its own kind of test here.

*Too strict* would break every build over valid Lua the parser never learned.  The
defence is the repository's own Lua: every file under ``src/scripts/veaf`` must parse.
That is thousands of lines of hand-written 5.1 nobody wrote for this parser, and it is
the corpus DCS actually runs.

*Too permissive* would make the guard decorative, which is exactly the state the build
was in.  The defence is a list of broken chunks, each one a shape an unescaped
mission value produces, with the line the parser must point at.
"""

from __future__ import annotations

from pathlib import Path

import pytest
from veaf_libs.lua_syntax import LuaSyntaxError, check_lua_syntax, tokenize

#: The repository root, four levels above ``test/python/veaf_libs/``.
REPO_ROOT = Path(__file__).resolve().parents[3]

VALID: dict[str, str] = {
    "assignment": "a = 1\n",
    "multiple assignment": "a, b.c, d[1] = 1, 2, 3\n",
    "local": "local a, b = 1, 2\n",
    "local function": "local function f(a, ...) return a end\n",
    "method definition": "function M.sub:go(a) return self end\n",
    "call with a string": 'require "mod"\n',
    "call with a table": "f{1, 2}\n",
    "method chain": 'Zone:new()\n  :setName("x")\n  :initialize()\n',
    "if elseif else": "if a then b() elseif c then d() else e() end\n",
    "while": "while a < 10 do a = a + 1 end\n",
    "repeat": "repeat a = a - 1 until a == 0\n",
    "numeric for": "for i = 1, 10, 2 do f(i) end\n",
    "generic for": "for k, v in pairs(t) do f(k, v) end\n",
    "do block": "do local a = 1 end\n",
    "break": "while true do break end\n",
    "return nothing": "function f() return end\n",
    "table constructor": "t = {1, 2; x = 3, [4] = 5,}\n",
    "nested function value": "t = { cb = function() return 1 end }\n",
    "long string": "s = [==[a ]] b]==]\n",
    "long comment": "--[[ a\nmulti line\ncomment ]]\na = 1\n",
    "operators": "a = not b and #c or -d ^ 2 .. e\n",
    "hex and exponent numbers": "a = 0xFF + 1.5e-3 + .5\n",
    "parenthesised prefix": "local x = (f or g)(1)\n",
    "escaped quote in a string": 's = "he said \\"hi\\""\n',
    "escaped line break in a string": 's = "one \\\n two"\n',
    "semicolons": "a = 1; b = 2;\n",
    "empty chunk": "",
    "comment only": "-- nothing here\n",
}

INVALID: dict[str, tuple[str, int]] = {
    "the coordinate that broke the mission": (
        'AirWaveZone:new()\n    :setZoneCenterFromCoordinates("N42°00\'00" E042°00\'00"")\n',
        2,
    ),
    "a quote inside a name": ('v.ActivateZone("Zone "Alpha"", true)\n', 1),
    "a newline inside a short string": ('f("one\ntwo")\n', 1),
    "a trailing backslash eating the quote": ('f("ends with \\")\n', 1),
    "unfinished long string": ("s = [[never closed\n", 1),
    "unfinished long comment": ("--[[ never closed\n", 1),
    "missing end": ("if a then b()\n", 2),
    "a bare expression as a statement": ("a + 1\n", 1),
    "assigning to a call": ("f() = 1\n", 1),
    "missing then": ("if a b() end\n", 1),
    "unclosed call": ("f(1, 2\n", 2),
    "stray closing brace": ("a = 1\n}\n", 2),
    "a value alone on a line": ('"orphan string"\n', 1),
}


@pytest.mark.parametrize("label", sorted(VALID))
def test_valid_lua_is_accepted(label: str) -> None:
    """Valid Lua 5.1 must pass; a false alarm here would break every build."""
    check_lua_syntax(VALID[label])


@pytest.mark.parametrize("label", sorted(INVALID))
def test_broken_lua_is_rejected_on_the_right_line(label: str) -> None:
    """Each shape an unescaped value produces must be caught, and located."""
    source, expected_line = INVALID[label]
    with pytest.raises(LuaSyntaxError) as excinfo:
        check_lua_syntax(source)
    assert excinfo.value.line == expected_line


def test_the_error_carries_the_offending_line_text() -> None:
    """The build shows the line, not just its number."""
    with pytest.raises(LuaSyntaxError) as excinfo:
        check_lua_syntax('a = 1\nf("one "two")\n')
    assert excinfo.value.source_line == 'f("one "two")'


def test_every_veaf_runtime_script_parses() -> None:
    """The parser is measured against the Lua the project actually ships.

    Nobody wrote these files with this parser in mind, and DCS runs them, so a rejection
    here means the parser is wrong — not the script.
    """
    scripts = sorted((REPO_ROOT / "src" / "scripts" / "veaf").rglob("*.lua"))
    assert len(scripts) > 20, "the corpus moved; this test is only worth its cost on the real one"
    for script in scripts:
        try:
            check_lua_syntax(script.read_text(encoding="utf-8"))
        except LuaSyntaxError as exc:  # pragma: no cover - only on a parser regression
            pytest.fail(f"{script.name}: {exc}")


def test_tokenizer_reports_the_line_a_multi_line_construct_ends_on() -> None:
    """Line counting has to survive long strings and comments, or the report lies."""
    tokens = tokenize("--[[\n\n]]\ns = [[\n\n]]\nx = 1\n")
    assert tokens[-2].value == "1"
    assert tokens[-2].line == 7
