"""Audit DCS-mock coverage of the VEAF Lua runtime against the vendored API schema.

The Lua test suite runs against hand-maintained DCS API stubs in
``test/lua/dcs_mocks.lua``. A missing stub is normally only discovered when a test
blows up on ``attempt to call a nil value``. This module cross-references three
sets, by **presence** (never signature), to surface the gap ahead of time:

- **schema** -- DCS functions parsed from the vendored ``dcs-world-api-schema.json``;
- **used** -- DCS calls extracted from ``src/scripts/veaf/*.lua``, restricted to the
  schema-known global namespaces (so VEAF/mist calls do not pollute the report);
- **mocked** -- functions defined in ``test/lua/dcs_mocks.lua``.

The reported buckets are:

- ``missing`` -- used and in-schema but not mocked -> the real test gap;
- ``unknown`` -- used on a known namespace but not in the schema -> typo or genuinely
  undocumented call (e.g. ``Disposition``);
- ``unused`` -- mocked on a known namespace but never called -> cleanup candidate.

Signatures are intentionally not compared: the mocks are *behavioural* (registries,
log capture) and the schema is *incomplete* (``params: []`` on undocumented funcs),
so an arg/return check would be mostly false positives.
"""

from __future__ import annotations

import json
import re
from collections.abc import Collection, Iterable
from dataclasses import dataclass
from typing import Any

# Long-bracket opener for Lua long strings/comments: ``[[``, ``[=[``, ``[==[`` ...
_LONG_OPEN = re.compile(r"\[(=*)\[")

# Keywords that open an ``end``-terminated block, used to skip Lua function bodies.
_BLOCK_OPENERS = frozenset({"function", "if", "for", "while"})


@dataclass(frozen=True)
class SchemaModel:
    """Parsed DCS scripting-API schema.

    Attributes:
        functions: Dotted namespace-qualified function paths (e.g. ``land.getHeight``,
            ``trigger.action.outText``).
        namespaces: The top-level DCS global names (e.g. ``land``, ``coalition``).
    """

    functions: frozenset[str]
    namespaces: frozenset[str]


@dataclass(frozen=True)
class AuditResult:
    """Outcome of a mock-coverage audit (all tuples sorted for stable output).

    Attributes:
        missing: Used, in-schema, not mocked -- the real test gap.
        unknown: Used on a known namespace but not in the schema (typo/undocumented).
        unused: Mocked on a known namespace but never used (cleanup candidate).
    """

    missing: tuple[str, ...]
    unknown: tuple[str, ...]
    unused: tuple[str, ...]

    @property
    def has_gap(self) -> bool:
        """Whether the real gap (``missing``) is non-empty."""
        return bool(self.missing)


def strip_lua_comments(text: str) -> str:
    """Remove Lua comments from source while preserving string literals.

    Handles short (``-- ...``) and long (``--[[ ... ]]``, ``--[==[ ... ]==]``)
    comments, and skips over single/double/long string literals so a ``--`` inside
    a string is not mistaken for a comment.

    Args:
        text: Lua source.

    Returns:
        The source with every comment removed (newlines preserved).
    """
    out: list[str] = []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        # Short string literal.
        if c in ("'", '"'):
            quote = c
            out.append(c)
            i += 1
            while i < n:
                ch = text[i]
                out.append(ch)
                i += 1
                if ch == "\\" and i < n:
                    out.append(text[i])
                    i += 1
                    continue
                if ch == quote:
                    break
            continue
        # Long string literal.
        if c == "[":
            m = _LONG_OPEN.match(text, i)
            if m:
                close = "]" + "=" * len(m.group(1)) + "]"
                end = text.find(close, m.end())
                end = n if end == -1 else end + len(close)
                out.append(text[i:end])
                i = end
                continue
        # Comment (short or long).
        if c == "-" and i + 1 < n and text[i + 1] == "-":
            m = _LONG_OPEN.match(text, i + 2)
            if m:
                close = "]" + "=" * len(m.group(1)) + "]"
                end = text.find(close, m.end())
                i = n if end == -1 else end + len(close)
                continue
            nl = text.find("\n", i)
            i = n if nl == -1 else nl  # keep the newline itself
            continue
        out.append(c)
        i += 1
    return "".join(out)


