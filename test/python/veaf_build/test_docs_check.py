"""Unit tests for the documentation gate (veaf_build.docs_check).

Each test builds a miniature docs tree, because the point of the gate is what it does with
*shapes* — a missing translation, an anchor left behind by a renumbering — not with our own pages.

Two behaviours are pinned deliberately, since getting them wrong is what made the DOC-AUDIT-PASS
audit produce 245 false positives before being verified against the published site: relative links
are language-agnostic (the i18n plugin rewrites them) and anchors keep their accents.
"""

from pathlib import Path

import pytest

from veaf_build.docs_check import EXEMPT, check_docs, format_report, slugify


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
