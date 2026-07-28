"""Unit tests for the docs version stamper (veaf_build.docs_version_stamp)."""

from datetime import date
from pathlib import Path

import pytest

from veaf_build.docs_version_stamp import STAMPED_PAGES, read_version, stamp, stamp_text

_FR_HEADER = """# Modules Lua VEAF — Référence API complète

**Version :** générée pour la 6.5.x
**Dernière mise à jour :** Juin 2026
**Projet :** VEAF Mission Creation Tools
"""

_EN_HEADER = """# VEAF Lua Modules - Complete API Reference

**Version:** generated for 6.5.x
**Last Updated:** June 2026
**Project:** VEAF Mission Creation Tools
"""


@pytest.fixture
def repo(tmp_path: Path) -> Path:
    """A repo skeleton carrying a pyproject version and both stamped pages."""
    (tmp_path / "pyproject.toml").write_text('[tool.poetry]\nversion = "6.11.9"\n', encoding="utf-8")
    for rel, text in zip(STAMPED_PAGES, (_FR_HEADER, _EN_HEADER)):
        page = tmp_path / rel
        page.parent.mkdir(parents=True, exist_ok=True)
        page.write_text(text, encoding="utf-8")
    return tmp_path


class TestReadVersion:
    def test_reads_the_declared_version(self, repo: Path):
        assert read_version(repo / "pyproject.toml") == "6.11.9"

    def test_raises_when_absent(self, tmp_path: Path):
        empty = tmp_path / "pyproject.toml"
        empty.write_text("[tool.poetry]\n", encoding="utf-8")
        with pytest.raises(ValueError):
            read_version(empty)


class TestStampText:
    def test_french_page_keeps_french_wording(self):
        out = stamp_text(_FR_HEADER, "6.11.9", date(2026, 7, 28), french=True)
        assert "**Version :** générée pour la 6.11.9" in out
        assert "**Dernière mise à jour :** Juillet 2026" in out

    def test_english_page_keeps_english_wording(self):
        out = stamp_text(_EN_HEADER, "6.11.9", date(2026, 7, 28), french=False)
        assert "**Version:** generated for 6.11.9" in out
        assert "**Last Updated:** July 2026" in out

    def test_leaves_other_lines_alone(self):
        out = stamp_text(_FR_HEADER, "6.11.9", date(2026, 7, 28), french=True)
        assert "**Projet :** VEAF Mission Creation Tools" in out

    def test_page_without_headers_is_untouched(self):
        text = "# Some page\n\nNo version header here.\n"
        assert stamp_text(text, "6.11.9", date(2026, 7, 28), french=True) == text

    def test_only_the_header_version_is_rewritten(self):
        # A per-module "**Version :**" further down the page must survive.
        text = _FR_HEADER + "\n## veafSpawn\n\n**Version :** 1.56.2\n"
        out = stamp_text(text, "6.11.9", date(2026, 7, 28), french=True)
        assert "**Version :** 1.56.2" in out
        assert "**Version :** générée pour la 6.11.9" in out


class TestStamp:
    def test_writes_both_pages(self, repo: Path):
        assert sorted(stamp(repo, today=date(2026, 7, 28))) == sorted(STAMPED_PAGES)
        assert "6.11.9" in (repo / STAMPED_PAGES[0]).read_text(encoding="utf-8")

    def test_is_idempotent(self, repo: Path):
        stamp(repo, today=date(2026, 7, 28))
        assert stamp(repo, today=date(2026, 7, 28)) == []

    def test_check_only_does_not_write(self, repo: Path):
        before = (repo / STAMPED_PAGES[0]).read_text(encoding="utf-8")
        assert stamp(repo, check_only=True, today=date(2026, 7, 28))
        assert (repo / STAMPED_PAGES[0]).read_text(encoding="utf-8") == before

    def test_missing_page_is_skipped(self, tmp_path: Path):
        (tmp_path / "pyproject.toml").write_text('version = "6.11.9"\n', encoding="utf-8")
        assert stamp(tmp_path, today=date(2026, 7, 28)) == []
