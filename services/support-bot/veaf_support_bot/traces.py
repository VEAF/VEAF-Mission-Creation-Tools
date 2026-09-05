"""Turning a pasted stack trace into a place in the code, without asking a model.

A trace **states** its location. ``File "…/v5_converter.py", line 412, in convert`` is not an
inference, and neither is ``…\\Scripts\\veafSpawn.lua:1234:``. What a maintainer then wants is the
neighbourhood of that line and the functions that call the one it sits in — a read and a search.
Both are exact, both cost nothing, and both keep working when the day's model quota is gone.

## The three steps, and what each is allowed to assume

1. **Find the locations.** A small set of anchored patterns, one per runtime the project ships:
   CPython tracebacks, the tools' own logger records, and DCS Lua errors. Nothing heuristic: a line
   that does not match one of them is not a location.
2. **Map the path onto the checkout.** The path in a trace is a path on the reporter's machine —
   ``C:\\Users\\Someone\\veaf\\src\\...``. It is mapped by matching its **longest existing tail**
   against the checkout, so ``.../mission_builder/v5_converter.py`` resolves and
   ``.../somewhere-else/v5_converter.py`` resolves to the same file only when no longer tail
   distinguishes them. When no tail matches, a **unique** basename does — DCS names a Lua chunk with
   no directory at all — and a basename carried by two files does not, because that answer would be
   a coin toss. A path that matches nothing resolves to nothing, which is the honest answer for a
   file that no longer exists.
3. **Read the neighbourhood and search for callers.** Both bounded, both textual.

## What this module refuses to do

It never treats the trace's text as anything but a coordinate. The pasted text can name
``../../../../etc/passwd`` or ``/proc/self/environ``; the mapping only ever returns files that exist
**inside the checkout** (:meth:`veaf_support_bot.checkout.Checkout.resolve` enforces it), and the
only thing read out of one is a fixed window of lines. There is no branch anywhere in this module
that a line of user text can select.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path, PurePosixPath

from veaf_support_bot.checkout import Checkout

#: How many lines around the faulting line are quoted. Wide enough to hold a small function, narrow
#: enough that three locations still fit in an issue body.
CONTEXT_LINES = 8

#: How many distinct locations are extracted from one report. A deep traceback names dozens of
#: frames; the ones worth quoting are the innermost few in the project's own code.
MAX_LOCATIONS = 3

#: How many call sites are listed per location. A utility called from ninety places produces a list
#: nobody reads; the count is reported in full even when the list is cut.
MAX_CALLERS = 8

#: Files scanned when searching for callers. Everything the project's own code is written in.
SOURCE_SUFFIXES = frozenset({".py", ".lua"})

#: Directories never walked. Build outputs and dependency trees hold copies of the project's own
#: files, and a caller found in one of them points at code nobody edits.
SKIPPED_DIRECTORIES = frozenset(
    {".git", ".venv", "venv", "node_modules", "__pycache__", "build", "dist", ".mypy_cache", ".ruff_cache", ".claude"}
)

#: Largest file opened while searching. A generated Lua table of several megabytes is not a caller.
MAX_SEARCHED_FILE_BYTES = 2 * 1024 * 1024

#: Ceiling on how many files one caller search opens, so a pathological checkout cannot make a
#: report take minutes.
MAX_SEARCHED_FILES = 6000

#: ``File "C:\path\to\module.py", line 412, in convert`` — CPython's own traceback line.
_PYTHON_FRAME = re.compile(r'^\s*File "(?P<path>[^"]+)", line (?P<line>\d+)(?:, in (?P<symbol>\S+))?')

#: ``…\Scripts\veafSpawn.lua:1234: attempt to index a nil value`` — how DCS reports a Lua error, and
#: how ``luacheck`` and ``stylua`` report a position too.
#:
#: The closing ``"]`` is optional and skipped: DCS wraps the chunk name as ``[string "…lua"]:12:``,
#: so a pattern that required the colon to touch the suffix matched nothing at all on the one shape
#: that actually comes out of the game.
_LUA_FRAME = re.compile(r"""(?P<path>[\w./\\:~ -]*?[\w-]+\.lua)["'\]]*:(?P<line>\d+)""")

#: ``  at mission_builder/v5_converter.py:412`` and the shapes the tools' logger writes.
_BARE_FRAME = re.compile(r"""(?P<path>[\w./\\:~ -]*?[\w-]+\.py)["'\]]*:(?P<line>\d+)\b""")

#: A Python ``def`` or a Lua function, for naming the function a line sits in.
_PYTHON_DEF = re.compile(r"^\s*(?:async\s+)?def\s+(?P<name>\w+)\s*\(")
_LUA_DEF = re.compile(r"^\s*(?:local\s+)?function\s+(?P<name>[\w.:]+)\s*\(")


@dataclass(frozen=True)
class Location:
    """One place in the code a trace named, resolved against the checkout.

    Attributes:
        relative: Path relative to the checkout root, using forward slashes.
        line: The 1-based line number the trace stated.
        symbol: The function the trace named, when it named one.
        function: The function the line actually sits in, read from the file.
        excerpt: The quoted neighbourhood, each line prefixed with its number.
        callers: Call sites of :attr:`function` elsewhere in the checkout.
        caller_total: How many call sites were found, which can exceed ``len(callers)``.
    """

    relative: str
    line: int
    symbol: str = ""
    function: str = ""
    excerpt: str = ""
    callers: tuple[str, ...] = ()
    caller_total: int = 0


