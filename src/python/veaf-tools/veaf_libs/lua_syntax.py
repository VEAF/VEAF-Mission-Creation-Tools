"""Answer one question about generated Lua: does it parse?

The build writes ``veaf-config.lua`` and used to ship whatever came out.  A single
mission-supplied value carrying a ``"`` closed a string literal early, the file stopped
being valid Lua, and DCS refused **the whole file** — so not one module initialised, no
radio menu, nothing.  The build reported success; the defect appeared only in
``dcs.log``, after the mission was loaded in the game.

This module is the check that closes that gap.  It is deliberately a *syntax* check and
nothing more: it does not evaluate, resolve names or know what a VEAF module is.  It
answers "would Lua refuse this file, and on which line".

Why a parser written here rather than a tool
--------------------------------------------
* ``luac -p`` answers the same question in milliseconds — where ``luac`` is installed.
  It is not on the CI runners, not in the shipped one-file executable, and not on a
  mission maker's machine.  A guard that only runs where an optional tool exists is not
  a guard; it is a guard-shaped hole.
* ``luadata``, bundled in this repository, is a *data* (de)serialiser: it reads a Lua
  table literal.  Measured against the generated file, it rejects the very first line of
  real code — ``veaf.setConfig("X", "enable", false)`` is a function call, not data.  It
  cannot serve.

So the grammar below is Lua 5.1's own, transcribed: the version DCS runs, and small
enough that a recursive-descent parser fits in one readable module.
"""

from __future__ import annotations

from typing import NamedTuple

__all__ = ["LuaSyntaxError", "check_lua_syntax", "tokenize"]


class LuaSyntaxError(Exception):
    """Raised when a chunk of Lua source does not parse.

    Attributes:
        line: The 1-based line the parser stopped on.
        reason: The message without the location prefix.
        source_line: That line's text, filled in by :func:`check_lua_syntax` so the
            build can show the mission maker what it choked on instead of a number.
    """

    def __init__(self, reason: str, line: int) -> None:
        """Build the error.

        Args:
            reason: What the parser expected or found.
            line: The 1-based source line.
        """
        self.reason = reason
        self.line = line
        self.source_line = ""
        super().__init__(f"line {line}: {reason}")


class Token(NamedTuple):
    """One lexical token.

    Attributes:
        kind: ``name``, ``number``, ``string``, ``op``, ``keyword`` or ``eof``.
        value: The token text (for a string, the raw literal, never its value).
        line: The 1-based line the token starts on.
    """

    kind: str
    value: str
    line: int


#: Lua 5.1 reserved words. ``goto`` is 5.2+ and is deliberately absent: DCS runs 5.1.
_KEYWORDS = frozenset(
    """and break do else elseif end false for function if in local nil not or
    repeat return then true until while""".split()
)

#: Multi-character operators, longest first so ``...`` wins over ``..`` over ``.``.
_OPERATORS = (
    "...",
    "..",
    "==",
    "~=",
    "<=",
    ">=",
    "+",
    "-",
    "*",
    "/",
    "%",
    "^",
    "#",
    "<",
    ">",
    "=",
    "(",
    ")",
    "{",
    "}",
    "[",
    "]",
    ";",
    ":",
    ",",
    ".",
)

#: Binary operators mapped to (left priority, right priority), from ``lparser.c``.
#: A right-associative operator has a right priority one below its left one.
_BINARY_PRIORITY: dict[str, tuple[int, int]] = {
    "or": (1, 1),
    "and": (2, 2),
    "<": (3, 3),
    ">": (3, 3),
    "<=": (3, 3),
    ">=": (3, 3),
    "~=": (3, 3),
    "==": (3, 3),
    "..": (9, 8),
    "+": (6, 6),
    "-": (6, 6),
    "*": (7, 7),
    "/": (7, 7),
    "%": (7, 7),
    "^": (10, 9),
}

#: Priority of a unary operator, from ``lparser.c``.
_UNARY_PRIORITY = 8

#: Tokens that can only close a block, never start a statement inside it.
_BLOCK_FOLLOW = frozenset({"end", "else", "elseif", "until"})


def _is_digit(char: str) -> bool:
    """Return whether *char* is an ASCII digit.

    ``str.isdigit`` is true for characters Lua's lexer does not accept in a number
    (superscripts, other scripts' digits), so the test is spelled out.

    Args:
        char: A single character.

    Returns:
        ``True`` for ``0``-``9``.
    """
    return "0" <= char <= "9"


