"""Write a mission member (`mission`, `options`, `warehouses`, …) in the layout the DCS Mission Editor writes.

`luadata` writes the same Lua table in its own layout — bare keys, two-space indentation, no closing
comments — which DCS reads just as well, but which tools outside VEAF that read a mission's text do
not (Flogas, 2026-11-09). Measured on a mission the editor saved the same day: tab indentation, every
key in brackets, a table's `{` on its own line, `{}` inline for an empty table, a `-- end of [key]`
comment after each table and `} -- end of <name>` to close the member.

The keys keep VEAF's order (`luadata`'s sort), not the editor's: the editor writes them in hash order,
which changes from one save to the next, so no tool can rely on it, and a fixed order keeps the diffs
of a mission folder readable.
"""

from __future__ import annotations

from typing import Any

from luadata.serializer.serialize import _sort, _sort_by_id

_INDENT = "\t"


def serialize_member(content: Any, variable_name: str) -> str:
    """Render one mission member the way the DCS Mission Editor writes it.

    Args:
        content: The member's table, as the Lua parser returned it (dicts and lists).
        variable_name: The Lua global the member assigns (`mission`, `options`, `mapResource`…).

    Returns:
        The member's full text, ending with a newline.
    """
    if not isinstance(content, (dict, list)):
        return f"{variable_name} = {_scalar(content)}\n"
    if not content:
        return f"{variable_name} = {{}}\n"
    lines = [f"{variable_name} = ", "{"]
    _write_entries(content, 1, None, lines)
    lines.append(f"}} -- end of {variable_name}")
    return "\n".join(lines) + "\n"


def _write_entries(table: dict[Any, Any] | list[Any], level: int, parent_key: Any, lines: list[str]) -> None:
    """Append one line per entry of `table`, recursing into the nested tables."""
    indent = _INDENT * level
    for key, value in _entries(table, parent_key):
        key_text = _key(key)
        if isinstance(value, (dict, list)) and value:
            lines.append(f"{indent}{key_text} = ")
            lines.append(f"{indent}{{")
            _write_entries(value, level + 1, key, lines)
            lines.append(f"{indent}}}, -- end of {_comment_safe(key_text)}")
        elif isinstance(value, (dict, list)):
            lines.append(f"{indent}{key_text} = {{}},")
        else:
            lines.append(f"{indent}{key_text} = {_scalar(value)},")


def _entries(table: dict[Any, Any] | list[Any], parent_key: Any) -> list[tuple[Any, Any]]:
    """The entries of `table` in the order `luadata` writes them (a list numbered from 1)."""
    if isinstance(table, list):
        items = _sort_by_id(table) if parent_key == "country" else table
        return [(index + 1, item) for index, item in enumerate(items)]
    return [(key, table[key]) for key in _sort(list(table.keys()))]


def _key(key: Any) -> str:
    """A table key between brackets: `["name"]` for a string, `[1]` for a number."""
    if isinstance(key, str):
        return f"[{_string(key)}]"
    return f"[{_scalar(key)}]"


def _comment_safe(key_text: str) -> str:
    """`key_text` with no line break, for the `-- end of` comment.

    A Lua comment ends at the line break: a key holding a newline (escaped as a backslash then a real
    newline) would end the comment there and turn the rest of the key into code that DCS runs.
    """
    return key_text.replace("\\\n", "\\n").replace("\r", "\\r").replace("\n", "\\n")


def _scalar(value: Any) -> str:
    """A Lua literal for a value that is not a table."""
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        # The editor writes a whole number without its decimal part (`["start_time"] = 28800`).
        return str(int(value)) if value.is_integer() and abs(value) < 1e15 else repr(value)
    return _string(str(value))


def _string(text: str) -> str:
    """A quoted Lua string, escaped as `luadata` escapes it (backslash, quote, newline)."""
    escaped = text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\\n")
    return f'"{escaped}"'
