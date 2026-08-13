"""Unit tests for the documentation gate (veaf_build.docs_check).

Each test builds a miniature docs tree, because the point of the gate is what it does with
*shapes* — a missing translation, an anchor left behind by a renumbering — not with our own pages.

Two behaviours are pinned deliberately, since getting them wrong is what made the DOC-AUDIT-PASS
audit produce 245 false positives before being verified against the published site: relative links
are language-agnostic (the i18n plugin rewrites them) and anchors keep their accents.
"""

import subprocess
from pathlib import Path

import pytest

from veaf_build.docs_check import (
    COVERAGE_RULES,
    EXEMPT,
    OPTION_RULES,
    CoverageRule,
    OptionRule,
    Report,
    check_doc_coverage,
    check_docs,
    check_repo_links,
    format_report,
    slugify,
)


@pytest.fixture
def docs(tmp_path: Path) -> Path:
    """An empty docs tree with a minimal mkdocs.yml alongside it."""
    doc = tmp_path / "doc"
    doc.mkdir()
    (tmp_path / "mkdocs.yml").write_text("site_name: t\nnav:\n", encoding="utf-8")
    return doc


def _nav(root: Path, *paths: str) -> None:
    lines = ["site_name: t", "nav:"] + [f"  - Page: {p}" for p in paths]
    (root / "mkdocs.yml").write_text("\n".join(lines) + "\n", encoding="utf-8")


def _run(docs: Path, explicit: bool = True):
    return check_docs(docs, docs.parent / "mkdocs.yml", require_explicit_anchors=explicit)


class TestSlugify:
    def test_keeps_accents(self):
        # pymdownx.slugify(case=lower) does not transliterate — verified on the published HTML.
        assert slugify("Étape 1 — Préréglages radio (`presets.yaml`)") == "étape-1--préréglages-radio-presetsyaml"

    def test_strips_code_and_emphasis_markers(self):
        assert slugify("`pipeline:`") == "pipeline"

    def test_ignores_a_trailing_explicit_anchor(self):
        assert slugify("Coverage {#coverage}") == "coverage"

    def test_keeps_underscores(self):
        # FIX-DOCAUDIT-CODE 04-C. The underscore sat in the same character class as the emphasis
        # markers, so `build_variants:` was registered as "buildvariants" while the published site
        # uses "build_variants" — `_` is a word character for pymdownx. Roughly a dozen headings in
        # MISSION_YAML_REFERENCE alone, each making a *correct* link invisible to the gate.
        # Underscore emphasis in a heading would break this; measured, no page uses any.
        assert slugify("`build_variants:`") == "build_variants"
        assert slugify("`global_log_level`") == "global_log_level"


class TestBrokenLinks:
    def test_reports_a_missing_target(self, docs: Path):
        (docs / "a.md").write_text("# A\n\n[gone](missing.md)\n", encoding="utf-8")
        (docs / "a.en.md").write_text("# A\n", encoding="utf-8")
        _nav(docs.parent, "a.md")
        assert _run(docs).broken_links == ["a.md -> missing.md"]

    def test_accepts_an_existing_target(self, docs: Path):
        for name in ("a.md", "a.en.md", "b.md", "b.en.md"):
            (docs / name).write_text("# T\n\n[ok](b.md)\n", encoding="utf-8")
        _nav(docs.parent, "a.md", "b.md")
        assert _run(docs).broken_links == []

    def test_ignores_external_and_same_page_links(self, docs: Path):
        (docs / "a.md").write_text("# A\n\n[x](https://e.org) [y](#a) [z](mailto:a@b.c)\n", encoding="utf-8")
        (docs / "a.en.md").write_text("# A\n", encoding="utf-8")
        _nav(docs.parent, "a.md")
        assert _run(docs).broken_links == []