@dataclass(frozen=True)
class Unresolved:
    """A location the trace stated and the checkout does not have.

    Reported rather than dropped: *"the trace names ``v5_converter.py:412`` and this revision has no
    such file"* tells a maintainer the reporter is on an older build, which a silent omission does
    not.

    Attributes:
        raw: The path exactly as the trace wrote it, before any redaction.
        line: The line number stated.
    """

    raw: str
    line: int


@dataclass(frozen=True)
class TraceReading:
    """Everything the deterministic pass got out of one report's text.

    Attributes:
        locations: Resolved locations, innermost first.
        unresolved: Locations the checkout does not have.
    """

    locations: tuple[Location, ...] = ()
    unresolved: tuple[Unresolved, ...] = ()

    @property
    def found_anything(self) -> bool:
        """Whether the text named a location at all.

        Returns:
            ``True`` when at least one location, resolved or not, was stated.
        """
        return bool(self.locations or self.unresolved)


@dataclass
class _RawFrame:
    """One ``path:line`` a pattern matched, before the checkout is consulted."""

    path: str
    line: int
    symbol: str = ""


def find_frames(text: str) -> list[_RawFrame]:
    """Extract every ``path:line`` the text states, innermost last then reversed.

    A traceback prints the outermost frame first and the failing one last, so the reversal puts the
    frame a maintainer opens first at the top.

    Args:
        text: Any text — the form's fields, the ``doctor`` block's records, a log excerpt.

    Returns:
        The frames, most interesting first, without duplicates.
    """
    frames: list[_RawFrame] = []
    for line in text.splitlines():
        python = _PYTHON_FRAME.match(line)
        if python is not None:
            frames.append(_RawFrame(python["path"], int(python["line"]), python["symbol"] or ""))
            continue
        for pattern in (_LUA_FRAME, _BARE_FRAME):
            found = pattern.search(line)
            if found is not None:
                frames.append(_RawFrame(found["path"], int(found["line"])))
                break

    seen: set[tuple[str, int]] = set()
    unique: list[_RawFrame] = []
    for frame in reversed(frames):
        key = (frame.path, frame.line)
        if key not in seen:
            seen.add(key)
            unique.append(frame)
    return unique


def _tails(raw: str) -> list[str]:
    """Return the candidate repository-relative paths a machine path could be, longest first.

    Args:
        raw: A path as a trace wrote it, in either slash convention.

    Returns:
        Every trailing segment run, e.g. ``["src/python/veaf-tools/veaf_libs/redaction.py",
        "veaf-tools/veaf_libs/redaction.py", "veaf_libs/redaction.py", "redaction.py"]``.
    """
    parts = [part for part in raw.replace("\\", "/").split("/") if part not in ("", ".", "..")]
    # A Windows drive letter is not a path segment anywhere in the repository.
    if parts and re.fullmatch(r"[A-Za-z]:", parts[0]):
        parts = parts[1:]
    return ["/".join(parts[index:]) for index in range(len(parts))]


def resolve_frame(checkout: Checkout, frame: _RawFrame) -> Path | None:
    """Map one machine path onto a file inside the checkout.

    The **longest** tail that exists wins, so a path that carries enough of its directory structure
    is matched precisely and a bare basename is only used when nothing longer matched.

    Args:
        checkout: The working copy.
        frame: The frame to resolve.

    Returns:
        The file, or ``None`` when the checkout has nothing matching.
    """
    for tail in _tails(frame.path):
        found = checkout.resolve(tail)
        if found is not None:
            return found
    return unique_by_name(checkout.root.resolve(), PurePosixPath(frame.path.replace("\\", "/")).name)


def unique_by_name(root: Path, basename: str) -> Path | None:
    """Find a file by name alone, but only when exactly one file carries it.

    DCS names a Lua chunk with no directory at all — ``[string "veafSpawn.lua"]:12:`` — so without
    this a real in-game error would resolve to nothing. The uniqueness condition is what keeps that
    from becoming a guess: two files sharing a name make the answer *unknown*, which is reported as
    unresolved rather than picked at random.

    Args:
        root: The checkout root.
        basename: The file name, with no directory part.

    Returns:
        The one file with that name, or ``None`` when there are none or several.
    """
    if not basename or "/" in basename or "\\" in basename:
        return None
    matches = [path for path in _searchable_files(root) if path.name == basename]
    return matches[0] if len(matches) == 1 else None


def _read_lines(path: Path) -> list[str]:
    """Read a source file as text, tolerating whatever encoding it is in.

    Args:
        path: The file.

    Returns:
        Its lines without terminators, or an empty list when it cannot be read.
    """
    try:
        return path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return []