def _is_name_start(char: str) -> bool:
    """Return whether *char* may open a Lua identifier.

    ASCII only, deliberately: Lua 5.1 identifiers are ``[A-Za-z_]``, so an accented
    letter loose in the source is a syntax error and must be reported as one rather
    than swallowed into a name — which is precisely how an unescaped value escapes
    its string literal.

    Args:
        char: A single character.

    Returns:
        ``True`` for ``A-Z``, ``a-z`` and ``_``.
    """
    return char == "_" or ("a" <= char <= "z") or ("A" <= char <= "Z")


def _is_name_char(char: str) -> bool:
    """Return whether *char* may continue a Lua identifier.

    Args:
        char: A single character.

    Returns:
        ``True`` for an identifier start character or an ASCII digit.
    """
    return _is_name_start(char) or _is_digit(char)


def _long_bracket(source: str, pos: int) -> tuple[int, int] | None:
    """Match a long-bracket opener ``[==[`` at *pos*.

    Args:
        source: The whole source.
        pos: Index of the candidate ``[``.

    Returns:
        ``(level, index just past the opener)``, or ``None`` when *pos* does not open
        a long bracket.
    """
    if pos >= len(source) or source[pos] != "[":
        return None
    cursor = pos + 1
    level = 0
    while cursor < len(source) and source[cursor] == "=":
        level += 1
        cursor += 1
    if cursor < len(source) and source[cursor] == "[":
        return level, cursor + 1
    return None


def _read_long_bracket(source: str, pos: int, line: int, what: str) -> tuple[int, int]:
    """Consume a long string or long comment starting at *pos*.

    Args:
        source: The whole source.
        pos: Index of the opening ``[``.
        line: Current 1-based line number.
        what: ``string`` or ``comment``, used in the error message.

    Returns:
        ``(index just past the closer, updated line number)``.

    Raises:
        LuaSyntaxError: If the closing bracket never appears.
    """
    opener = _long_bracket(source, pos)
    assert opener is not None  # noqa: S101 - callers check first
    level, cursor = opener
    closer = "]" + "=" * level + "]"
    end = source.find(closer, cursor)
    if end < 0:
        raise LuaSyntaxError(f"unfinished long {what}", line)
    return end + len(closer), line + source.count("\n", pos, end + len(closer))


def _read_short_string(source: str, pos: int, line: int) -> int:
    """Consume a ``'…'`` or ``"…"`` string starting at *pos*.

    Args:
        source: The whole source.
        pos: Index of the opening quote.
        line: Current 1-based line number.

    Returns:
        The index just past the closing quote.

    Raises:
        LuaSyntaxError: On an unescaped newline or end of file inside the literal —
            which is exactly what an unescaped mission value produces.
    """
    quote = source[pos]
    cursor = pos + 1
    while True:
        if cursor >= len(source):
            raise LuaSyntaxError("unfinished string", line)
        char = source[cursor]
        if char == "\\":
            # Lua 5.1 accepts any character after a backslash (an unknown escape yields
            # the character itself), including an escaped newline.
            cursor += 2
            continue
        if char in "\r\n":
            raise LuaSyntaxError("unfinished string", line)
        cursor += 1
        if char == quote:
            return cursor


def _read_number(source: str, pos: int) -> int:
    """Consume a numeric literal starting at *pos*.

    Args:
        source: The whole source.
        pos: Index of the first digit or of a ``.`` followed by a digit.

    Returns:
        The index just past the literal.
    """
    cursor = pos
    if source.startswith(("0x", "0X"), pos):
        cursor += 2
        while cursor < len(source) and source[cursor] in "0123456789abcdefABCDEF":
            cursor += 1
        return cursor
    while cursor < len(source) and (_is_digit(source[cursor]) or source[cursor] == "."):
        cursor += 1
    if cursor < len(source) and source[cursor] in "eE":
        cursor += 1
        if cursor < len(source) and source[cursor] in "+-":
            cursor += 1
        while cursor < len(source) and _is_digit(source[cursor]):
            cursor += 1
    return cursor


