"""Stamp the shipped version into the documentation pages that display one.

`LUA_API_REFERENCE` carried **Version 6.5.25 / June 2026** while the project shipped 6.11.8: a
hand-maintained header nobody remembers to bump is worse than no header, because a reader trusts
it. The repository keeps a readable placeholder (a `6.11.x`-style range) and the docs deploy
workflow runs this stamper on its throwaway checkout, so the published page always states the
version it was generated from.

Usage:
    poetry run docs-stamp-version              # rewrite the headers in place
    poetry run docs-stamp-version --check      # report what would change, exit 1 if any
"""

from __future__ import annotations

import argparse
import re
import sys
from datetime import date
from pathlib import Path

_REPO_ROOT = Path(__file__).parent.parent

#: Pages carrying a version header, and the label used in each language.
STAMPED_PAGES: tuple[str, ...] = ("doc/LUA_API_REFERENCE.md", "doc/LUA_API_REFERENCE.en.md")

_VERSION_LINE = re.compile(r"^(\*\*Version\s*:?\*\*)\s*.+$", re.MULTILINE)
_UPDATED_LINE = re.compile(r"^(\*\*(?:Dernière mise à jour|Last Updated)\s*:?\*\*)\s*.+$", re.MULTILINE)
#: The page repeats a version in its footer ("Généré pour : … v6.5.25"). Missed on the first
#: pass and caught by reading the published 6.12.0 page, which still advertised v6.5.25 there.
#: Anchored on the ASCII product name rather than the localised label: one occurrence per page,
#: and no accented literal to get wrong.
_GENERATED_FOR_LINE = re.compile(r"^(\*\*[^*]+\*\*\s*VEAF Mission Creation Tools v)\d[\w.+-]*\s*$", re.MULTILINE)
_PYPROJECT_VERSION = re.compile(r'^version\s*=\s*"([^"]+)"', re.MULTILINE)

_FR_MONTHS = {
    1: "Janvier",
    2: "Février",
    3: "Mars",
    4: "Avril",
    5: "Mai",
    6: "Juin",
    7: "Juillet",
    8: "Août",
    9: "Septembre",
    10: "Octobre",
    11: "Novembre",
    12: "Décembre",
}


def read_version(pyproject: Path) -> str:
    """Return the project version declared in *pyproject*.

    Args:
        pyproject: Path to ``pyproject.toml``.

    Returns:
        The version string, e.g. ``"6.11.9"``.

    Raises:
        ValueError: If no ``version = "..."`` line is present.
    """
    match = _PYPROJECT_VERSION.search(pyproject.read_text(encoding="utf-8"))
    if not match:
        raise ValueError(f"no version found in {pyproject}")
    return match.group(1)


def stamp_text(text: str, version: str, today: date, french: bool) -> str:
    """Return *text* with its version and last-updated headers rewritten.

    Args:
        text: The page's full markdown.
        version: Version to stamp.
        today: Date to stamp (month and year only).
        french: True for the French page, driving the month name and wording.

    Returns:
        The updated markdown (unchanged when the page has no such headers).
    """
    if french:
        version_value = f"générée pour la {version}"
        updated_value = f"{_FR_MONTHS[today.month]} {today.year}"
    else:
        version_value = f"generated for {version}"
        updated_value = f"{today:%B} {today.year}"
    text = _VERSION_LINE.sub(lambda m: f"{m.group(1)} {version_value}", text, count=1)
    # No count here: the header and the footer both carry a date, and both must reflect the build.
    text = _UPDATED_LINE.sub(lambda m: f"{m.group(1)} {updated_value}", text)
    return _GENERATED_FOR_LINE.sub(lambda m: f"{m.group(1)}{version}", text)


def stamp(repo_root: Path, check_only: bool = False, today: date | None = None) -> list[str]:
    """Stamp every page in :data:`STAMPED_PAGES`.

    Args:
        repo_root: Repository root holding ``pyproject.toml`` and ``doc/``.
        check_only: When True, report what would change without writing.
        today: Date to stamp; defaults to today.

    Returns:
        The relative paths whose header changed (or would change).
    """
    version = read_version(repo_root / "pyproject.toml")
    when = today or date.today()
    changed: list[str] = []
    for rel in STAMPED_PAGES:
        page = repo_root / rel
        if not page.exists():
            continue
        original = page.read_text(encoding="utf-8")
        updated = stamp_text(original, version, when, french=not page.name.endswith(".en.md"))
        if updated == original:
            continue
        changed.append(rel)
        if not check_only:
            page.write_text(updated, encoding="utf-8", newline="\n")
    return changed


def main(argv: list[str] | None = None) -> int:
    """CLI entry point.

    Args:
        argv: Argument list; defaults to ``sys.argv[1:]``.

    Returns:
        ``0`` normally; ``1`` in ``--check`` mode when a header is out of date.
    """
    parser = argparse.ArgumentParser(description="Stamp the shipped version into the docs headers.")
    parser.add_argument("--repo-root", type=Path, default=_REPO_ROOT)
    parser.add_argument("--check", action="store_true", help="Report, do not write; exit 1 if stale.")
    args = parser.parse_args(argv)

    changed = stamp(args.repo_root, check_only=args.check)
    if not changed:
        print("docs-stamp-version: headers already up to date.")
        return 0
    verb = "would update" if args.check else "updated"
    print(f"docs-stamp-version: {verb} {len(changed)} page(s): {', '.join(changed)}")
    return 1 if args.check else 0


if __name__ == "__main__":
    sys.exit(main())
