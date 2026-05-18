"""One-shot migration script: replace veaf.p( with veaf.lp( in Lua log call arguments.

Usage (from workspace root, venv active):
    python -m veaf_libs.migrate_lazy_log [--dry-run]

Rationale:
    formatText() already calls veaf.p() on each argument passed to trace/debug/etc.,
    so callers who write `logger:trace("msg", veaf.p(x))` cause double-serialisation
    AND evaluate veaf.p(x) unconditionally (before the level check in trace()).
    Replacing veaf.p( with veaf.lp( makes the serialisation lazy: the lazy wrapper is
    cheap to create, and veaf.p() is called inside formatText(), i.e. after the level
    check, only when the message will actually be emitted.

    Lines that are NOT migrated automatically (reported as residuals):
      - continuation lines of multi-line log calls (veaf.p( on its own line)
      - lines inside veaf.p() / veaf._p() / veaf.lp() / formatText bodies
      - comment lines
      - :info / :warn / :error calls (those levels are almost always active)
      - string.format() wrapper pattern (needs separate manual refactoring)

    The string.format() wrapper pattern:
        logger:trace(string.format("msg %s", veaf.p(x)))
    can be refactored to:
        logger:trace("msg %s", veaf.lp(x))
    for full lazy-eval benefit, but this is outside the scope of this script.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Log methods whose arguments should be lazy (trace/debug only).
_LOG_METHODS = r"(?:trace|debug|marker|cleanupMarkers)"

# Matches any line that contains a log call for one of the lazy log methods.
# Covers:
#   - Full form:  veaf.loggers.get(...):trace(  /  someLogger:trace(
#   - Continuation: line (possibly indented) starts with :trace( after whitespace
_LOG_LINE_RE = re.compile(
    r"(?:"
    r"(?:veaf\.loggers\.get\([^)]+\)|logger|\w+logger|\w+\.logger):" + _LOG_METHODS + r"\("
    r"|^\s*:" + _LOG_METHODS + r"\("
    r")",
    re.MULTILINE,
)

# Lines that should never be migrated regardless.
_SKIP_PATTERNS = [
    re.compile(r"function veaf\.[l_]?p\("),  # veaf.p() / veaf._p() / veaf.lp() definitions
    re.compile(r"pArgs\[i\]\s*=\s*veaf\.p\("),  # formatText internal
    re.compile(r"text\s*=\s*veaf\.p\("),  # formatText internal (text = veaf.p(text))
    re.compile(r"return veaf\.p\(self\._v\)"),  # veaf.lp() internal
]


# Continuation-arg pattern: an entire line consisting of just a veaf.p() call
# (with leading whitespace and optional trailing comma/close-paren).
# These are continuation lines of multi-line log calls.
# Note: this intentionally excludes lines with other content before/after veaf.p().
_CONTINUATION_ARG_RE = re.compile(r"^(\s+)(veaf\.p\([^)]+\))([,)]*\s*)$")


def _is_comment_line(line: str) -> bool:
    return line.lstrip().startswith("--")


def _should_skip(line: str) -> bool:
    if _is_comment_line(line):
        return True
    return any(p.search(line) for p in _SKIP_PATTERNS)


def _migrate_line(line: str) -> tuple[str, int]:
    """Try to migrate one line.  Returns (new_line, replacement_count)."""
    if _should_skip(line) or "veaf.p(" not in line:
        return line, 0

    if _LOG_LINE_RE.search(line):
        count = line.count("veaf.p(")
        new_line = line.replace("veaf.p(", "veaf.lp(")
        return new_line, count

    # Standalone continuation arg: the entire line is just a veaf.p() call
    # (indented, optional trailing comma/close-paren, nothing else).
    if _CONTINUATION_ARG_RE.match(line):
        count = line.count("veaf.p(")
        return line.replace("veaf.p(", "veaf.lp("), count

    return line, 0


def _migrate_file(path: Path, *, dry_run: bool) -> tuple[int, list[str]]:
    """Migrate one file.  Returns (replacement_count, residual_lines)."""
    original = path.read_text(encoding="utf-8")
    lines = original.splitlines(keepends=True)
    new_lines: list[str] = []
    replacements = 0
    residuals: list[str] = []

    for lineno, line in enumerate(lines, start=1):
        new_line, count = _migrate_line(line)
        new_lines.append(new_line)
        replacements += count

        # Detect residual veaf.p( that we could NOT migrate automatically.
        if count == 0 and "veaf.p(" in line and not _should_skip(line):
            residuals.append(f"  {path.name}:{lineno}: {line.rstrip()}")

    if replacements > 0 and not dry_run:
        path.write_text("".join(new_lines), encoding="utf-8")

    return replacements, residuals


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dry-run", action="store_true", help="Report changes without writing files")
    args = parser.parse_args(argv)

    lua_dir = Path(__file__).parents[3] / "scripts" / "veaf"
    if not lua_dir.is_dir():
        # fallback: try relative to cwd
        lua_dir = Path("src/scripts/veaf")
    if not lua_dir.is_dir():
        print(f"ERROR: cannot find src/scripts/veaf (tried {lua_dir})", file=sys.stderr)
        sys.exit(1)

    lua_files = sorted(lua_dir.glob("*.lua"))
    print(f"Scanning {len(lua_files)} Lua files in {lua_dir} ({'DRY RUN' if args.dry_run else 'WRITE MODE'})...\n")

    total_replacements = 0
    all_residuals: list[str] = []

    for path in lua_files:
        count, residuals = _migrate_file(path, dry_run=args.dry_run)
        if count:
            action = "(would replace)" if args.dry_run else "(replaced)"
            print(f"  {path.name}: {count} veaf.p( -> veaf.lp( {action}")
        total_replacements += count
        all_residuals.extend(residuals)

    print(f"\nTotal replacements: {total_replacements}")

    if all_residuals:
        print(f"\n{'=' * 60}")
        print(f"RESIDUAL veaf.p( NOT migrated automatically ({len(all_residuals)} lines):")
        print("These are typically continuation lines of multi-line log calls.")
        print("Please review and fix manually:\n")
        for line in all_residuals:
            print(line)
        print(f"{'=' * 60}")
    else:
        print("No residual veaf.p( found — migration complete.")


if __name__ == "__main__":
    main()
