"""The facts a bug report is always missing, collected from the machine that has them.

Measured on the repository's own history: what a report lacks is never the story — the regulars
attach the log, the mission and sometimes the fix — it is the three mechanical facts nobody thinks
to write down. **Which version of the tool, which version of DCS, on which machine.** A model
cannot deduce them; it can only ask someone who does not know them either.

So this module reads them out, and produces two things from one collection pass:

- a **structured report** (:class:`DiagnosticReport`) the console command renders as a table;
- a **paste block** (:meth:`DiagnosticReport.to_block`), versioned and parseable, which is the
  contract two later lots consume — ``FEAT-SUPPORT-LOG-ANALYSIS`` embeds it in its report block and
  ``FEAT-SUPPORT-BUG-INTAKE`` parses it back. :func:`parse_block` is that inverse, kept here so the
  two halves cannot drift; the format itself is documented in
  ``doc/developer/diagnostic-block.md``.

Two rules govern everything below.

**Nothing may crash.** A diagnostic command that dies on the machine being diagnosed is worthless,
and every field here reads something that can be absent: DCS is not installed, ``VEAF_HOME`` points
nowhere, the log has never been written. Each collector is guarded on its own and an unavailable
field reports :data:`UNKNOWN` while the rest is still produced.

**Nothing personal escapes.** Everything here is designed to be pasted into a public issue, so it
goes through :func:`veaf_libs.redaction.redact` before it is returned — not at publication time,
which happens in a different program on a different machine.
"""

from __future__ import annotations

import locale as locale_module
import platform
import re
import shutil
import sys
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path

from veaf_libs.redaction import redact, redact_path

#: Identifies the paste block's format. Consumers must check it before parsing: a block carrying an
#: unknown schema is a block whose fields they cannot assume anything about.
SCHEMA = "veaf-tools-doctor/1"

#: Delimiters of the paste block. Deliberately unmistakable, because the block travels through
#: Discord and GitHub Markdown and has to be found again in the middle of prose.
BLOCK_START = "=== VEAF-TOOLS DOCTOR BEGIN ==="
BLOCK_END = "=== VEAF-TOOLS DOCTOR END ==="

#: Delimiters of the free-text section holding the recent log records. Everything between them is
#: raw text (a traceback keeps its own line structure); everything outside is ``key: value``.
ERRORS_START = "--- recent-errors ---"
ERRORS_END = "--- recent-errors end ---"

#: What a field reports when the machine cannot answer. Never an empty string: absent and unknown
#: read the same to a human, and a consumer must be able to tell "no DCS" from "field not collected".
UNKNOWN = "unknown"

#: The fields, in the order the block writes them. **This tuple is the contract.** Adding a field is
#: backwards compatible for a parser that reads what it knows; removing or renaming one is not, and
#: bumps :data:`SCHEMA`.
FIELD_ORDER: tuple[str, ...] = (
    "schema",
    "generated",
    "tool.version",
    "tool.packaging",
    "tool.executable",
    "tool.python",
    "machine.os",
    "machine.locale",
    "machine.free_space",
    "dcs.detected",
    "dcs.version",
    "dcs.variant",
    "dcs.write_dir",
    "dcs.log_age",
    "veaf.home",
    "veaf.log",
    "veaf.lua_modules",
)

#: Every line break inside a field name or value. A field is **one line** — that is the whole of the
#: format's field section — so a value carrying a newline would come back as two fields, the second
#: of them forged. No collector can produce one today, but ``FEAT-SUPPORT-BUG-INTAKE`` runs
#: :func:`parse_block` over text a stranger pasted into a public issue, so the producer collapses
#: them rather than leaving the invariant to the reader's goodwill.
_LINE_BREAK = re.compile(r"[\r\n]+")

#: How many log records :func:`collect_recent_errors` returns by default.
DEFAULT_ERROR_COUNT = 3

#: How many lines of one record survive. A traceback through a deep call stack is not more
#: informative for being complete, and the block has to fit a Discord message.
MAX_LINES_PER_ERROR = 25