def parse_schema(data: dict[str, Any]) -> SchemaModel:
    """Build the schema model from a parsed ``dcs-world-api-schema.json`` document.

    Walks every global namespace and collects namespace-qualified function paths
    from its ``static`` block and, recursively, from nested ``properties``
    sub-namespaces (e.g. ``trigger.action.outText``). Instance methods are ignored:
    they are called on variables, never namespace-qualified, so they never appear in
    the namespace-filtered ``used`` set.

    Args:
        data: The decoded JSON document (with a top-level ``globals`` mapping).

    Returns:
        A :class:`SchemaModel` with the function paths and namespace names.
    """
    functions: set[str] = set()
    globals_node = data.get("globals", {})
    namespaces = frozenset(globals_node.keys())
    for name, node in globals_node.items():
        _collect_schema_functions(node, name, functions)
    return SchemaModel(functions=frozenset(functions), namespaces=namespaces)


def _collect_schema_functions(node: Any, prefix: str, out: set[str]) -> None:
    """Recursively collect static/nested function paths under ``prefix``."""
    if not isinstance(node, dict):
        return
    static = node.get("static")
    if isinstance(static, dict):
        for fname, fspec in static.items():
            out.add(f"{prefix}.{fname}")
            # A static entry is normally a leaf function; recurse only if it nests.
            if isinstance(fspec, dict) and ("static" in fspec or "properties" in fspec):
                _collect_schema_functions(fspec, f"{prefix}.{fname}", out)
    properties = node.get("properties")
    if isinstance(properties, dict):
        for pname, pspec in properties.items():
            _collect_schema_functions(pspec, f"{prefix}.{pname}", out)


def load_schema(json_text: str) -> SchemaModel:
    """Parse a schema model from the raw JSON text of the vendored schema.

    Args:
        json_text: Contents of ``dcs-world-api-schema.json``.

    Returns:
        A :class:`SchemaModel`.
    """
    return parse_schema(json.loads(json_text))


def extract_used_calls(lua_text: str, namespaces: Collection[str]) -> set[str]:
    """Extract DCS calls from Lua source, restricted to known namespaces.

    Matches namespace-qualified call chains ending in a ``(`` (e.g.
    ``land.getHeight(``, ``trigger.action.outText(``). A negative look-behind keeps
    the namespace from matching when it is itself a sub-field of another table
    (e.g. ``something.land.getHeight``).

    Args:
        lua_text: Lua source to scan.
        namespaces: The schema-known global namespaces to anchor matches on.

    Returns:
        The set of dotted call paths used (e.g. ``{"land.getHeight"}``).
    """
    if not namespaces:
        return set()
    code = strip_lua_comments(lua_text)
    alt = "|".join(sorted((re.escape(ns) for ns in namespaces), key=len, reverse=True))
    pattern = re.compile(r"(?<![\w.:])(" + alt + r")((?:\.[A-Za-z_]\w*)+)\s*\(")
    return {m.group(1) + m.group(2) for m in pattern.finditer(code)}


def parse_mocked_functions(lua_text: str) -> set[str]:
    """Extract the dotted paths of function-valued keys defined in a mock file.

    Tracks table-constructor nesting to build dotted paths (e.g.
    ``trigger.action.outText``) and skips function bodies so that braces or ``end``
    keywords inside a body do not corrupt the key stack. Only ``key = function``
    leaves are recorded (enum/value tables are ignored).

    Args:
        lua_text: Contents of a DCS mock file (e.g. ``dcs_mocks.lua``).

    Returns:
        The set of dotted function paths defined by the mock.
    """
    tokens = _tokenize_lua(strip_lua_comments(lua_text))
    out: set[str] = set()
    stack: list[str | None] = []
    pending: str | None = None
    last_name: str | None = None
    i, n = 0, len(tokens)
    while i < n:
        kind, val = tokens[i]
        if kind == "NAME":
            if val == "function":
                if pending is not None:
                    parts = [p for p in stack if p]
                    parts.append(pending)
                    out.add(".".join(parts))
                pending = last_name = None
                i = _skip_function_body(tokens, i + 1)
                continue
            last_name = val
            i += 1
            continue
        if kind == "ASSIGN":
            pending, last_name = last_name, None
            i += 1
            continue
        if kind == "LBRACE":
            stack.append(pending)
            pending = last_name = None
            i += 1
            continue
        if kind == "RBRACE":
            if stack:
                stack.pop()
            pending = last_name = None
            i += 1
            continue
        # STRING / OTHER: a scalar value resolves any pending assignment.
        pending = last_name = None
        i += 1
    return out