def enclosing_function(lines: list[str], line_number: int) -> str:
    """Name the function a line sits in, by scanning upwards for its definition.

    Args:
        lines: The file's lines.
        line_number: 1-based line the trace named.

    Returns:
        The function name, or an empty string when the line sits at module level or the definition
        could not be found.
    """
    for index in range(min(line_number, len(lines)) - 1, -1, -1):
        for pattern in (_PYTHON_DEF, _LUA_DEF):
            found = pattern.match(lines[index])
            if found is not None:
                return found["name"]
    return ""


def quote_neighbourhood(lines: list[str], line_number: int, context: int = CONTEXT_LINES) -> str:
    """Render the lines around *line_number*, numbered, with the faulting one marked.

    Args:
        lines: The file's lines.
        line_number: 1-based line to centre on.
        context: Lines kept on each side.

    Returns:
        The quoted window, or an empty string when the file is shorter than the stated line — which
        is itself a fact worth having, and the caller reports it.
    """
    if not lines or line_number < 1 or line_number > len(lines):
        return ""
    first = max(1, line_number - context)
    last = min(len(lines), line_number + context)
    width = len(str(last))
    return "\n".join(
        f"{'>' if number == line_number else ' '} {str(number).rjust(width)} | {lines[number - 1]}"
        for number in range(first, last + 1)
    )


def _searchable_files(root: Path) -> list[Path]:
    """Walk the checkout for files worth searching for call sites.

    Args:
        root: The checkout root.

    Returns:
        The files, capped at :data:`MAX_SEARCHED_FILES`.
    """
    found: list[Path] = []
    stack = [root]
    while stack and len(found) < MAX_SEARCHED_FILES:
        current = stack.pop()
        try:
            entries = list(current.iterdir())
        except OSError:
            continue
        for entry in entries:
            if entry.is_dir():
                if entry.name not in SKIPPED_DIRECTORIES:
                    stack.append(entry)
            elif entry.suffix in SOURCE_SUFFIXES:
                found.append(entry)
                if len(found) >= MAX_SEARCHED_FILES:
                    break
    return found


def find_callers(
    root: Path,
    function: str,
    defined_in: Path,
    files: list[Path] | None = None,
) -> tuple[tuple[str, ...], int]:
    """Search the checkout for places that call *function*.

    A textual search, deliberately: resolving calls properly would need to import a tree written in
    two languages, and the value here is a list of files to open, not a call graph.

    Args:
        root: The checkout root.
        function: The function name; a Lua ``module.name`` is matched on its last segment too.
        defined_in: The file holding the definition, whose own recursive calls are not call sites.
        files: The files to search; defaults to walking the checkout. :func:`read_trace` walks once
            and passes the list, so three locations in one report do not cost three walks.

    Returns:
        A pair: up to :data:`MAX_CALLERS` ``path:line`` strings, and the total number found.
    """
    if not function:
        return (), 0
    bare = function.split(".")[-1].split(":")[-1]
    if not bare.isidentifier():
        return (), 0
    pattern = re.compile(rf"(?<![\w.:]){re.escape(bare)}\s*\(")
    definition = re.compile(rf"^\s*(?:async\s+)?(?:def|local\s+function|function)\s+[\w.:]*{re.escape(bare)}\s*\(")

    hits: list[str] = []
    total = 0
    for path in sorted(_searchable_files(root) if files is None else files):
        try:
            if path.stat().st_size > MAX_SEARCHED_FILE_BYTES:
                continue
        except OSError:
            continue
        if path == defined_in:
            continue
        for number, line in enumerate(_read_lines(path), start=1):
            if definition.match(line) or not pattern.search(line):
                continue
            total += 1
            if len(hits) < MAX_CALLERS:
                hits.append(f"{path.relative_to(root).as_posix()}:{number}")
    return tuple(hits), total


def read_trace(checkout: Checkout, text: str, *, max_locations: int = MAX_LOCATIONS) -> TraceReading:
    """Do the whole deterministic pass over one report's text.

    Args:
        checkout: The working copy the locations are resolved against.
        text: The report's text, however it was assembled.
        max_locations: How many resolved locations to build in full.

    Returns:
        The reading. Locations the checkout does not have are listed separately rather than dropped.
    """
    root = checkout.root.resolve()
    locations: list[Location] = []
    unresolved: list[Unresolved] = []
    searchable: list[Path] | None = None

    for frame in find_frames(text):
        if len(locations) >= max_locations:
            break
        resolved = resolve_frame(checkout, frame)
        if resolved is None:
            unresolved.append(Unresolved(raw=frame.path, line=frame.line))
            continue
        lines = _read_lines(resolved)
        function = frame.symbol or enclosing_function(lines, frame.line)
        if searchable is None:
            searchable = _searchable_files(root)
        callers, total = find_callers(root, function, resolved, searchable)
        locations.append(
            Location(
                relative=resolved.relative_to(root).as_posix(),
                line=frame.line,
                symbol=frame.symbol,
                function=function,
                excerpt=quote_neighbourhood(lines, frame.line),
                callers=callers,
                caller_total=total,
            )
        )
    return TraceReading(locations=tuple(locations), unresolved=tuple(unresolved))


#: Kept so a caller can build a frame without reaching for a private name.
RawFrame = _RawFrame