class TestAnchors:
    def test_reports_an_anchor_the_target_does_not_expose(self, docs: Path):
        (docs / "b.md").write_text("# B\n\n## Étape 6 {#step-6}\n", encoding="utf-8")
        (docs / "b.en.md").write_text("# B\n\n## Step 6 {#step-6}\n", encoding="utf-8")
        (docs / "a.md").write_text("# A\n\n[old](b.md#step-4)\n", encoding="utf-8")
        (docs / "a.en.md").write_text("# A\n", encoding="utf-8")
        _nav(docs.parent, "a.md", "b.md")
        report = _run(docs)
        assert len(report.dead_anchors) == 1
        assert "step-4" in report.dead_anchors[0]

    def test_accepts_an_explicit_anchor(self, docs: Path):
        (docs / "b.md").write_text("# B\n\n## Couverture {#coverage}\n", encoding="utf-8")
        (docs / "b.en.md").write_text("# B\n\n## Coverage {#coverage}\n", encoding="utf-8")
        (docs / "a.md").write_text("# A\n\n[cov](b.md#coverage)\n", encoding="utf-8")
        (docs / "a.en.md").write_text("# A\n\n[cov](b.md#coverage)\n", encoding="utf-8")
        _nav(docs.parent, "a.md", "b.md")
        report = _run(docs)
        assert report.dead_anchors == []
        assert report.implicit_anchors == []

    def test_an_en_page_anchor_is_checked_against_the_en_twin(self, docs: Path):
        # The i18n plugin rewrites the *link*, not the anchor: an EN reader lands on b.en.md,
        # whose French-derived anchor does not exist.
        (docs / "b.md").write_text("# B\n\n## Couverture\n", encoding="utf-8")
        (docs / "b.en.md").write_text("# B\n\n## Coverage\n", encoding="utf-8")
        (docs / "a.md").write_text("# A\n", encoding="utf-8")
        (docs / "a.en.md").write_text("# A\n\n[cov](b.md#couverture)\n", encoding="utf-8")
        _nav(docs.parent, "a.md", "b.md")
        report = _run(docs)
        assert len(report.dead_anchors) == 1
        assert "b.en.md" in report.dead_anchors[0]

    def test_reports_a_heading_derived_anchor_when_required(self, docs: Path):
        (docs / "b.md").write_text("# B\n\n## Coverage\n", encoding="utf-8")
        (docs / "b.en.md").write_text("# B\n\n## Coverage\n", encoding="utf-8")
        (docs / "a.md").write_text("# A\n\n[cov](b.md#coverage)\n", encoding="utf-8")
        (docs / "a.en.md").write_text("# A\n", encoding="utf-8")
        _nav(docs.parent, "a.md", "b.md")
        assert len(_run(docs).implicit_anchors) == 1
        assert _run(docs, explicit=False).implicit_anchors == []

    def test_accented_anchor_is_valid(self, docs: Path):
        (docs / "b.md").write_text("# B\n\n## Étape 1 — Préréglages\n", encoding="utf-8")
        (docs / "b.en.md").write_text("# B\n\n## Step 1\n", encoding="utf-8")
        (docs / "a.md").write_text("# A\n\n[s](b.md#étape-1--préréglages)\n", encoding="utf-8")
        (docs / "a.en.md").write_text("# A\n", encoding="utf-8")
        _nav(docs.parent, "a.md", "b.md")
        assert _run(docs).dead_anchors == []

    def test_an_explicit_anchor_retires_the_heading_derived_one(self, docs: Path):
        # FIX-DOCAUDIT-CODE 04-A. mkdocs' attr_list **replaces** the generated id with the explicit
        # one, so a link to the heading-derived slug 404s on the published site while the gate said
        # it was fine. Five dead anchors survived exactly this way; `TESTING.md`'s `#couverture`
        # against `## Couverture {#coverage}` is the cleanest specimen.
        (docs / "b.md").write_text("# B\n\n## Couverture {#coverage}\n", encoding="utf-8")
        (docs / "b.en.md").write_text("# B\n\n## Coverage {#coverage}\n", encoding="utf-8")
        (docs / "a.md").write_text("# A\n\n[old](b.md#couverture)\n", encoding="utf-8")
        (docs / "a.en.md").write_text("# A\n", encoding="utf-8")
        _nav(docs.parent, "a.md", "b.md")
        report = _run(docs)
        assert len(report.dead_anchors) == 1
        assert "couverture" in report.dead_anchors[0]