def _tokenize_lua(code: str) -> list[tuple[str, str | None]]:
    """Tokenize comment-stripped Lua into the minimal tokens the mock parser needs."""
    tokens: list[tuple[str, str | None]] = []
    i, n = 0, len(code)
    while i < n:
        c = code[i]
        if c.isspace():
            i += 1
            continue
        if c in ("'", '"'):
            quote = c
            i += 1
            while i < n:
                ch = code[i]
                i += 1
                if ch == "\\":
                    i += 1
                    continue
                if ch == quote:
                    break
            tokens.append(("STRING", None))
            continue
        if c == "[":
            m = _LONG_OPEN.match(code, i)
            if m:
                close = "]" + "=" * len(m.group(1)) + "]"
                end = code.find(close, m.end())
                i = n if end == -1 else end + len(close)
                tokens.append(("STRING", None))
                continue
        if c.isalpha() or c == "_":
            j = i + 1
            while j < n and (code[j].isalnum() or code[j] == "_"):
                j += 1
            tokens.append(("NAME", code[i:j]))
            i = j
            continue
        if c == "=":
            if i + 1 < n and code[i + 1] == "=":
                tokens.append(("OTHER", "=="))
                i += 2
                continue
            tokens.append(("ASSIGN", "="))
            i += 1
            continue
        if c == "{":
            tokens.append(("LBRACE", None))
            i += 1
            continue
        if c == "}":
            tokens.append(("RBRACE", None))
            i += 1
            continue
        tokens.append(("OTHER", c))
        i += 1
    return tokens


def _skip_function_body(tokens: list[tuple[str, str | None]], i: int) -> int:
    """Advance past a Lua function body, returning the index after its ``end``."""
    depth = 1
    n = len(tokens)
    while i < n and depth > 0:
        kind, val = tokens[i]
        if kind == "NAME":
            if val in _BLOCK_OPENERS:
                depth += 1
            elif val == "end":
                depth -= 1
        i += 1
    return i


def compute_audit(*, schema: SchemaModel, used: set[str], mocked: set[str]) -> AuditResult:
    """Compare the three sets and bucket the findings (presence only).

    Args:
        schema: Parsed schema model.
        used: DCS calls used by VEAF Lua (already namespace-filtered).
        mocked: Function paths defined by the mock file.

    Returns:
        An :class:`AuditResult` with sorted ``missing`` / ``unknown`` / ``unused``.
    """
    missing = (used & schema.functions) - mocked
    unknown = used - schema.functions
    mocked_known = {m for m in mocked if m.split(".", 1)[0] in schema.namespaces}
    unused = mocked_known - used
    return AuditResult(
        missing=tuple(sorted(missing)),
        unknown=tuple(sorted(unknown)),
        unused=tuple(sorted(unused)),
    )


def audit_mocks(*, schema_json: str, mock_lua: str, veaf_sources: Iterable[str]) -> AuditResult:
    """Run a full audit from raw inputs.

    Args:
        schema_json: Contents of the vendored ``dcs-world-api-schema.json``.
        mock_lua: Contents of ``test/lua/dcs_mocks.lua``.
        veaf_sources: Lua source texts of the runtime scripts to scan.

    Returns:
        The :class:`AuditResult`.
    """
    schema = load_schema(schema_json)
    used: set[str] = set()
    for source in veaf_sources:
        used |= extract_used_calls(source, schema.namespaces)
    mocked = parse_mocked_functions(mock_lua)
    return compute_audit(schema=schema, used=used, mocked=mocked)
