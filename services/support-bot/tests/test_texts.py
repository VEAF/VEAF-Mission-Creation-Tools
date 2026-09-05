"""The two catalogues, kept in lockstep by assertion rather than by discipline.

A French sentence with an English one missing is not a crash: it is a bot that answers half its
audience in the wrong language, which nobody notices until an English speaker asks. So the shapes of
the two catalogues are compared as a whole, not sampled.
"""

from __future__ import annotations

import inspect
import re
import unittest

from veaf_support_bot import quota, texts
from veaf_support_bot.worker import FailureKind


def _refusal_reasons() -> set[str]:
    """Return every reason the quota keeper can refuse with, read from its source.

    Enumerated rather than listed: a reason added to the keeper with no sentence beside it would be
    a blank message the user has to interpret, and a hand-maintained list would not notice.

    Returns:
        The reason strings.
    """
    source = inspect.getsource(quota)
    return set(re.findall(r'QuotaDecision\(\s*False,\s*"([a-z-]+)"', source))


class TestTheTwoCatalogues(unittest.TestCase):
    def test_they_hold_exactly_the_same_keys(self) -> None:
        self.assertEqual(texts.keys("fr"), texts.keys("en"))

    def test_a_key_uses_the_same_placeholders_in_both(self) -> None:
        """A placeholder present in one language only raises ``KeyError`` at the worst moment."""
        for key in sorted(texts.keys("fr")):
            with self.subTest(key=key):
                self.assertEqual(texts.placeholders(key, "fr"), texts.placeholders(key, "en"))

    def test_no_sentence_is_empty(self) -> None:
        for lang in texts.LANGUAGES:
            for key in sorted(texts.keys(lang)):
                with self.subTest(lang=lang, key=key):
                    self.assertTrue(texts._TEXTS[lang][key].strip())


class TestEveryOutcomeHasASentence(unittest.TestCase):
    """Enumerated from the code that produces the outcomes, never a hand-picked sample."""

    def test_every_worker_failure_kind_is_covered(self) -> None:
        for kind in FailureKind:
            for lang in texts.LANGUAGES:
                with self.subTest(kind=kind, lang=lang):
                    self.assertTrue(texts.text(f"ask.error.{kind.value}", lang))

    def test_every_quota_refusal_reason_is_covered(self) -> None:
        """The reasons are read out of the keeper's own source, so a new one cannot slip past."""
        for reason in sorted(_refusal_reasons()):
            for lang in texts.LANGUAGES:
                with self.subTest(reason=reason, lang=lang):
                    rendered = texts.text(f"quota.{reason}", lang, limit=1, reset_relative="R", reset_time="T")

                    self.assertIn("R", rendered)

    def test_the_reasons_were_actually_found(self) -> None:
        """Guards the guard: an extractor that finds nothing makes the test above vacuous.

        Compared against the keeper's own declared list rather than one written here, so the two
        ways a reason can go wrong both fail: one produced and never declared, and one declared that
        nothing produces.
        """
        self.assertTrue(_refusal_reasons())
        self.assertEqual(_refusal_reasons(), set(quota.REFUSAL_REASONS))


class TestLanguageSelection(unittest.TestCase):
    def test_an_english_locale_answers_in_english(self) -> None:
        self.assertEqual(texts.normalize_language("en-GB"), "en")

    def test_a_french_locale_answers_in_french(self) -> None:
        self.assertEqual(texts.normalize_language("fr"), "fr")

    def test_an_unindexed_language_falls_back_to_the_site_default(self) -> None:
        """The corpus exists in two languages only, and French is the site's default locale."""
        self.assertEqual(texts.normalize_language("pt-BR"), texts.DEFAULT_LANGUAGE)

    def test_no_locale_at_all_falls_back_too(self) -> None:
        self.assertEqual(texts.normalize_language(None), texts.DEFAULT_LANGUAGE)

    def test_an_unknown_language_still_renders_a_sentence(self) -> None:
        self.assertTrue(texts.text("ask.thinking", "de"))


class TestMissingKeys(unittest.TestCase):
    def test_a_key_that_does_not_exist_is_loud(self) -> None:
        """A blank the user has to interpret is worse than a crash at the first run."""
        with self.assertRaises(KeyError):
            texts.text("ask.does_not_exist", "fr")


class TestTheSupportPageLink(unittest.TestCase):
    def test_the_french_page_is_at_the_site_root(self) -> None:
        self.assertEqual(texts.support_page_url("fr"), f"{texts.DOC_SITE_BASE}/SUPPORT/")

    def test_the_english_page_lives_under_en(self) -> None:
        self.assertEqual(texts.support_page_url("en"), f"{texts.DOC_SITE_BASE}/en/SUPPORT/")


if __name__ == "__main__":
    unittest.main()