class TestSamePageAnchors:
    """FIX-DOCAUDIT-CODE 04-D — the gate validated cross-page anchors only.

    A table-of-contents entry pointing at a heading that carries an explicit anchor passed CI
    untouched: seven genuinely dead ones were found by hand during the audit
    (`developer/GUIDE.md` ×4, `veafRadio.md`, `pilot/GUIDE.md`, `TESTING.md`).
    """

    def test_a_dead_same_page_anchor_is_reported(self, docs: Path):
        (docs / "a.md").write_text("# A\n\n[toc](#gone)\n\n## Here\n", encoding="utf-8")
        (docs / "a.en.md").write_text("# A\n", encoding="utf-8")
        _nav(docs.parent, "a.md")
        report = _run(docs)
        assert len(report.dead_anchors) == 1
        assert "#gone" in report.dead_anchors[0]

    def test_a_live_same_page_anchor_passes(self, docs: Path):
        (docs / "a.md").write_text("# A\n\n[toc](#here)\n\n## Here\n", encoding="utf-8")
        (docs / "a.en.md").write_text("# A\n", encoding="utf-8")
        _nav(docs.parent, "a.md")
        assert _run(docs).dead_anchors == []

    def test_the_explicit_anchor_rule_applies_on_the_same_page_too(self, docs: Path):
        # Same as rule A, one page in: the derived slug is not an id the site serves.
        (docs / "a.md").write_text("# A\n\n[toc](#couverture)\n\n## Couverture {#coverage}\n", encoding="utf-8")
        (docs / "a.en.md").write_text("# A\n", encoding="utf-8")
        _nav(docs.parent, "a.md")
        assert len(_run(docs).dead_anchors) == 1

    def test_an_underscore_heading_is_reachable_on_the_same_page(self, docs: Path):
        # Rule C is what makes rule D usable: with the underscore stripped, this correct link
        # would be reported, and the real findings would drown in false positives — which is
        # exactly what happened to a hand-rolled version of this sweep during the audit.
        (docs / "a.md").write_text("# A\n\n[v](#build_variants)\n\n### `build_variants:`\n", encoding="utf-8")
        (docs / "a.en.md").write_text("# A\n", encoding="utf-8")
        _nav(docs.parent, "a.md")
        assert _run(docs).dead_anchors == []

    def test_a_same_page_anchor_is_never_reported_as_implicit(self, docs: Path):
        # The explicit-anchor requirement exists because a *cross-page* link breaks on a reword
        # and differs between languages. Neither applies within one page, and demanding an
        # explicit anchor for every heading a table of contents lists would be noise.
        (docs / "a.md").write_text("# A\n\n[toc](#here)\n\n## Here\n", encoding="utf-8")
        (docs / "a.en.md").write_text("# A\n", encoding="utf-8")
        _nav(docs.parent, "a.md")
        assert _run(docs).implicit_anchors == []


class TestTranslationsAndNav:
    def test_reports_a_page_without_an_english_twin(self, docs: Path):
        (docs / "a.md").write_text("# A\n", encoding="utf-8")
        _nav(docs.parent, "a.md")
        assert _run(docs).missing_translations == ["a.md"]

    def test_reports_a_page_outside_the_nav(self, docs: Path):
        (docs / "a.md").write_text("# A\n", encoding="utf-8")
        (docs / "a.en.md").write_text("# A\n", encoding="utf-8")
        _nav(docs.parent)
        assert _run(docs).nav_orphans == ["a.md"]

    def test_reports_a_nav_entry_with_no_file(self, docs: Path):
        _nav(docs.parent, "ghost.md")
        assert _run(docs).nav_dangling == ["ghost.md"]

    def test_exempt_pages_need_neither_twin_nor_nav_entry(self, docs: Path):
        exempt = next(iter(EXEMPT))
        page = docs / exempt
        page.parent.mkdir(parents=True, exist_ok=True)
        page.write_text("# repo note\n", encoding="utf-8")
        _nav(docs.parent)
        report = _run(docs)
        assert report.missing_translations == []
        assert report.nav_orphans == []


class TestReport:
    def test_clean_tree_reports_nothing(self, docs: Path):
        (docs / "a.md").write_text("# A\n", encoding="utf-8")
        (docs / "a.en.md").write_text("# A\n", encoding="utf-8")
        _nav(docs.parent, "a.md")
        report = _run(docs)
        assert report.total == 0
        assert format_report(report) == "docs-check: no defect found."

    def test_format_lists_every_kind_found(self, docs: Path):
        (docs / "a.md").write_text("# A\n\n[gone](missing.md)\n", encoding="utf-8")
        _nav(docs.parent)
        text = format_report(_run(docs))
        assert "target file does not exist" in text
        assert "no English counterpart" in text
        assert "absent from the mkdocs nav" in text


