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

A **second, narrower pass** (:func:`check_repo_links`) covers the markdown the first one never saw:
``.backlog/``, ``docs/``, the root pages. It checks one thing — that a relative link's target
exists — because that is all that transfers. It was added after PR #655 folded 258 backlog files into
226 archives and broke 68 relative links doing it, with nothing to notice: the gate stopped at
``doc/``. Its verification had been line-level, and line fidelity is not link validity.

Run with ``poetry run docs-check`` (or ``veaf-build docs-check``); the CI ``docs-check`` job runs
the same entry point and both passes.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass, field, fields
from pathlib import Path

#: Pages that legitimately sit outside the nav and have no translation: repo notes about the
#: documentation itself, not documentation pages.
EXEMPT: frozenset[str] = frozenset({"assets/img/README.md"})

#: Directories the repo-wide link pass never walks. ``doc`` is excluded because
#: :func:`check_docs` already covers it with the stricter published-site rules. The rest only matter on
#: the fallback path below, when the file list cannot come from git.
_REPO_SKIP_DIRS: frozenset[str] = frozenset(
    {".git", ".claude", "doc", "node_modules", ".mypy_cache", ".venv", "__pycache__", ".pytest_cache"}
)

#: Files whose relative links describe a **past** state of the repo and are expected not to resolve.
#: Each entry needs its reason: an exemption nobody can justify is indistinguishable from neglect.
#: Decided by David on 2026-08-08 (TOOLING-REPO-LINK-GATE ticket 04): **exempt, do not repair**.
#: Repairing the links of a document that records a past state would rewrite it into a state that
#: never existed, which is worse than a link that does not resolve.
_REPO_LINK_EXEMPT: frozenset[str] = frozenset(
    {
        # The plan *for* the backlog restructure, and its design spec: both describe the flat
        # `backlog.md` era they replaced, so their links resolved when written. Repointing them would
        # rewrite a record of a real past state into one that never existed.
        "docs/superpowers/plans/2026-06-24-backlog-restructure.md",
        "docs/superpowers/specs/2026-06-24-backlog-restructure-design.md",
        # A dated review whose links were written relative to `doc/`. **Still live work**: SECREV-2's
        # PRD sources its tickets from this file and 04-07 are open, so it is not deletable yet. The
        # delete-or-archive question reopens when SECREV-2 closes, not before.
        "CODE_DOC_REVIEW_2026-07-01.md",
    }
)

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
    repo_broken_links: list[str] = field(default_factory=list)
    undocumented_names: list[str] = field(default_factory=list)

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


@dataclass(frozen=True)
class CoverageRule:
    """A set of names the code defines, and the pages that must mention every one of them.

    Attributes:
        label: What the names are, for the report.
        source_glob: Where they are declared, relative to the repo root.
        pattern: Regex whose first group captures a name.
        pages: Pages that must mention every name, relative to the repo root.
        mention: How a name appears in prose, as a format string.
    """

    label: str
    source_glob: str
    pattern: str
    pages: tuple[str, ...]
    mention: str = "{name}"


