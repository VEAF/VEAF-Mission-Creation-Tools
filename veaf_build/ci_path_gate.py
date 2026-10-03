"""Decide whether a pull request touches the paths a CI gate watches.

A workflow filtered with ``on.pull_request.paths`` does not start at all on a pull request outside
those paths, so a check it owns, once *required*, waits as *Expected* for ever and blocks the merge.
A job skipped by its own ``if:`` reports *Skipped* instead, which a required check accepts. So the
gated workflows trigger on every pull request and run this first, in a ``changes`` job; the real
jobs run only when it answers ``run=true``.

Stdlib only, and run as a plain script (``python3 veaf_build/ci_path_gate.py``): it executes before
any dependency is installed.

Usage::

    GATE_PATHS="doc/**
    *.md" python3 veaf_build/ci_path_gate.py <base-sha> <head-sha>
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from collections.abc import Iterable


def _pattern_to_regex(pattern: str) -> re.Pattern[str]:
    """Translate a GitHub trigger-path glob into a regular expression.

    Args:
        pattern: A glob as written under ``paths:`` — ``*`` stays inside one path segment, ``**``
            crosses segments, ``?`` is one character other than ``/``.

    Returns:
        The compiled expression, to be used with ``fullmatch``.
    """
    parts: list[str] = []
    index = 0
    while index < len(pattern):
        if pattern.startswith("**", index):
            parts.append(".*")
            index += 2
        elif pattern[index] == "*":
            parts.append("[^/]*")
            index += 1
        elif pattern[index] == "?":
            parts.append("[^/]")
            index += 1
        else:
            parts.append(re.escape(pattern[index]))
            index += 1
    return re.compile("".join(parts))


def path_matches(path: str, pattern: str) -> bool:
    """Tell whether a repository-relative path matches one trigger-path glob.

    Args:
        path: A changed file, as ``git diff --name-only`` prints it.
        pattern: A glob as written under ``paths:``.

    Returns:
        True when the whole path matches.
    """
    return _pattern_to_regex(pattern).fullmatch(path) is not None


def any_path_matches(paths: Iterable[str], patterns: Iterable[str]) -> bool:
    """Tell whether any changed file falls under any of the gate's patterns.

    Args:
        paths: The changed files.
        patterns: The gate's trigger-path globs.

    Returns:
        True when at least one file matches at least one pattern.
    """
    compiled = [_pattern_to_regex(pattern) for pattern in patterns]
    return any(regex.fullmatch(path) for path in paths for regex in compiled)


def main(argv: list[str]) -> int:
    """Print the changed files that matter and write ``run=true|false`` for the workflow.

    Args:
        argv: ``[base_sha, head_sha]``.

    Returns:
        The process exit code.
    """
    if len(argv) != 2:
        sys.stderr.write("usage: ci_path_gate.py <base-sha> <head-sha>\n")
        return 2
    patterns = [line.strip() for line in os.environ.get("GATE_PATHS", "").splitlines() if line.strip()]
    if not patterns:
        sys.stderr.write("GATE_PATHS is empty: refusing to decide, the gate runs\n")
        decision = True
    else:
        changed = subprocess.run(
            ["git", "diff", "--name-only", argv[0], argv[1]],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.splitlines()
        decision = any_path_matches(changed, patterns)
        sys.stdout.write(f"{len(changed)} changed file(s); gate {'runs' if decision else 'is skipped'}\n")
    line = f"run={'true' if decision else 'false'}\n"
    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a", encoding="utf-8") as handle:
            handle.write(line)
    sys.stdout.write(line)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
