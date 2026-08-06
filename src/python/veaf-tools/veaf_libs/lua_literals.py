"""The one place that turns a Python value into a Lua literal.

Several parts of the toolchain generate Lua source: the mission configuration
generator, the spawn-data emitter, the MCP writers.  Each of them used to carry its
own idea of how to quote a string, and the ideas disagreed — one wrapped the value in
a long string when it had to, another escaped a backslash and a double quote and
nothing else, a third interpolated the value into ``"…"`` with no escaping at all.
Any value carrying a newline came out of the second as a Lua syntax error, and out of
the third as whatever the value chose to be.

The 2026-07-01 security review (SECREV-2, findings VMR-010 and VMR-012) called this
out as one pattern rather than three bugs, and the fix as one always-used helper
rather than three repairs: fixing the instances leaves a fourth emitter to be written
next month.  This module is that helper.  Emitting Lua from anywhere else in the
codebase without going through it should look wrong.

Note the asymmetry with the server hook, which solves the same problem with Lua's own
``string.format("%q", …)``.  That is available inside Lua and not here, so this module
reimplements the guarantee: whatever the value contains, it comes back as *one* Lua
string literal that evaluates to exactly that value.

Two forms, because the generated files have two different readers and only one of them
is Lua:

* :func:`lua_string` prefers a long string when the value needs escaping.  Generated
  mission configuration is full of briefings and multi-line prose that a person reads
  in the built ``.miz``, and ``[[…]]`` keeps it legible.
* :func:`lua_quoted_string` always produces an escaped ``"…"``.  Spawn data is read
  back by the bundled pure-Python ``luadata`` parser, which supports no long-string
  syntax at all, so readability loses to being parseable by both readers.

Pick by who reads the output, not by taste.
"""

from __future__ import annotations


def lua_long_string(text: str) -> str:
    """Wrap *text* in a Lua long string with a bracket level that cannot be closed early.

    A long string ``[[…]]`` is opaque only until its own closing sequence appears
    inside it.  The level is raised until the closing bracket does not occur in the
    text, which makes the result valid for any input.

    Args:
        text: The raw text to embed.

    Returns:
        A Lua long-string literal, e.g. ``[==[text]==]``.
    """
    level = 0
    while f"]{('=' * level)}]" in text:
        level += 1
    eq = "=" * level
    return f"[{eq}[{text}]{eq}]"


def lua_string(value: str) -> str:
    """Return a Lua string literal that evaluates to exactly *value*.

    Uses a long string when the value contains a newline, a double quote or a
    backslash — characters that either cannot appear unescaped inside a ``"…"`` Lua
    string, or that Lua's escape processing would silently transform.  Everything else
    is wrapped in double quotes, which keeps ordinary generated Lua readable.

    A leading newline is worth knowing about: Lua drops the first newline immediately
    after a long-string opening bracket, so the value is emitted with an explicit
    newline of its own to survive the round trip.

    Args:
        value: The string to embed in generated Lua source.

    Returns:
        A single Lua string literal.
    """
    if "\n" in value or '"' in value or "\\" in value:
        if value.startswith("\n"):
            # Lua eats the newline that follows the opening bracket, so give it one to eat.
            return lua_long_string("\n" + value)
        return lua_long_string(value)
    return f'"{value}"'


#: Characters that cannot travel raw inside a Lua ``"…"`` literal, and their escapes.
#: A backslash must be replaced first, or it would escape the escapes added after it.
_QUOTED_ESCAPES = (
    ("\\", "\\\\"),
    ('"', '\\"'),
    ("\n", "\\n"),
    ("\r", "\\r"),
    ("\t", "\\t"),
)


def lua_quoted_string(value: str) -> str:
    """Return an escaped ``"…"`` Lua literal that evaluates to exactly *value*.

    Always a short string, never a long one: the caller's output is read by something
    that is not a Lua interpreter.  Escapes the backslash, the double quote and the
    three whitespace characters that terminate or distort a short string; any other
    control character is emitted as a numeric escape, which Lua accepts and which
    cannot be mistaken for structure.

    Args:
        value: The string to embed in generated Lua source.

    Returns:
        A single double-quoted Lua string literal.
    """
    escaped = value
    for raw, replacement in _QUOTED_ESCAPES:
        escaped = escaped.replace(raw, replacement)
    escaped = "".join(char if char.isprintable() or char == " " else f"\\{ord(char):03d}" for char in escaped)
    return f'"{escaped}"'


def lua_scalar(value: object) -> str:
    """Return a Lua literal for a Python scalar, strings safely quoted.

    Args:
        value: A bool, number, ``None``, or anything else, which is rendered via its
            string form.

    Returns:
        The Lua source for that value.
    """
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if value is None:
        return "nil"
    return lua_string(str(value))