def tokenize(source: str) -> list[Token]:
    """Split Lua 5.1 source into tokens, ending with an ``eof`` token.

    Args:
        source: The Lua source text.

    Returns:
        The token list.

    Raises:
        LuaSyntaxError: On an unfinished string, long string or long comment, or on a
            character Lua has no token for.
    """
    tokens: list[Token] = []
    pos = 0
    line = 1
    length = len(source)
    while pos < length:
        char = source[pos]
        if char == "\n":
            line += 1
            pos += 1
            continue
        if char in " \t\r\v\f":
            pos += 1
            continue
        if source.startswith("--", pos):
            after = pos + 2
            if _long_bracket(source, after) is not None:
                pos, line = _read_long_bracket(source, after, line, "comment")
                continue
            newline = source.find("\n", after)
            pos = length if newline < 0 else newline
            continue
        if char in "\"'":
            start_line = line
            pos = _read_short_string(source, pos, line)
            tokens.append(Token("string", "<string>", start_line))
            continue
        if char == "[" and _long_bracket(source, pos) is not None:
            start_line = line
            pos, line = _read_long_bracket(source, pos, line, "string")
            tokens.append(Token("string", "<string>", start_line))
            continue
        if _is_digit(char) or (char == "." and pos + 1 < length and _is_digit(source[pos + 1])):
            end = _read_number(source, pos)
            tokens.append(Token("number", source[pos:end], line))
            pos = end
            continue
        if _is_name_start(char):
            end = pos
            while end < length and _is_name_char(source[end]):
                end += 1
            word = source[pos:end]
            tokens.append(Token("keyword" if word in _KEYWORDS else "name", word, line))
            pos = end
            continue
        for operator in _OPERATORS:
            if source.startswith(operator, pos):
                tokens.append(Token("op", operator, line))
                pos += len(operator)
                break
        else:
            raise LuaSyntaxError(f"unexpected symbol near {char!r}", line)
    tokens.append(Token("eof", "<eof>", line))
    return tokens


