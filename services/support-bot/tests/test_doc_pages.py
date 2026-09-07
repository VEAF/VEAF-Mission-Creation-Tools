"""The link index: that it matches the real documentation, and that the URL rule is the site's.

The checked-in index is generated data. Generated data that nobody re-derives becomes wrong quietly:
a page renamed in ``doc/`` would leave the bot citing a title that no longer exists, or worse,
linking a URL that 404s. So the index is rebuilt here from the real tree and compared.
"""

from __future__ import annotations

import unittest
from pathlib import Path

from veaf_support_bot.doc_pages import (
    PAGES_BY_TITLE,
    build_index,
    normalize_title,
    page_url,
    resolve_title,
)
from veaf_support_bot.texts import DOC_SITE_BASE

DOC_DIR = Path(__file__).resolve().parents[3] / "doc"


class TestTheIndexMatchesTheDocumentation(unittest.TestCase):
    def test_the_documentation_tree_is_where_the_test_thinks_it_is(self) -> None:
        """Guards the guard: a wrong path would make every comparison below vacuous."""
        self.assertTrue((DOC_DIR / "SUPPORT.md").is_file(), f"no documentation tree at {DOC_DIR}")

    def test_the_checked_in_index_is_what_the_generator_produces(self) -> None:
        """Run ``poetry run python scripts/refresh_doc_pages.py`` when this fails."""
        self.assertEqual(PAGES_BY_TITLE, build_index(DOC_DIR))

    def test_both_languages_are_indexed(self) -> None:
        self.assertEqual(set(PAGES_BY_TITLE), {"fr", "en"})

    def test_the_index_is_not_empty(self) -> None:
        self.assertGreater(len(PAGES_BY_TITLE["fr"]), 50)

    def test_every_indexed_path_is_a_real_file(self) -> None:
        for lang, pages in PAGES_BY_TITLE.items():
            for title, relative in pages.items():
                with self.subTest(lang=lang, title=title):
                    self.assertTrue((DOC_DIR / relative).is_file())


class TestTheUrlRule(unittest.TestCase):
    """Verified against a real ``mkdocs build``: 142 built pages, zero mismatches."""

    def test_a_french_page_lives_at_the_site_root(self) -> None:
        self.assertEqual(page_url("SUPPORT.md"), f"{DOC_SITE_BASE}/SUPPORT/")

    def test_an_english_page_lives_under_en(self) -> None:
        self.assertEqual(page_url("SUPPORT.en.md"), f"{DOC_SITE_BASE}/en/SUPPORT/")

    def test_a_nested_page_keeps_its_folders(self) -> None:
        self.assertEqual(page_url("mission-maker/LOGS.md"), f"{DOC_SITE_BASE}/mission-maker/LOGS/")

    def test_an_index_page_renders_as_its_directory(self) -> None:
        self.assertEqual(page_url("mission-maker/index.md"), f"{DOC_SITE_BASE}/mission-maker/")

    def test_a_readme_renders_as_its_directory_too(self) -> None:
        self.assertEqual(page_url("mission-maker/README.md"), f"{DOC_SITE_BASE}/mission-maker/")

    def test_the_site_root_is_the_site_root(self) -> None:
        self.assertEqual(page_url("index.md"), f"{DOC_SITE_BASE}/")

    def test_the_english_site_root_is_under_en(self) -> None:
        self.assertEqual(page_url("index.en.md"), f"{DOC_SITE_BASE}/en/")


class TestResolvingATitle(unittest.TestCase):
    def test_a_real_title_resolves(self) -> None:
        self.assertEqual(resolve_title("Obtenir de l'aide", "fr"), f"{DOC_SITE_BASE}/SUPPORT/")

    def test_a_title_the_corpus_does_not_have_resolves_to_nothing(self) -> None:
        self.assertIsNone(resolve_title("Le Grand Livre Des Choses", "fr"))

    def test_a_language_the_corpus_does_not_have_resolves_to_nothing(self) -> None:
        self.assertIsNone(resolve_title("Obtenir de l'aide", "de"))


class TestNormalisation(unittest.TestCase):
    """It must survive how a model retypes a title, and *only* that."""

    def test_case_does_not_matter(self) -> None:
        self.assertEqual(normalize_title("Obtenir De L'Aide"), normalize_title("obtenir de l'aide"))

    def test_doubled_spaces_do_not_matter(self) -> None:
        self.assertEqual(normalize_title("Obtenir  de   l'aide"), normalize_title("Obtenir de l'aide"))

    def test_a_non_breaking_space_does_not_matter(self) -> None:
        """French typography puts one before a colon, and the model reproduces it."""
        self.assertEqual(normalize_title("Obtenir de l'aide"), normalize_title("Obtenir de l'aide"))

    def test_surrounding_punctuation_does_not_matter(self) -> None:
        self.assertEqual(normalize_title("« Obtenir de l'aide »."), normalize_title("Obtenir de l'aide"))

    def test_a_different_title_is_still_a_different_title(self) -> None:
        """Normalisation removes decoration; it must not make two pages collide."""
        self.assertNotEqual(normalize_title("Le build"), normalize_title("Les fiches"))


class TestTheGeneratorRefusesAmbiguity(unittest.TestCase):
    def test_two_pages_sharing_a_title_are_an_error_not_a_coin_toss(self) -> None:
        with self.assertRaises(ValueError):
            self._build_with_duplicate_titles()

    def _build_with_duplicate_titles(self) -> object:
        """Build an index over a tree where two pages carry the same heading.

        Returns:
            Never; the call raises.
        """
        import tempfile

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "one.md").write_text("# Le même titre\n", encoding="utf-8")
            (root / "two.md").write_text("# Le même titre\n", encoding="utf-8")
            return build_index(root)


if __name__ == "__main__":
    unittest.main()