#: How wide one line of a record may be. Measured on a real log: a single record quoting a rejected
#: expression ran past 400 characters on one line, which no amount of line-capping would have
#: bounded. Truncation is marked so a reader knows the line is not the whole story.
MAX_CHARS_PER_LINE = 300

#: Appended to a line cut at :data:`MAX_CHARS_PER_LINE`.
TRUNCATION_MARK = " […]"

#: How much of the tail of the log file is read. The log rotates at 2 MB (see
#: :mod:`veaf_libs.logger`), and the last few error records are always near the end.
_LOG_TAIL_BYTES = 512 * 1024

#: How far the rolled-over logs (``veaf-tools.log.1``, ``.2``…) are followed when the live file does
#: not hold enough records. The handler keeps three, but the number is probed rather than imported:
#: the first rollover after an upgrade moves the *whole* previous log — 87 MB was measured on a real
#: machine — into ``.1`` and leaves a 28-byte live file, and reading only the live file would have
#: answered "no recent errors" to the very user reporting a crash.
_MAX_ROLLED_LOGS = 9

#: A record header written by the file formatter: ``2026-09-05 12:00:00,123 - veaf-tools - ERROR - …``
_RECORD_HEADER = re.compile(r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2},\d{3} - \S+ - (?P<level>[A-Z]+) - ")

#: ``INFO    APP (Main): DCS/2.9.29.27278 (x86_64; MT; Windows NT 10.0.26200)`` — measured against a
#: real ``dcs.log`` on 2026-09-05. The version is the only reliable place DCS states itself.
_DCS_VERSION = re.compile(r"\bDCS/(\d+(?:\.\d+)+)")

#: How many lines of ``dcs.log`` are scanned for that banner. It sits on line 6; a hundred is slack.
_DCS_HEADER_LINES = 100


@dataclass(frozen=True)
class DiagnosticReport:
    """One collection pass: the fields, plus the recent error records already redacted."""

    fields: dict[str, str] = field(default_factory=dict)
    """Field name to value, keyed by :data:`FIELD_ORDER`. Every key is present; missing data is
    :data:`UNKNOWN`."""

    recent_errors: list[str] = field(default_factory=list)
    """The most recent error records from the tool's log, oldest first, redacted."""

    def to_block(self) -> str:
        """Render the paste block: the versioned, parseable form of this report.

        A field name and its value are each collapsed onto **one line**: the reader splits the field
        section by line, so a value carrying a newline would come back as two fields and the second
        would be one the producer never wrote.

        Returns:
            The block, delimited by :data:`BLOCK_START` and :data:`BLOCK_END`, without a trailing
            newline. Fields come in :data:`FIELD_ORDER`; anything else the report happens to carry
            follows in insertion order, so an added field never disappears silently.
        """
        lines = [BLOCK_START]
        ordered = [name for name in FIELD_ORDER if name in self.fields]
        extras = [name for name in self.fields if name not in FIELD_ORDER]
        for name in ordered + extras:
            lines.append(f"{_one_line(name)}: {_one_line(self.fields[name])}")
        if self.recent_errors:
            lines.append(ERRORS_START)
            for record in self.recent_errors:
                lines.extend(record.splitlines())
            lines.append(ERRORS_END)
        lines.append(BLOCK_END)
        return "\n".join(lines)


def _one_line(value: str) -> str:
    """Collapse *value* onto a single line, so one field stays one line of the block.

    Args:
        value: A field name or a field value.

    Returns:
        The same text with every run of line breaks turned into a space, trimmed at both ends.
    """
    return _LINE_BREAK.sub(" ", value).strip()


