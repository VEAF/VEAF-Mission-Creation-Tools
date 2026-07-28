"""Guard the published documentation against silent rot.

The DOC-AUDIT-PASS audit found eight real defects that no gate would have caught: an English page
missing for months (its EN URL served French), six links returning 404 in production, cross-page
anchors left behind by a section renumbering, and a page absent from every menu. This module is
that gate.

Two things it gets deliberately right, because getting them wrong produces a flood of false
positives — both were verified against the published HTML during the audit:

- **Relative links are language-agnostic.** ``mkdocs-static-i18n`` rewrites them, so an EN page
  linking to ``page.md`` is served ``page/`` resolved inside ``/en/``. Such a link is correct; only
  a *missing target* is a defect. Anchors, however, are **not** rewritten, so an anchor is checked
  against the file the reader actually lands on (the EN twin, from an EN page).
- **Anchors keep their accents.** ``pymdownx.slugify(case=lower)`` does not transliterate, so
  ``#étape-1--préréglages-radio-presetsyaml`` is a valid id. An ASCII-folding slugifier reports
  every accented anchor as broken.

Run with ``poetry run docs-check`` (or ``veaf-build docs-check``); the CI ``docs-check`` job runs
the same entry point.
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field, fields
from pathlib import Path

#: Pages that legitimately sit outside the nav and have no translation: repo notes about the
#: documentation itself, not documentation pages.
EXEMPT: frozenset[str] = frozenset({"assets/img/README.md"})

_LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+?)(?:\s+\"[^\"]*\")?\)")
_HEADING = re.compile(r"^#{1,6}\s+(.*?)\s*$", re.MULTILINE)
_EXPLICIT_ANCHOR = re.compile(r"\{#([A-Za-z0-9_-]+)\}\s*$")
#: mkdocs.yml carries a `!!python/object/apply` tag, so it cannot go through yaml.safe_load;
#: the nav is a flat list of `key: path.md` lines, which this reads directly.
_NAV_ENTRY = re.compile(r":\s*([A-Za-z0-9_./-]+\.md)\s*$", re.MULTILINE)


def slugify(title: str) -> str:
    """Return the anchor id mkdocs generates for a heading.

    Mirrors ``pymdownx.slugs.slugify(case="lower")`` as configured in ``mkdocs.yml``: inline code
    and emphasis markers are dropped, punctuation is stripped, spaces become dashes, and
    **accents are preserved**.

    Args:
        title: The heading text, with or without a trailing explicit ``{#anchor}``.

    Returns:
        The generated anchor id.
    """
    title = _EXPLICIT_ANCHOR.sub("", title).strip()
    title = re.sub(r"[`*_]", "", title)
    return re.sub(r"[^\w\- ]", "", title, flags=re.UNICODE).strip().lower().replace(" ", "-")


def anchors_of(page: Path) -> tuple[set[str], set[str]]:
    """Return the anchors a page exposes, split by kind.

    Args:
        page: Path to a markdown page.

    Returns:
        ``(all_anchors, explicit_anchors)`` — explicit ones are those declared with
        ``{#anchor}``, which survive a heading reword and are shared across languages.
    """
    every: set[str] = set()
    explicit: set[str] = set()
    for title in _HEADING.findall(page.read_text(encoding="utf-8")):
        match = _EXPLICIT_ANCHOR.search(title)
        if match:
            every.add(match.group(1))
            explicit.add(match.group(1))
        every.add(slugify(title))
    return every, explicit


def _twin(page: Path) -> Path:
    """Return the English counterpart of a French page (``x.md`` → ``x.en.md``)."""
    return page.parent / (page.name[:-3] + ".en.md")


@dataclass
class Report:
    """Everything the check found, one list per defect kind."""

    broken_links: list[str] = field(default_factory=list)
    dead_anchors: list[str] = field(default_factory=list)
    implicit_anchors: list[str] = field(default_factory=list)
    missing_translations: list[str] = field(default_factory=list)
    nav_orphans: list[str] = field(default_factory=list)
    nav_dangling: list[str] = field(default_factory=list)

    @property
    def total(self) -> int:
        """Number of defects across every kind."""
        return sum(len(getattr(self, entry.name)) for entry in fields(self))


def check_docs(doc_dir: Path, mkdocs_yml: Path, require_explicit_anchors: bool = True) -> Report:
    """Audit the documentation tree and return everything that is wrong.

    Args:
        doc_dir: The ``docs_dir`` root (``doc/``).
        mkdocs_yml: Path to ``mkdocs.yml``, read for its ``nav``.
        require_explicit_anchors: When True, a cross-page link whose anchor is derived from a
            heading (rather than declared with ``{#anchor}``) is reported: such a link breaks on
            the next reword and differs between languages.

    Returns:
        A :class:`Report`; ``report.total == 0`` means the documentation is clean.
    """
    report = Report()
    pages = sorted(doc_dir.rglob("*.md"))
    fr_pages = [p for p in pages if not p.name.endswith(".en.md")]

    nav_text = mkdocs_yml.read_text(encoding="utf-8").split("\nnav:", 1)[-1]
    nav_targets = set(_NAV_ENTRY.findall(nav_text))

    for page in pages:
        rel = page.relative_to(doc_dir).as_posix()
        is_en = page.name.endswith(".en.md")
        for target in _LINK.findall(page.read_text(encoding="utf-8")):
            if target.startswith(("http://", "https://", "mailto:", "#")):
                continue
            path_part, _, anchor = target.partition("#")
            if not path_part.endswith(".md"):
                continue
            resolved = (page.parent / path_part).resolve()
            if not resolved.exists():
                report.broken_links.append(f"{rel} -> {target}")
                continue
            if not anchor:
                continue
            # Anchors are not rewritten by the i18n plugin: check the page the reader lands on.
            if is_en and not path_part.endswith(".en.md") and _twin(resolved).exists():
                resolved = _twin(resolved)
            every, explicit = anchors_of(resolved)
            landed = resolved.relative_to(doc_dir.resolve()).as_posix()
            if anchor not in every:
                report.dead_anchors.append(f"{rel} -> {target} (no '{anchor}' in {landed})")
            elif require_explicit_anchors and anchor not in explicit:
                report.implicit_anchors.append(f"{rel} -> {target} (add {{#{anchor}}} in {landed})")

    for page in fr_pages:
        rel = page.relative_to(doc_dir).as_posix()
        if rel in EXEMPT:
            continue
        if not _twin(page).exists():
            report.missing_translations.append(rel)
        if rel not in nav_targets:
            report.nav_orphans.append(rel)

    for target in sorted(nav_targets):
        if not (doc_dir / target).exists():
            report.nav_dangling.append(target)

    return report


_LABELS = {
    "broken_links": "Links whose target file does not exist",
    "dead_anchors": "Links pointing at an anchor the target does not expose",
    "implicit_anchors": "Cross-page links relying on a heading-derived anchor (declare {#anchor})",
    "missing_translations": "French pages with no English counterpart",
    "nav_orphans": "Pages absent from the mkdocs nav (unreachable by menu)",
    "nav_dangling": "Nav entries pointing at a file that does not exist",
}


def format_report(report: Report) -> str:
    """Render *report* as the text the CI job prints.

    Args:
        report: The audit result.

    Returns:
        A human-readable multi-line summary.
    """
    if report.total == 0:
        return "docs-check: no defect found."
    lines = [f"docs-check: {report.total} defect(s) found.", ""]
    for key, label in _LABELS.items():
        entries = getattr(report, key)
        if not entries:
            continue
        lines.append(f"{label} ({len(entries)}):")
        lines += [f"  - {entry}" for entry in entries]
        lines.append("")
    return "\n".join(lines).rstrip()


def main(argv: list[str] | None = None) -> int:
    """CLI entry point: audit the docs and exit non-zero on any defect.

    Args:
        argv: Argument list; defaults to ``sys.argv[1:]``.

    Returns:
        ``0`` when the documentation is clean, ``1`` otherwise.
    """
    repo_root = Path(__file__).parent.parent
    parser = argparse.ArgumentParser(description="Check the documentation for rot.")
    parser.add_argument("--doc-dir", type=Path, default=repo_root / "doc")
    parser.add_argument("--mkdocs", type=Path, default=repo_root / "mkdocs.yml")
    parser.add_argument(
        "--allow-implicit-anchors",
        action="store_true",
        help="Do not report cross-page links that rely on a heading-derived anchor.",
    )
    args = parser.parse_args(argv)

    report = check_docs(args.doc_dir, args.mkdocs, require_explicit_anchors=not args.allow_implicit_anchors)
    print(format_report(report))
    return 1 if report.total else 0


if __name__ == "__main__":
    sys.exit(main())
