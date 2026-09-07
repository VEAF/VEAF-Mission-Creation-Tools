"""What the forms and the command picker show, which is the half the service never translated.

The bot translated every sentence it *says* and no label it *shows*. David switched his Discord
client to French on 2026-09-07 to check, and nothing moved — French being the service's own default
language, its most visible surface was English-only.

Two surfaces, and they are not fixed the same way:

* a **modal** is built when the command is typed, so the interaction — and its locale — are in hand;
* a **command description** is registered once, before any interaction exists, which is why the
  second half of this goes through Discord's own translation table.
"""

from __future__ import annotations

import unittest
from typing import Any, cast

import discord
from discord import app_commands

from veaf_support_bot.discord_bot import (
    _FRENCH_LOCALES,
    _REGISTERED_STRINGS,
    BugModal,
    SuggestModal,
    VeafTranslator,
)
from veaf_support_bot.suggestion import COMPONENTS
from veaf_support_bot.texts import text


def _bug(lang: str) -> BugModal:
    """Build a bug form in one language.

    Args:
        lang: ``"fr"`` or ``"en"``.

    Returns:
        The modal.
    """
    return BugModal(cast(Any, None), [], cast(Any, None), lang=lang)


def _suggest(lang: str) -> SuggestModal:
    """Build a suggestion form in one language.

    Args:
        lang: ``"fr"`` or ``"en"``.

    Returns:
        The modal.
    """
    return SuggestModal(cast(Any, None), COMPONENTS[0], cast(Any, None), lang=lang)


class TheFormsSpeakTheAskersLanguage(unittest.TestCase):
    """The eleven labels, two titles and one placeholder that were hard-coded English."""

    def test_the_bug_form_differs_between_the_two_languages(self) -> None:
        french, english = _bug("fr"), _bug("en")

        self.assertNotEqual(french.title, english.title)
        for field in ("summary", "happened", "expected", "steps", "doctor"):
            with self.subTest(field=field):
                self.assertNotEqual(getattr(french, field).label, getattr(english, field).label)

    def test_the_suggestion_form_differs_too(self) -> None:
        french, english = _suggest("fr"), _suggest("en")

        self.assertNotEqual(french.title, english.title)
        self.assertNotEqual(french.problem.label, english.problem.label)
        self.assertNotEqual(french.problem.placeholder, english.problem.placeholder)

    def test_the_labels_come_from_the_catalogue(self) -> None:
        """Not from a second table nobody keeps at parity with the first."""
        self.assertEqual(_bug("fr").title, text("form.bug.title", "fr"))
        self.assertEqual(_bug("fr").doctor.label, text("form.bug.doctor", "fr"))

    def test_a_french_form_is_really_french(self) -> None:
        self.assertEqual(_bug("fr").title, "Signaler un bug")


class TheComponentValuesAreNotTranslated(unittest.TestCase):
    """They are the issue templates' own options, word for word.

    A translated value is a component nobody can filter on, which is worse than an English label.
    """

    def test_the_component_the_form_carries_is_the_template_s_own(self) -> None:
        for lang in ("fr", "en"):
            with self.subTest(lang=lang):
                self.assertEqual(_suggest(lang)._component, COMPONENTS[0])


class TheRegisteredSurfaceIsTranslatedThroughDiscord(unittest.IsolatedAsyncioTestCase):
    """The command picker: `/ask`, `/bug`, `/suggest` and their option descriptions.

    This is what a mission maker sees before typing anything, and no per-interaction fix can reach
    it — the descriptions are uploaded with the commands, once.
    """

    async def _translate(self, source: str, locale: discord.Locale) -> str | None:
        """Ask the translator for one string.

        Args:
            source: The English source, as declared at registration.
            locale: The client's language.

        Returns:
            What Discord would store, or ``None``.
        """
        return await VeafTranslator().translate(
            app_commands.locale_str(source),
            locale,
            cast(Any, None),
        )

    async def test_a_french_client_gets_french(self) -> None:
        translated = await self._translate("Report a bug — a short form, and the files you have", discord.Locale.french)

        self.assertEqual(translated, text("command.bug.description", "fr"))

    async def test_an_english_client_keeps_the_declared_string(self) -> None:
        self.assertIsNone(
            await self._translate(
                "Report a bug — a short form, and the files you have", discord.Locale.american_english
            )
        )

    async def test_a_string_nobody_translated_shows_the_original(self) -> None:
        """A missing key must show English, never an empty description or a placeholder."""
        self.assertIsNone(await self._translate("something nobody registered", discord.Locale.french))

    async def test_every_registered_string_has_a_key_that_resolves(self) -> None:
        """A table entry pointing at a key the catalogue does not hold would fail at run time."""
        for source, key in _REGISTERED_STRINGS.items():
            with self.subTest(source=source):
                self.assertTrue(text(key, "fr"))
                self.assertEqual(text(key, "en"), source, "the English catalogue is the declared string")

    def test_canadian_french_is_french_too(self) -> None:
        self.assertIn("fr-CA", _FRENCH_LOCALES)


class TheTranslatorIsInstalledBeforeTheCommandsAreUploaded(unittest.TestCase):
    """A translator set after the sync translates nothing until the next restart.

    The repository has shipped that shape before: a thing that works, wired at the wrong moment.
    """

    def test_setup_hook_sets_the_translator_before_it_syncs(self) -> None:
        import inspect

        from veaf_support_bot.discord_bot import SupportBotClient

        source = inspect.getsource(SupportBotClient.setup_hook)

        self.assertLess(
            source.index("set_translator"),
            source.index("copy_global_to"),
            "the translations are uploaded with the commands, so they must be set first",
        )


if __name__ == "__main__":
    unittest.main()