def parse_block(text: str) -> DiagnosticReport:
    """Read a paste block back into a report — the inverse of :meth:`DiagnosticReport.to_block`.

    The intake flow of ``FEAT-SUPPORT-BUG-INTAKE`` receives this block inside a free-form message,
    so the parser locates the delimiters rather than assuming the block starts at the first line.

    **What comes back is untrusted.** The block travels through a public issue and anyone can type
    one by hand: a field name and a value are only ever what the text said they were. The producer
    guarantees the *shape* (:func:`_one_line`), never the truth of a value — a consumer that acts on
    ``tool.version`` must treat it as a claim, not as a reading taken from the machine.

    Args:
        text: Any text containing exactly one block.

    Returns:
        The parsed report. Records are split back apart on their header lines, so a multi-line
        traceback comes back as one entry.

    Raises:
        ValueError: No block, or a block missing its end delimiter — a truncated paste, which must
            be reported rather than half-parsed.
    """
    lines = text.splitlines()
    try:
        start = next(i for i, line in enumerate(lines) if line.strip() == BLOCK_START)
        end = next(i for i, line in enumerate(lines) if i > start and line.strip() == BLOCK_END)
    except StopIteration as exc:
        raise ValueError(f"no complete {SCHEMA} block found") from exc

    fields: dict[str, str] = {}
    records: list[str] = []
    current: list[str] = []
    in_errors = False
    for line in lines[start + 1 : end]:
        stripped = line.strip()
        if stripped == ERRORS_START:
            in_errors = True
            continue
        if stripped == ERRORS_END:
            in_errors = False
            if current:
                records.append("\n".join(current))
                current = []
            continue
        if in_errors:
            if _RECORD_HEADER.match(line) and current:
                records.append("\n".join(current))
                current = []
            current.append(line)
            continue
        name, separator, value = line.partition(":")
        if separator:
            fields[name.strip()] = value.strip()
    if current:
        records.append("\n".join(current))
    return DiagnosticReport(fields=fields, recent_errors=records)


# ---------------------------------------------------------------------------
# Collectors
# ---------------------------------------------------------------------------


def _guarded(keys: tuple[str, ...], collector: Callable[[], dict[str, str]]) -> dict[str, str]:
    """Run *collector*, filling in :data:`UNKNOWN` for whatever it does not or cannot answer.

    Args:
        keys: Every field the collector is responsible for.
        collector: The collection function.

    Returns:
        A mapping over exactly *keys*. A collector that raises costs its own fields, not the report.
    """
    result = dict.fromkeys(keys, UNKNOWN)
    try:
        answered = collector()
    except Exception:
        return result
    for name, value in answered.items():
        if name in result and value:
            result[name] = value
    return result


def _collect_tool() -> dict[str, str]:
    """Read what the tool knows about itself: version, packaging, interpreter."""
    from veaf_tools.app import VERSION

    return {
        "tool.version": VERSION,
        "tool.packaging": "frozen" if getattr(sys, "frozen", False) else "source",
        "tool.executable": redact_path(sys.executable),
        "tool.python": platform.python_version(),
    }


def _collect_machine() -> dict[str, str]:
    """Read the operating system, the active locale and the free space where the tool is running."""
    try:
        language = locale_module.getlocale()[0] or UNKNOWN
    except ValueError:
        language = UNKNOWN
    encoding = locale_module.getpreferredencoding(False) or UNKNOWN
    cwd = Path.cwd()
    usage = shutil.disk_usage(cwd)
    return {
        "machine.os": platform.platform(),
        "machine.locale": f"{language} / {encoding}",
        "machine.free_space": f"{usage.free / (1024**3):.1f} GB on {redact_path(cwd.anchor) or UNKNOWN}",
    }


def find_dcs_write_dirs(home: Path | None = None) -> list[Path]:
    """Return the DCS *Saved Games* folders that hold a log, most recently used first.

    A machine commonly carries several: ``DCS`` beside ``DCS.openbeta``, plus the per-module folders
    the updater leaves behind (``DCS_F14``, ``DCS.C130J``…). Only those with a ``Logs/dcs.log``
    are real instances, and the one whose log is freshest is the one the user just played.

    Args:
        home: The user's home directory. Defaults to the real one; the parameter exists so a test
            can point at a fixture instead of the machine running it.

    Returns:
        The matching folders, freshest log first. Empty when DCS is absent — the normal case on a
        workstation without the game.
    """
    base = (home or Path.home()) / "Saved Games"
    if not base.is_dir():
        return []
    candidates = [
        entry
        for entry in base.iterdir()
        if entry.is_dir() and entry.name.upper().startswith("DCS") and (entry / "Logs" / "dcs.log").is_file()
    ]
    return sorted(candidates, key=lambda entry: (entry / "Logs" / "dcs.log").stat().st_mtime, reverse=True)