class _Parser:
    """A recursive-descent parser for a Lua 5.1 chunk.

    It accepts or rejects; it builds no tree, because the only question asked of it is
    whether Lua would refuse the file.
    """

    def __init__(self, tokens: list[Token]) -> None:
        """Store the token stream.

        Args:
            tokens: The output of :func:`tokenize`.
        """
        self._tokens = tokens
        self._index = 0

    # -- token access -------------------------------------------------------

    @property
    def _current(self) -> Token:
        return self._tokens[self._index]

    def _advance(self) -> Token:
        token = self._tokens[self._index]
        self._index += 1
        return token

    def _at(self, value: str) -> bool:
        token = self._current
        return token.kind in ("op", "keyword") and token.value == value

    def _accept(self, value: str) -> bool:
        if self._at(value):
            self._index += 1
            return True
        return False

    def _expect(self, value: str) -> None:
        if not self._accept(value):
            self._error(f"'{value}' expected")

    def _expect_name(self) -> None:
        if self._current.kind != "name":
            self._error("<name> expected")
        self._index += 1

    def _error(self, reason: str) -> None:
        token = self._current
        raise LuaSyntaxError(f"{reason} near '{token.value}'", token.line)

    # -- grammar ------------------------------------------------------------

    def parse(self) -> None:
        """Parse a whole chunk.

        Raises:
            LuaSyntaxError: On the first construct Lua would refuse.
        """
        self._block()
        if self._current.kind != "eof":
            self._error("'<eof>' expected")

    def _block_follow(self) -> bool:
        token = self._current
        return token.kind == "eof" or (token.kind == "keyword" and token.value in _BLOCK_FOLLOW)

    def _block(self) -> None:
        while not self._block_follow():
            if self._at("return") or self._at("break"):
                self._last_statement()
                return
            self._statement()

    def _last_statement(self) -> None:
        if self._accept("break"):
            self._accept(";")
            return
        self._expect("return")
        if not self._block_follow() and not self._at(";"):
            self._expression_list()
        self._accept(";")

    def _statement(self) -> None:
        if self._accept("if"):
            self._expression()
            self._expect("then")
            self._block()
            while self._accept("elseif"):
                self._expression()
                self._expect("then")
                self._block()
            if self._accept("else"):
                self._block()
            self._expect("end")
        elif self._accept("while"):
            self._expression()
            self._expect("do")
            self._block()
            self._expect("end")
        elif self._accept("do"):
            self._block()
            self._expect("end")
        elif self._accept("for"):
            self._for_statement()
        elif self._accept("repeat"):
            self._block()
            self._expect("until")
            self._expression()
        elif self._accept("function"):
            self._function_name()
            self._function_body()
        elif self._accept("local"):
            self._local_statement()
        else:
            self._expression_statement()
        self._accept(";")

    def _for_statement(self) -> None:
        self._expect_name()
        if self._accept("="):
            self._expression()
            self._expect(",")
            self._expression()
            if self._accept(","):
                self._expression()
        else:
            while self._accept(","):
                self._expect_name()
            self._expect("in")
            self._expression_list()
        self._expect("do")
        self._block()
        self._expect("end")

    def _local_statement(self) -> None:
        if self._accept("function"):
            self._expect_name()
            self._function_body()
            return
        self._expect_name()
        while self._accept(","):
            self._expect_name()
        if self._accept("="):
            self._expression_list()

    def _function_name(self) -> None:
        self._expect_name()
        while self._accept("."):
            self._expect_name()
        if self._accept(":"):
            self._expect_name()

    def _function_body(self) -> None:
        self._expect("(")
        if not self._at(")"):
            while True:
                if self._accept("..."):
                    break
                self._expect_name()
                if not self._accept(","):
                    break
        self._expect(")")
        self._block()
        self._expect("end")

    def _expression_statement(self) -> None:
        line = self._current.line
        was_call = self._suffixed_expression()
        if self._at("=") or self._at(","):
            if was_call:
                raise LuaSyntaxError("cannot assign to a function call", line)
            while self._accept(","):
                if self._suffixed_expression():
                    raise LuaSyntaxError("cannot assign to a function call", line)
            self._expect("=")
            self._expression_list()
            return
        if not was_call:
            raise LuaSyntaxError("syntax error: statement is not a call or an assignment", line)

    def _expression_list(self) -> None:
        self._expression()
        while self._accept(","):
            self._expression()

    def _expression(self, limit: int = 0) -> None:
        token = self._current
        if (token.kind == "op" and token.value in ("-", "#")) or self._at("not"):
            self._advance()
            self._expression(_UNARY_PRIORITY)
        else:
            self._simple_expression()
        while True:
            token = self._current
            if token.kind not in ("op", "keyword"):
                break
            priority = _BINARY_PRIORITY.get(token.value)
            if priority is None or priority[0] <= limit:
                break
            self._advance()
            self._expression(priority[1])

    def _simple_expression(self) -> None:
        token = self._current
        if token.kind in ("number", "string"):
            self._advance()
            return
        if token.kind == "keyword" and token.value in ("nil", "true", "false"):
            self._advance()
            return
        if self._accept("..."):
            return
        if self._at("{"):
            self._table_constructor()
            return
        if self._accept("function"):
            self._function_body()
            return
        self._suffixed_expression()

    def _primary_expression(self) -> None:
        if self._accept("("):
            self._expression()
            self._expect(")")
            return
        if self._current.kind == "name":
            self._advance()
            return
        self._error("unexpected symbol")

    def _suffixed_expression(self) -> bool:
        """Parse a variable or a call and report which one it was.

        Returns:
            ``True`` when the expression ends in a call, which is the only expression
            Lua accepts as a statement on its own.
        """
        self._primary_expression()
        is_call = False
        while True:
            if self._accept("."):
                self._expect_name()
                is_call = False
            elif self._accept("["):
                self._expression()
                self._expect("]")
                is_call = False
            elif self._accept(":"):
                self._expect_name()
                self._call_arguments()
                is_call = True
            elif self._at("(") or self._at("{") or self._current.kind == "string":
                self._call_arguments()
                is_call = True
            else:
                return is_call

    def _call_arguments(self) -> None:
        if self._current.kind == "string":
            self._advance()
            return
        if self._at("{"):
            self._table_constructor()
            return
        self._expect("(")
        if not self._at(")"):
            self._expression_list()
        self._expect(")")

    def _table_constructor(self) -> None:
        self._expect("{")
        while not self._at("}"):
            if self._accept("["):
                self._expression()
                self._expect("]")
                self._expect("=")
                self._expression()
            elif self._current.kind == "name" and self._tokens[self._index + 1].value == "=":
                self._advance()
                self._advance()
                self._expression()
            else:
                self._expression()
            if not (self._accept(",") or self._accept(";")):
                break
        self._expect("}")


def check_lua_syntax(source: str) -> None:
    """Raise unless *source* is a syntactically valid Lua 5.1 chunk.

    Args:
        source: The Lua source to check.

    Raises:
        LuaSyntaxError: With the offending 1-based line number, what was expected, and
            that line's text in :attr:`LuaSyntaxError.source_line`.
    """
    try:
        _Parser(tokenize(source)).parse()
    except LuaSyntaxError as error:
        lines = source.splitlines()
        if 0 < error.line <= len(lines):
            error.source_line = lines[error.line - 1].strip()
        raise