#: What must be documented, and where. Both rules were added after measuring live drift rather than
#: imagining it: the MCP page was missing ``set_airbase_coalition``, shipped by
#: FEAT-MCP-AIRBASES-WAREHOUSES and never written up.
#:
#: Names are **read out of the source with a regex, not imported**. That is deliberate: the CI job
#: runs this module with plain ``python`` and no Poetry install, which is what keeps it a few seconds
#: long, and importing the MCP catalogue would drag in pydantic. A pytest test asserts the regex and
#: the real ``list_catalog()`` agree, so the cheap gate is itself gated by the expensive one.
#:
#: `AI_ASSISTANT_CATALOG.md` is deliberately **not** covered: it is written for mission makers in
#: natural language and says outright that you do not need to know the technical names, so only 3 of
#: the 29 appear in it. Requiring them there would be requiring the page to stop doing its job.
COVERAGE_RULES: tuple[CoverageRule, ...] = (
    CoverageRule(
        label="MCP action",
        source_glob="src/python/veaf-tools/veaf_mission_mcp/*.py",
        pattern=r'name="([a-z][a-z0-9_]+)"',
        pages=("doc/developer/mission-editing-mcp.md", "doc/developer/mission-editing-mcp.en.md"),
    ),
    CoverageRule(
        label="marker alias",
        source_glob="src/scripts/veaf/veafShortcuts.lua",
        pattern=r'setName\("([^"]+)"\)',
        pages=("doc/ALIASES.md", "doc/ALIASES.en.md"),
        mention="`{name}`",
    ),
    # REFACTOR-CLI-COMMAND-TREE ticket 04: every command the tree places must be mentioned by the
    # page that documents the CLI. This is what stops the next command from shipping undocumented —
    # the tree already fails a test when a command is not *placed*, and this covers the other half.
    # Matches every lowercase quoted token in the tree module: the 25 command names **and** the 5
    # group names, which are equally user-facing (`veaf-tools mission --help`). `ROOT_GROUP_ID` is
    # excluded because it names a wizard heading, not something anyone types. Note `re.findall` is
    # applied without MULTILINE here, so a pattern anchored on `$` would silently match nothing —
    # which is how the first version of this rule passed while extracting zero names.
    CoverageRule(
        label="CLI command",
        source_glob="src/python/veaf-tools/veaf_tools/command_tree.py",
        pattern=r'(?<!ROOT_GROUP_ID = )"([a-z][a-z0-9]*(?:-[a-z0-9]+)*)"',
        pages=("doc/mission-maker/GUIDE.md", "doc/mission-maker/GUIDE.en.md"),
        mention="`{name}`",
    ),
)


def _names_of(repo_root: Path, rule: CoverageRule) -> list[str]:
    """Extract the names *rule* says must be documented.

    Args:
        repo_root: Repository root.
        rule: The rule to apply.

    Returns:
        Sorted names.
    """
    names: set[str] = set()
    compiled = re.compile(rule.pattern)
    for source in sorted(repo_root.glob(rule.source_glob)):
        names |= set(compiled.findall(source.read_text(encoding="utf-8", errors="replace")))
    return sorted(names)


def check_doc_coverage(repo_root: Path) -> list[str]:
    """Check that every name the code defines is mentioned by the pages that document it.

    A **drift check, not a generator**. Both pages this covers carry curated prose — thematic
    sections, hand-written descriptions, an editorial frequency column — and generating them would
    destroy exactly what makes them worth reading. What actually needs guarding is narrower: that a
    capability shipped in code did not silently miss its documentation.

    Args:
        repo_root: Repository root.

    Returns:
        Sorted findings, of two shapes: ``"<label> '<name>' is not documented in <page>"`` for a name
        the page never mentions, and ``"<label> page missing: <page>"`` when the page itself is gone —
        which is the more urgent of the two and must not be reported as if it were a single gap.
    """
    findings: list[str] = []
    for rule in COVERAGE_RULES:
        names = _names_of(repo_root, rule)
        for page in rule.pages:
            path = repo_root / page
            if not path.is_file():
                findings.append(f"{rule.label} page missing: {page}")
                continue
            text = path.read_text(encoding="utf-8", errors="replace")
            findings += [
                f"{rule.label} '{name}' is not documented in {page}"
                for name in names
                if rule.mention.format(name=name) not in text
            ]
    return sorted(findings)


#: A link target only counts as a path when it is plain ASCII path characters. This is what keeps an
#: ellipsis out of the results: ``CHANGELOG.md`` contains ``…png`` in prose, which the link regex
#: happily captures. Erring this way can only *miss* a broken link with an accented name — a false
#: negative — and a gate that reports prose as a defect is a gate people switch off.
_PATHLIKE = re.compile(r"^[A-Za-z0-9._/~%+-]+$")


def check_repo_links(repo_root: Path) -> list[str]:
    """Check that every relative link outside ``doc/`` points at something that exists.

    A deliberately narrow pass, and narrow for reasons rather than convenience. It does **not**
    validate anchors: outside ``doc/`` the renderer is GitHub, whose slugifier differs from the
    ``pymdownx`` one :func:`check_docs` mirrors, so checking them would produce confident false
    positives. It does not check translations or nav either — a backlog ticket has no English twin and
    belongs in no menu.

    Unlike :func:`check_docs` it **does** check non-``.md`` targets: a link to a ``.spec`` or a
    ``.conf`` rots exactly as readily, and one did.

    Args:
        repo_root: Repository root.

    Returns:
        One ``"file -> target"`` string per broken link, sorted.
    """
    findings: list[str] = []
    for page in _markdown_to_check(repo_root):
        if _REPO_SKIP_DIRS & set(page.relative_to(repo_root).parts):
            continue
        rel = page.relative_to(repo_root).as_posix()
        if rel in _REPO_LINK_EXEMPT:
            continue
        for target in _LINK.findall(page.read_text(encoding="utf-8", errors="replace")):
            if target.startswith(("http://", "https://", "mailto:", "#", "<", "/")):
                continue
            path_part = target.partition("#")[0]
            if not path_part or not _PATHLIKE.match(path_part):
                continue
            if not (page.parent / path_part).resolve().exists():
                findings.append(f"{rel} -> {target}")
    return findings