def read_dcs_version(dcs_log: Path) -> str:
    """Extract the DCS version from the header of a ``dcs.log``.

    DCS states it once, on the sixth line, as ``DCS/2.9.29.27278 (x86_64; MT; Windows NT …)``.
    Reading the log rather than the install directory works for every install layout and needs no
    guess about where the game was put.

    Args:
        dcs_log: Path to a ``dcs.log``.

    Returns:
        The dotted version, or :data:`UNKNOWN` when the banner is absent or the file unreadable.
    """
    try:
        with dcs_log.open(encoding="utf-8", errors="replace") as handle:
            for _ in range(_DCS_HEADER_LINES):
                line = handle.readline()
                if not line:
                    break
                if match := _DCS_VERSION.search(line):
                    return match.group(1)
    except OSError:
        return UNKNOWN
    return UNKNOWN


def _dcs_variant(folder_name: str) -> str:
    """Name the branch a write folder belongs to, from its folder name."""
    suffix = folder_name[len("DCS") :].lstrip("._-")
    return suffix.lower() if suffix else "stable"


def _humanise_age(seconds: float) -> str:
    """Render an age in the largest unit that keeps it readable."""
    if seconds < 60:
        return f"{int(seconds)} s"
    if seconds < 3600:
        return f"{int(seconds // 60)} min"
    if seconds < 86400:
        return f"{int(seconds // 3600)} h"
    return f"{int(seconds // 86400)} d"


def _collect_dcs(home: Path | None = None) -> dict[str, str]:
    """Read the DCS install: which branch, which version, how stale its log is."""
    folders = find_dcs_write_dirs(home)
    if not folders:
        return {
            "dcs.detected": "no",
            "dcs.version": UNKNOWN,
            "dcs.variant": UNKNOWN,
            "dcs.write_dir": UNKNOWN,
            "dcs.log_age": UNKNOWN,
        }
    folder = folders[0]
    log = folder / "Logs" / "dcs.log"
    age = datetime.now(tz=UTC).timestamp() - log.stat().st_mtime
    return {
        "dcs.detected": "yes",
        "dcs.version": read_dcs_version(log),
        "dcs.variant": _dcs_variant(folder.name),
        "dcs.write_dir": redact_path(folder),
        "dcs.log_age": _humanise_age(age),
    }


def _humanise_size(size: int) -> str:
    """Render a byte count in the largest unit that keeps it readable."""
    if size < 1024:
        return f"{size} B"
    if size < 1024**2:
        return f"{size / 1024:.0f} KB"
    return f"{size / 1024**2:.1f} MB"


def _collect_veaf() -> dict[str, str]:
    """Read the VEAF home: where it is, whether the tool's log exists, how many Lua modules ship."""
    from veaf_libs.lua_module_scanner import get_modules
    from veaf_libs.veaf_home import get_veaf_home

    home = get_veaf_home()
    log = home / "veaf-tools.log"
    log_state = f"present, {_humanise_size(log.stat().st_size)}" if log.is_file() else "absent"
    try:
        modules = str(len(get_modules()))
    except Exception:
        modules = UNKNOWN
    return {
        "veaf.home": redact_path(home),
        "veaf.log": log_state,
        "veaf.lua_modules": modules,
    }


def tool_log_path() -> Path:
    """Return where the tool writes its own log — the single answer the documentation must give.

    Returns:
        ``$VEAF_HOME/veaf-tools.log``, i.e. ``~/.veaf/veaf-tools.log`` unless the environment
        overrides it.
    """
    from veaf_libs.veaf_home import get_veaf_home

    return get_veaf_home() / "veaf-tools.log"


