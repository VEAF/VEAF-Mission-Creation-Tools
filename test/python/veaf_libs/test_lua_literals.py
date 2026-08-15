"""Tests for the shared Lua-literal helper (SECREV-2, findings VMR-010 and VMR-012).

The property that matters is not the exact bytes but the guarantee: whatever a value
contains, it comes back as *one* Lua string literal, and nothing inside it can be read
as structure.  Where an independent parser can confirm that, the tests use one --
``luadata`` is the repo's own, written by someone else, so a round trip through it is
not the implementation grading its own homework.
"""

from __future__ import annotations

import luadata
import pytest
from veaf_libs.lua_literals import lua_long_string, lua_quoted_string, lua_scalar, lua_string

#: Values that broke one emitter or another before this module existed.
NASTY_VALUES = [
    'say "hello"',
    r"C:\Users\foo",
    "line1\nline2",
    "carriage\rreturn",
    "tab\tseparated",
    "closing ]] bracket",
    "closing ]=] bracket",
    'both "quotes" and \\ backslash',
    "",
    "plain",
    "accented éàü",
]


# ---------------------------------------------------------------------------
# lua_quoted_string -- the form read by non-Lua parsers
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("value", NASTY_VALUES)
def test_quoted_string_is_a_single_literal(value: str) -> None:
    """The result opens and closes exactly once, so nothing escapes the literal."""
    result = lua_quoted_string(value)

    assert result.startswith('"')
    assert result.endswith('"')
    # Every quote strictly inside the literal must be escaped, or the literal ends early.
    body = result[1:-1]
    unescaped = body.replace("\\\\", "").replace('\\"', "")
    assert '"' not in unescaped


@pytest.mark.parametrize("value", NASTY_VALUES)
def test_quoted_string_never_contains_a_raw_line_break(value: str) -> None:
    """A raw newline inside a Lua short string is a syntax error -- this was VMR-010."""
    result = lua_quoted_string(value)

    assert "\n" not in result
    assert "\r" not in result


@pytest.mark.parametrize(
    "value",
    ['say "hello"', r"C:\Users\foo", 'both "quotes" and \\ backslash', "plain", "", "accented éàü"],
)
def test_quoted_string_round_trips_through_luadata(value: str) -> None:
    """Confirmed by the repo's own parser, not by re-running the escaping logic.

    Limited to the escapes ``luadata`` implements: it passes ``\\n`` and ``\\t``
    through verbatim rather than decoding them, so those are pinned by the explicit
    expectations below instead.
    """
    parsed = luadata.unserialize("{" + lua_quoted_string(value) + "}")

    assert parsed == [value]


def test_quoted_string_escapes_are_the_lua_ones() -> None:
    """The whitespace escapes, pinned exactly."""
    assert lua_quoted_string("a\nb") == '"a\\nb"'
    assert lua_quoted_string("a\rb") == '"a\\rb"'
    assert lua_quoted_string("a\tb") == '"a\\tb"'


def test_quoted_string_escapes_the_backslash_before_anything_else() -> None:
    """Order matters: escaping the quote first would leave its backslash unescaped."""
    assert lua_quoted_string("\\") == '"\\\\"'
    assert lua_quoted_string('\\"') == '"\\\\\\""'


def test_quoted_string_renders_other_control_characters_numerically() -> None:
    """A control character Lua has no named escape for still cannot travel raw."""
    result = lua_quoted_string("bell\x07here")

    assert result == '"bell\\007here"'


# ---------------------------------------------------------------------------
# lua_long_string -- the readable form
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("value", NASTY_VALUES)
def test_long_string_picks_a_level_the_value_cannot_close(value: str) -> None:
    """The chosen closing sequence must not occur in the text it wraps."""
    result = lua_long_string(value)

    level = result.index("[", 1) - 1
    closing = "]" + ("=" * level) + "]"
    assert result.startswith("[" + ("=" * level) + "[")
    assert result.endswith(closing)
    assert closing not in value


def test_long_string_raises_the_level_when_needed() -> None:
    assert lua_long_string("plain") == "[[plain]]"
    assert lua_long_string("has ]] inside") == "[=[has ]] inside]=]"
    assert lua_long_string("has ]] and ]=] inside") == "[==[has ]] and ]=] inside]==]"


# ---------------------------------------------------------------------------
# lua_string -- the policy that picks between the two
# ---------------------------------------------------------------------------


def test_string_keeps_simple_values_readable() -> None:
    assert lua_string("hello") == '"hello"'
    assert lua_string("") == '""'


@pytest.mark.parametrize("value", ['say "hi"', r"back\slash", "two\nlines"])
def test_string_switches_to_a_long_string_when_escaping_is_needed(value: str) -> None:
    assert lua_string(value).startswith("[")


def test_string_preserves_a_leading_newline() -> None:
    """Lua drops the newline right after an opening long bracket, so one is added.

    Without this the value comes back one character shorter than it went in, which is
    the kind of quiet difference a briefing would carry into the built mission.
    """
    result = lua_string("\nstarts with a break")

    assert result == "[[\n\nstarts with a break]]"


# ---------------------------------------------------------------------------
# lua_scalar
# ---------------------------------------------------------------------------


def test_scalar_renders_non_strings() -> None:
    assert lua_scalar(True) == "true"
    assert lua_scalar(False) == "false"
    assert lua_scalar(None) == "nil"
    assert lua_scalar(42) == "42"
    assert lua_scalar(1.5) == "1.5"


def test_scalar_checks_bool_before_int() -> None:
    """``True`` is an ``int`` in Python; rendering it as ``1`` would be wrong Lua."""
    assert lua_scalar(True) == "true"


def test_scalar_quotes_strings_safely() -> None:
    """This is the VMR-012 hole: the string branch used to interpolate with no escaping."""
    assert lua_scalar('a "quoted" value').startswith("[")
    assert lua_scalar("plain") == '"plain"'