def _markdown_to_check(repo_root: Path) -> list[Path]:
    """The markdown files this pass is responsible for: the ones **git tracks**.

    Args:
        repo_root: Repository root.

    Returns:
        Tracked ``.md`` files, sorted; or every ``.md`` in the tree when git cannot answer.

    Walking the working tree instead was the defect: it reads whatever happens to sit on this
    workstation. Two local artefacts produced **392 phantom defects** here against **0 in CI**, for the
    same underlying reason — git ignores both, so a fresh clone has neither:

    - ``.claude/worktrees/<name>/`` — agent worktrees, each a *full checkout of this repository*, so
      every backlog and archive page got re-read at a different depth where none of its relative links
      resolve. 367 of the 392.
    - ``test/veaf-tools-updater/`` — a scratch directory for the updater's tests, ignored at
      ``.gitignore:63``. The remaining 25.

    Enumerating those two by name was the first fix and it was too narrow: the next local artefact would
    have needed a third entry, and the list would drift out of step with ``.gitignore``. Asking git is
    the general answer — the gate exists to guard **committed** documentation, and a link is only broken
    for other people if both ends are committed.

    The fallback matters: this module is also importable outside a checkout (a release tarball, a
    vendored copy), where walking the tree is the only option and the old behaviour is correct.
    """
    try:
        result = subprocess.run(  # noqa: S603 - fixed argv, no shell, no user input
            ["git", "-C", str(repo_root), "ls-files", "-z", "--", "*.md"],  # noqa: S607 - git from PATH
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError:
        result = None  # git is not installed
    if result is not None and result.returncode == 0:
        names = [n for n in result.stdout.split("\0") if n]
        # An empty repository is indistinguishable from "git answered nothing useful", so fall through
        # rather than silently reporting a clean gate over zero files.
        if names:
            return sorted(repo_root / name for name in names)
    return sorted(repo_root.rglob("*.md"))


_LABELS = {
    "broken_links": "Links whose target file does not exist",
    "dead_anchors": "Links pointing at an anchor the target does not expose",
    "implicit_anchors": "Cross-page links relying on a heading-derived anchor (declare {#anchor})",
    "missing_translations": "French pages with no English counterpart",
    "nav_orphans": "Pages absent from the mkdocs nav (unreachable by menu)",
    "nav_dangling": "Nav entries pointing at a file that does not exist",
    "repo_broken_links": "Relative links outside doc/ whose target does not exist",
    "undocumented_names": "Capabilities the code defines that their reference page never mentions",
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
    parser.add_argument("--repo-root", type=Path, default=repo_root)
    parser.add_argument(
        "--allow-implicit-anchors",
        action="store_true",
        help="Do not report cross-page links that rely on a heading-derived anchor.",
    )
    parser.add_argument(
        "--skip-repo-links",
        action="store_true",
        help="Skip the relative-link pass over .backlog/, docs/ and the root pages.",
    )
    parser.add_argument(
        "--skip-coverage",
        action="store_true",
        help="Skip the check that every capability the code defines is named by its reference page.",
    )
    args = parser.parse_args(argv)

    report = check_docs(args.doc_dir, args.mkdocs, require_explicit_anchors=not args.allow_implicit_anchors)
    # Each pass gets its own opt-out. They were briefly sharing one, which meant asking to skip link
    # validation silently dropped the coverage gate too — a gate nobody chose to lose.
    if not args.skip_repo_links:
        report.repo_broken_links = check_repo_links(args.repo_root)
    if not args.skip_coverage:
        report.undocumented_names = check_doc_coverage(args.repo_root)
    print(format_report(report))
    return 1 if report.total else 0


if __name__ == "__main__":
    sys.exit(main())