class TestRepoLinkPass:
    """The pass over markdown outside ``doc/`` — ``.backlog/``, ``docs/``, the root pages.

    It exists because PR #655 folded 258 backlog files into 226 archives and broke 68 relative links
    doing it, with nothing to notice: the gate stopped at ``doc/``. The first test is that exact
    regression, so it cannot be reintroduced silently.
    """

    def test_the_655_depth_shift_is_reported(self, tmp_path: Path):
        # A ticket at .backlog/L/tickets/01.md is three levels below the root, so it correctly says
        # ../../../target.md. Folded into .backlog/archive/L.md — two levels below — that path
        # climbs one level too far and resolves above the repo.
        (tmp_path / "target.md").write_text("# T\n", encoding="utf-8")
        archive = tmp_path / ".backlog" / "archive"
        archive.mkdir(parents=True)
        (archive / "L.md").write_text("# Lot L\n\n[t](../../../target.md)\n", encoding="utf-8")
        assert check_repo_links(tmp_path) == [".backlog/archive/L.md -> ../../../target.md"]

    def test_the_same_link_at_the_original_depth_passes(self, tmp_path: Path):
        (tmp_path / "target.md").write_text("# T\n", encoding="utf-8")
        tickets = tmp_path / ".backlog" / "L" / "tickets"
        tickets.mkdir(parents=True)
        (tickets / "01.md").write_text("[t](../../../target.md)\n", encoding="utf-8")
        assert check_repo_links(tmp_path) == []

    def test_the_repaired_depth_passes(self, tmp_path: Path):
        # What ticket 02 rewrote them to: one fewer level, matching the archive's own depth.
        (tmp_path / "target.md").write_text("# T\n", encoding="utf-8")
        archive = tmp_path / ".backlog" / "archive"
        archive.mkdir(parents=True)
        (archive / "L.md").write_text("[t](../../target.md)\n", encoding="utf-8")
        assert check_repo_links(tmp_path) == []

    def test_non_markdown_targets_are_checked_too(self, tmp_path: Path):
        # check_docs skips these, which is right for a published site. Here a link to a .spec or a
        # .conf rots just as readily — one did, at the wrong depth.
        (tmp_path / "a.md").write_text("[s](tool.spec)\n", encoding="utf-8")
        assert check_repo_links(tmp_path) == ["a.md -> tool.spec"]
        (tmp_path / "tool.spec").write_text("x\n", encoding="utf-8")
        assert check_repo_links(tmp_path) == []

    def test_an_ellipsis_is_not_a_link(self, tmp_path: Path):
        # CHANGELOG.md carries an ellipsis followed by "png" in prose, which the link regex captures
        # happily. A gate that reports prose as a defect is a gate people switch off.
        (tmp_path / "CHANGELOG.md").write_text("- a shot [x](…png) somewhere\n", encoding="utf-8")
        assert check_repo_links(tmp_path) == []

    def test_external_and_anchor_targets_are_ignored(self, tmp_path: Path):
        (tmp_path / "a.md").write_text(
            "[h](https://x.test) [m](mailto:a@b.test) [s](#section) [abs](/x/y.md)\n",
            encoding="utf-8",
        )
        assert check_repo_links(tmp_path) == []

    def test_doc_dir_is_left_to_check_docs(self, tmp_path: Path):
        # Otherwise every doc/ link would be reported twice, and by the looser of the two rules.
        doc = tmp_path / "doc"
        doc.mkdir()
        (doc / "a.md").write_text("[gone](missing.md)\n", encoding="utf-8")
        assert check_repo_links(tmp_path) == []

    def test_the_exemption_is_load_bearing(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
        # An exemption that is not doing anything is worse than none: it reads as coverage.
        import veaf_build.docs_check as mod

        (tmp_path / "hist.md").write_text("[gone](nowhere.md)\n", encoding="utf-8")
        monkeypatch.setattr(mod, "_REPO_LINK_EXEMPT", frozenset({"hist.md"}))
        assert mod.check_repo_links(tmp_path) == []
        monkeypatch.setattr(mod, "_REPO_LINK_EXEMPT", frozenset())
        assert mod.check_repo_links(tmp_path) == ["hist.md -> nowhere.md"]

    def test_an_agent_worktree_is_not_a_second_copy_of_the_docs(self, tmp_path: Path):
        # Belt for the fallback path (no git): .claude/worktrees/<name>/ is a full checkout of this
        # repository, so walking it re-reads every backlog page at a different depth where none of its
        # relative links resolve — 367 phantom defects on a workstation that had used worktrees, 0 in CI.
        (tmp_path / "target.md").write_text("# T\n", encoding="utf-8")
        (tmp_path / "ok.md").write_text("[t](target.md)\n", encoding="utf-8")
        worktree = tmp_path / ".claude" / "worktrees" / "agent-abc" / ".backlog" / "archive"
        worktree.mkdir(parents=True)
        (worktree / "L.md").write_text("[t](../../../target.md)\n", encoding="utf-8")
        assert check_repo_links(tmp_path) == []

    def test_findings_reach_the_report_text(self):
        report = Report(repo_broken_links=["x.md -> y.md"])
        assert report.total == 1
        assert "outside doc/" in format_report(report)


class TestOnlyTrackedFilesAreChecked:
    """The pass validates what git tracks, not what happens to sit on this workstation.

    Walking the tree produced **392 phantom defects** locally against **0 in CI**, from two paths git
    ignores: agent worktrees under ``.claude/worktrees/`` (367) and the updater's scratch directory
    ``test/veaf-tools-updater/`` (25, ignored at ``.gitignore:63``). Naming those two in a skip list was
    the first attempt and it was too narrow — the next local artefact needs a third entry, and the list
    drifts out of step with ``.gitignore``. A link is only broken *for other people* if both ends are
    committed, so git is the right authority.
    """

    def _repo(self, tmp_path: Path) -> bool:
        """Make tmp_path a git repo. Returns False when git is unavailable."""
        try:
            for args in (["init", "-q"], ["config", "user.email", "t@t.test"], ["config", "user.name", "t"]):
                subprocess.run(["git", "-C", str(tmp_path), *args], check=True, capture_output=True)
        except (OSError, subprocess.CalledProcessError):
            return False
        return True

    def _track(self, tmp_path: Path, *paths: str) -> None:
        subprocess.run(["git", "-C", str(tmp_path), "add", "--", *paths], check=True, capture_output=True)

    def test_an_untracked_page_with_a_broken_link_is_not_a_defect(self, tmp_path: Path):
        if not self._repo(tmp_path):
            pytest.skip("git unavailable")
        (tmp_path / "tracked.md").write_text("# T\n", encoding="utf-8")
        self._track(tmp_path, "tracked.md")
        # Never added: local debris, exactly like a worktree or a scratch directory.
        (tmp_path / "local.md").write_text("[gone](nowhere.md)\n", encoding="utf-8")
        assert check_repo_links(tmp_path) == []

    def test_a_tracked_page_with_a_broken_link_is_still_a_defect(self, tmp_path: Path):
        if not self._repo(tmp_path):
            pytest.skip("git unavailable")
        (tmp_path / "tracked.md").write_text("[gone](nowhere.md)\n", encoding="utf-8")
        self._track(tmp_path, "tracked.md")
        assert check_repo_links(tmp_path) == ["tracked.md -> nowhere.md"]

    def test_a_link_to_an_untracked_target_is_a_defect(self, tmp_path: Path):
        # The target exists on disk but not in the repository, so it 404s for everyone else. This is the
        # case a naive "does the file exist" walk gets wrong in the *permissive* direction.
        if not self._repo(tmp_path):
            pytest.skip("git unavailable")
        (tmp_path / "page.md").write_text("[local](scratch.md)\n", encoding="utf-8")
        (tmp_path / "scratch.md").write_text("# untracked\n", encoding="utf-8")
        self._track(tmp_path, "page.md")
        # Documented limitation: resolution is still filesystem-based, so this passes today. Pinned so
        # the behaviour is a recorded choice rather than an accident, and so tightening it is a visible
        # change rather than a surprise.
        assert check_repo_links(tmp_path) == []

    def test_no_git_falls_back_to_walking_the_tree(self, tmp_path: Path):
        # Importable outside a checkout — a release tarball, a vendored copy — where walking is the only
        # option and the old behaviour is right.
        (tmp_path / "page.md").write_text("[gone](nowhere.md)\n", encoding="utf-8")
        assert check_repo_links(tmp_path) == ["page.md -> nowhere.md"]


class TestDocCoverage:
    """The drift check: a capability the code defines must be named by its reference page.

    A **check, not a generator**. Both covered pages carry curated prose — thematic sections,
    hand-written descriptions — and generating them would destroy what makes them worth reading. It
    was added after measuring live drift: ``set_airbase_coalition`` shipped with
    FEAT-MCP-AIRBASES-WAREHOUSES and was never written up.
    """

    @pytest.fixture(autouse=True)
    def _no_option_rules(self, monkeypatch: pytest.MonkeyPatch) -> None:
        # check_doc_coverage runs the name rules and the option rules together, so a test isolating
        # one has to silence the other or the real OPTION_RULES fire against the fixture tree.
        monkeypatch.setattr("veaf_build.docs_check.OPTION_RULES", ())

    def _rule(self, tmp_path: Path) -> CoverageRule:
        (tmp_path / "src").mkdir()
        (tmp_path / "doc").mkdir()
        return CoverageRule(
            label="thing",
            source_glob="src/*.py",
            pattern=r'name="([a-z_]+)"',
            pages=("doc/ref.md",),
        )

    def test_a_name_the_page_never_mentions_is_reported(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
        rule = self._rule(tmp_path)
        (tmp_path / "src" / "a.py").write_text('name="documented"\nname="forgotten"\n', encoding="utf-8")
        (tmp_path / "doc" / "ref.md").write_text("# Ref\n\nThe documented thing.\n", encoding="utf-8")
        monkeypatch.setattr("veaf_build.docs_check.COVERAGE_RULES", (rule,))
        assert check_doc_coverage(tmp_path) == ["thing 'forgotten' is not documented in doc/ref.md"]

    def test_a_fully_documented_source_is_silent(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
        rule = self._rule(tmp_path)
        (tmp_path / "src" / "a.py").write_text('name="alpha"\n', encoding="utf-8")
        (tmp_path / "doc" / "ref.md").write_text("alpha is here\n", encoding="utf-8")
        monkeypatch.setattr("veaf_build.docs_check.COVERAGE_RULES", (rule,))
        assert check_doc_coverage(tmp_path) == []

    def test_the_mention_format_is_honoured(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
        # Aliases are written `-sa6` in backticks; a bare mention in prose must not count, or a page
        # that merely says "sa6" somewhere would satisfy the gate.
        rule = CoverageRule(
            label="alias",
            source_glob="src/*.lua",
            pattern=r'setName\("([^"]+)"\)',
            pages=("doc/ref.md",),
            mention="`{name}`",
        )
        (tmp_path / "src").mkdir()
        (tmp_path / "doc").mkdir()
        (tmp_path / "src" / "a.lua").write_text(':setName("-sa6")\n', encoding="utf-8")
        (tmp_path / "doc" / "ref.md").write_text("we mention -sa6 in prose only\n", encoding="utf-8")
        monkeypatch.setattr("veaf_build.docs_check.COVERAGE_RULES", (rule,))
        assert check_doc_coverage(tmp_path) == ["alias '-sa6' is not documented in doc/ref.md"]
        (tmp_path / "doc" / "ref.md").write_text("| `-sa6` | a SAM |\n", encoding="utf-8")
        assert check_doc_coverage(tmp_path) == []

    def test_every_configured_page_is_checked_not_just_the_first(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
        # The rules all carry an FR and an EN page; checking only one would let a translation rot.
        rule = CoverageRule(
            label="thing",
            source_glob="src/*.py",
            pattern=r'name="([a-z_]+)"',
            pages=("doc/ref.md", "doc/ref.en.md"),
        )
        (tmp_path / "src").mkdir()
        (tmp_path / "doc").mkdir()
        (tmp_path / "src" / "a.py").write_text('name="alpha"\n', encoding="utf-8")
        (tmp_path / "doc" / "ref.md").write_text("alpha\n", encoding="utf-8")
        (tmp_path / "doc" / "ref.en.md").write_text("nothing here\n", encoding="utf-8")
        monkeypatch.setattr("veaf_build.docs_check.COVERAGE_RULES", (rule,))
        assert check_doc_coverage(tmp_path) == ["thing 'alpha' is not documented in doc/ref.en.md"]

    def test_a_missing_page_is_reported_rather_than_silently_passing(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ):
        rule = self._rule(tmp_path)
        (tmp_path / "src" / "a.py").write_text('name="alpha"\n', encoding="utf-8")
        monkeypatch.setattr("veaf_build.docs_check.COVERAGE_RULES", (rule,))
        assert check_doc_coverage(tmp_path) == ["thing page missing: doc/ref.md"]

    def test_the_real_rules_point_at_pages_that_exist(self):
        # A rule whose page was renamed would otherwise report one defect forever and be muted.
        root = Path(__file__).parents[3]
        for rule in COVERAGE_RULES:
            for page in rule.pages:
                assert (root / page).is_file(), f"{rule.label}: {page} does not exist"
            assert list(root.glob(rule.source_glob)), f"{rule.label}: {rule.source_glob} matches nothing"

    def test_findings_reach_the_report_text(self):
        report = Report(undocumented_names=["thing 'x' is not documented in doc/ref.md"])
        assert report.total == 1
        assert "reference page never mentions" in format_report(report)


class TestOptionCoverage:
    """FIX-DOCAUDIT-CODE 04-B — coverage keyed on command *names* only.

    So `capture-map --parking` shipped on 2026-08-12 with zero documentation through a green
    gate: the command name was already on the page, and nothing looked at what it accepts.
    Options are read from the typer signatures by AST rather than by regex, because an option
    with no explicit literal — `verbose: bool = typer.Option(False, help=...)` — still becomes
    `--verbose`, and a regex hunting for `"--…"` would miss every one of those.
    """

    def _module(self, tmp_path: Path, body: str) -> OptionRule:
        (tmp_path / "src").mkdir(exist_ok=True)
        (tmp_path / "doc").mkdir(exist_ok=True)
        (tmp_path / "src" / "cmd.py").write_text(body, encoding="utf-8")
        return OptionRule(label="option", source_glob="src/cmd.py", pages=("doc/ref.md",))

    def test_an_undocumented_option_is_reported(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
        rule = self._module(
            tmp_path,
            'import typer\ndef run(parking: bool = typer.Option(False, "--parking", help="h")) -> None:\n    pass\n',
        )
        (tmp_path / "doc" / "ref.md").write_text("# Ref\n\nRun capture-map.\n", encoding="utf-8")
        monkeypatch.setattr("veaf_build.docs_check.COVERAGE_RULES", ())
        monkeypatch.setattr("veaf_build.docs_check.OPTION_RULES", (rule,))
        assert check_doc_coverage(tmp_path) == ["option '--parking' is not documented in doc/ref.md"]

    def test_a_documented_option_passes(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
        rule = self._module(
            tmp_path,
            'import typer\ndef run(parking: bool = typer.Option(False, "--parking", help="h")) -> None:\n    pass\n',
        )
        # A bare mention counts: the reference documents an option inside a shell block, which is
        # how `--tag` is written today, and demanding inline backticks would report prose that works.
        (tmp_path / "doc" / "ref.md").write_text("```bash\nveaf-tools capture-map --parking\n```\n", encoding="utf-8")
        monkeypatch.setattr("veaf_build.docs_check.COVERAGE_RULES", ())
        monkeypatch.setattr("veaf_build.docs_check.OPTION_RULES", (rule,))
        assert check_doc_coverage(tmp_path) == []

    def test_an_option_with_no_literal_is_derived_from_the_parameter_name(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ):
        # typer turns `no_backup` into `--no-backup` with no literal anywhere in the source.
        rule = self._module(
            tmp_path, "import typer\ndef run(no_backup: bool = typer.Option(False, help='h')) -> None:\n    pass\n"
        )
        (tmp_path / "doc" / "ref.md").write_text("nothing\n", encoding="utf-8")
        monkeypatch.setattr("veaf_build.docs_check.COVERAGE_RULES", ())
        monkeypatch.setattr("veaf_build.docs_check.OPTION_RULES", (rule,))
        assert check_doc_coverage(tmp_path) == ["option '--no-backup' is not documented in doc/ref.md"]

    def test_a_flag_and_its_negation_count_as_one_spelling(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
        # `typer.Option(None, "--dev-mode/--no-dev-mode")` is ONE literal declaring both forms.
        # Taking it whole asked the page to contain that exact string, which no reference writes —
        # found by pointing this rule at the new CLI reference and watching it report two ghosts.
        # The negative twin is a typer convention the page states once in its preamble.
        rule = self._module(
            tmp_path,
            'import typer\ndef run(dev_mode: bool = typer.Option(None, "--dev-mode/--no-dev-mode")) -> None:\n'
            "    pass\n",
        )
        (tmp_path / "doc" / "ref.md").write_text("`--dev-mode` builds from a dev checkout.\n", encoding="utf-8")
        monkeypatch.setattr("veaf_build.docs_check.COVERAGE_RULES", ())
        monkeypatch.setattr("veaf_build.docs_check.OPTION_RULES", (rule,))
        assert check_doc_coverage(tmp_path) == []

    def test_two_genuine_alternatives_are_both_required(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
        # Neither implies the other, so documenting one is not documenting both.
        rule = self._module(
            tmp_path,
            'import typer\ndef run(mode: str = typer.Option("a", "--fast/--thorough")) -> None:\n    pass\n',
        )
        (tmp_path / "doc" / "ref.md").write_text("`--fast` only.\n", encoding="utf-8")
        monkeypatch.setattr("veaf_build.docs_check.COVERAGE_RULES", ())
        monkeypatch.setattr("veaf_build.docs_check.OPTION_RULES", (rule,))
        assert check_doc_coverage(tmp_path) == ["option '--thorough' is not documented in doc/ref.md"]

    def test_an_argument_is_not_an_option(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
        # `typer.Argument` is positional — there is no `--` form to document.
        rule = self._module(
            tmp_path, 'import typer\ndef run(mission: str = typer.Argument(..., help="h")) -> None:\n    pass\n'
        )
        (tmp_path / "doc" / "ref.md").write_text("nothing\n", encoding="utf-8")
        monkeypatch.setattr("veaf_build.docs_check.COVERAGE_RULES", ())
        monkeypatch.setattr("veaf_build.docs_check.OPTION_RULES", (rule,))
        assert check_doc_coverage(tmp_path) == []

    def test_a_syntax_error_is_reported_rather_than_skipped(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
        # A module the AST cannot read must not silently contribute zero options — that would be a
        # gate reporting "all documented" about a file it never looked at.
        rule = self._module(tmp_path, "def run(:\n")
        (tmp_path / "doc" / "ref.md").write_text("nothing\n", encoding="utf-8")
        monkeypatch.setattr("veaf_build.docs_check.COVERAGE_RULES", ())
        monkeypatch.setattr("veaf_build.docs_check.OPTION_RULES", (rule,))
        findings = check_doc_coverage(tmp_path)
        assert len(findings) == 1
        assert "cannot be parsed" in findings[0]

    def test_the_real_rules_point_at_pages_and_sources_that_exist(self):
        root = Path(__file__).parents[3]
        for rule in OPTION_RULES:
            for page in rule.pages:
                assert (root / page).is_file(), f"{rule.label}: {page} does not exist"
            assert list(root.glob(rule.source_glob)), f"{rule.label}: {rule.source_glob} matches nothing"


class TestCoverageRegexMatchesReality:
    """The gate greps the source instead of importing it, so something must prove they agree.

    ``docs_check`` is stdlib-only on purpose — the CI job runs it with plain ``python`` and no Poetry
    install, which is what keeps it seconds long. Importing the MCP catalogue would drag in pydantic.
    That trade is only safe while the regex sees exactly what the catalogue holds, and this is the
    test that says so.
    """

    def test_the_mcp_rule_finds_exactly_what_list_catalog_returns(self):
        from veaf_build.docs_check import _names_of

        root = Path(__file__).parents[3]
        rule = next(r for r in COVERAGE_RULES if r.label == "MCP action")
        regexed = set(_names_of(root, rule))

        import sys

        sys.path.insert(0, str(root / "src" / "python" / "veaf-tools"))
        from veaf_mission_mcp.server import CATALOG

        imported = {spec.name for spec in CATALOG.list_catalog()}
        assert regexed == imported, (
            "the stdlib regex and the real catalogue disagree — the cheap gate has stopped seeing "
            f"what it guards. only regexed: {sorted(regexed - imported)}; "
            f"only imported: {sorted(imported - regexed)}"
        )


class TestTheTwoPassesOptOutIndependently:
    """`--skip-repo-links` must not silently take the coverage gate with it.

    They shared one flag briefly, so asking to skip link validation dropped a gate nobody chose to
    lose. Caught in review (Sourcery, PR #660).
    """

    def _repo(self, tmp_path: Path) -> Path:
        (tmp_path / "doc").mkdir()
        (tmp_path / "mkdocs.yml").write_text("site_name: t\nnav:\n", encoding="utf-8")
        (tmp_path / "broken.md").write_text("[gone](nowhere.md)\n", encoding="utf-8")
        (tmp_path / "src").mkdir()
        (tmp_path / "src" / "a.py").write_text('name="undocumented"\n', encoding="utf-8")
        (tmp_path / "doc" / "ref.md").write_text("nothing\n", encoding="utf-8")
        return tmp_path

    def _run(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch, *flags: str) -> str:
        import contextlib
        import io

        from veaf_build.docs_check import main

        monkeypatch.setattr(
            "veaf_build.docs_check.COVERAGE_RULES",
            (CoverageRule(label="thing", source_glob="src/*.py", pattern=r'name="([a-z_]+)"', pages=("doc/ref.md",)),),
        )
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            main(
                [
                    "--doc-dir",
                    str(tmp_path / "doc"),
                    "--mkdocs",
                    str(tmp_path / "mkdocs.yml"),
                    "--repo-root",
                    str(tmp_path),
                    *flags,
                ]
            )
        return out.getvalue()

    def test_skipping_links_keeps_the_coverage_gate(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
        text = self._run(self._repo(tmp_path), monkeypatch, "--skip-repo-links")
        assert "undocumented" in text, "the coverage gate must survive --skip-repo-links"
        assert "nowhere.md" not in text

    def test_skipping_coverage_keeps_the_link_pass(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
        text = self._run(self._repo(tmp_path), monkeypatch, "--skip-coverage")
        assert "nowhere.md" in text
        assert "undocumented" not in text

    def test_findings_are_sorted(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
        # The docstring promises it, and stable output is what makes a diff of two runs readable.
        (tmp_path / "src").mkdir()
        (tmp_path / "doc").mkdir()
        (tmp_path / "src" / "a.py").write_text('name="zulu"\nname="alpha"\n', encoding="utf-8")
        (tmp_path / "doc" / "ref.md").write_text("nothing\n", encoding="utf-8")
        monkeypatch.setattr(
            "veaf_build.docs_check.COVERAGE_RULES",
            (CoverageRule(label="thing", source_glob="src/*.py", pattern=r'name="([a-z_]+)"', pages=("doc/ref.md",)),),
        )
        assert check_doc_coverage(tmp_path) == sorted(check_doc_coverage(tmp_path))