def collect_recent_errors(count: int = DEFAULT_ERROR_COUNT, log_path: Path | None = None) -> list[str]:
    """Return the last error records written to the tool's log, redacted.

    A record is a header line plus every continuation line under it, so a stack trace comes back
    whole rather than as its first line. Only the tail of the file is read: the log rotates, and the
    records worth reading are always the last ones.

    Args:
        count: How many records to return, most recent last.
        log_path: The log to read. Defaults to :func:`tool_log_path`.

    Returns:
        The records, oldest first, each capped at :data:`MAX_LINES_PER_ERROR` lines and redacted.
        Empty when the log is absent or holds no error — both normal.
    """
    if count <= 0:
        return []
    path = log_path or tool_log_path()
    records: list[list[str]] = []
    for candidate in _log_files_newest_first(path):
        records = _error_records_in(candidate) + records
        if len(records) >= count:
            break
    trimmed = ["\n".join(_cap_line(line) for line in record[:MAX_LINES_PER_ERROR]) for record in records[-count:]]
    return [redact(record) for record in trimmed]


def _log_files_newest_first(path: Path) -> list[Path]:
    """Return the live log and the rolled-over files behind it, newest first.

    Args:
        path: The live log file.

    Returns:
        ``[log, log.1, log.2, …]``, stopping at the first one that does not exist.
    """
    files = [path]
    for index in range(1, _MAX_ROLLED_LOGS + 1):
        rolled = path.with_name(f"{path.name}.{index}")
        if not rolled.is_file():
            break
        files.append(rolled)
    return files


def _error_records_in(path: Path) -> list[list[str]]:
    """Return the error records held in the tail of one log file, oldest first.

    Args:
        path: A live or rolled-over log file; one that does not exist yields nothing.

    Returns:
        One list of lines per ``ERROR``/``CRITICAL`` record, the header line first.
    """
    try:
        if not path.is_file():
            return []
        with path.open("rb") as handle:
            size = path.stat().st_size
            handle.seek(max(0, size - _LOG_TAIL_BYTES))
            raw = handle.read().decode("utf-8", errors="replace")
    except OSError:
        return []

    records: list[list[str]] = []
    keeping = False
    for line in raw.splitlines():
        if match := _RECORD_HEADER.match(line):
            keeping = match.group("level") in ("ERROR", "CRITICAL")
            if keeping:
                records.append([line])
            continue
        if keeping and records:
            records[-1].append(line)
    return records


def _cap_line(line: str) -> str:
    """Cut one record line to :data:`MAX_CHARS_PER_LINE`, marking it when something was dropped."""
    return line if len(line) <= MAX_CHARS_PER_LINE else line[:MAX_CHARS_PER_LINE] + TRUNCATION_MARK


def build_report(
    error_count: int = DEFAULT_ERROR_COUNT,
    home: Path | None = None,
    log_path: Path | None = None,
) -> DiagnosticReport:
    """Collect every field and return the report.

    Args:
        error_count: How many recent error records to include; ``0`` includes none.
        home: The user's home directory, for locating DCS. Defaults to the real one.
        log_path: The tool's log file. Defaults to :func:`tool_log_path`.

    Returns:
        A report whose ``fields`` cover exactly :data:`FIELD_ORDER`. A field the machine cannot
        answer is :data:`UNKNOWN`; nothing raises.
    """
    fields: dict[str, str] = {
        "schema": SCHEMA,
        "generated": datetime.now(tz=UTC).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    fields.update(_guarded(("tool.version", "tool.packaging", "tool.executable", "tool.python"), _collect_tool))
    fields.update(_guarded(("machine.os", "machine.locale", "machine.free_space"), _collect_machine))
    fields.update(
        _guarded(
            ("dcs.detected", "dcs.version", "dcs.variant", "dcs.write_dir", "dcs.log_age"),
            lambda: _collect_dcs(home),
        )
    )
    fields.update(_guarded(("veaf.home", "veaf.log", "veaf.lua_modules"), _collect_veaf))
    try:
        errors = collect_recent_errors(error_count, log_path)
    except Exception:
        errors = []
    return DiagnosticReport(fields={name: fields[name] for name in FIELD_ORDER}, recent_errors=errors)
