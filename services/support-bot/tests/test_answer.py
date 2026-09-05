"""Turning a model's answer into a message: the source trailer, the links, and what never gets cut.

The rule the whole module exists to keep is one-directional: the bot may show **fewer** sources than
the answer used, never more, and never one that is not a real page. So the tests are written from
that side — every case that could produce a link out of nothing has an assertion.
"""

from __future__ import annotations

import unittest

from veaf_support_bot.answer import (
    DISCORD_MESSAGE_LIMIT,
    DISCORD_THREAD_NAME_LIMIT,
    MAX_SOURCES,
    SOURCES_MARKER,
    protocol_turns,
    render,
    render_partial,
    source_links,
    split_sources,
    thread_name,
)
from veaf_support_bot.texts import support_page_url, text

REAL_TITLE = "Obtenir de l'aide"
REAL_TITLE_EN = "Getting help"


class TestTheProtocolTurn(unittest.TestCase):
    def test_the_question_is_the_last_turn_and_carries_no_instructions(self) -> None:
        """The Worker embeds the last user turn to retrieve; instructions there poison retrieval."""
        turns = protocol_turns("comment builder ?")

        self.assertEqual(turns[-1], {"role": "user", "content": "comment builder ?"})

    def test_the_turns_alternate_so_the_model_accepts_them(self) -> None:
        roles = [turn["role"] for turn in protocol_turns("q")]

        self.assertEqual(roles, ["user", "assistant", "user"])

    def test_the_instruction_names_the_marker_the_parser_looks_for(self) -> None:
        """A protocol and a parser that disagree would silently produce no sources, ever."""
        self.assertIn(SOURCES_MARKER, protocol_turns("q")[0]["content"])


class TestSplittingTheTrailer(unittest.TestCase):
    def test_the_titles_are_read_off_the_trailer(self) -> None:
        body, titles = split_sources(f"La réponse.\n{SOURCES_MARKER} Un titre| Un autre")

        self.assertEqual(titles, ["Un titre", "Un autre"])

    def test_the_trailer_is_removed_from_the_body(self) -> None:
        body, _ = split_sources(f"La réponse.\n{SOURCES_MARKER} Un titre")

        self.assertEqual(body, "La réponse.")

    def test_an_answer_without_a_trailer_is_returned_whole(self) -> None:
        body, titles = split_sources("La réponse, sans rien après.")

        self.assertEqual((body, titles), ("La réponse, sans rien après.", []))

    def test_an_empty_trailer_declares_no_source(self) -> None:
        """The model saying "I used none" must not be read as a title."""
        body, titles = split_sources(f"La réponse.\n{SOURCES_MARKER}")

        self.assertEqual((body, titles), ("La réponse.", []))

    def test_a_model_quoting_the_protocol_before_obeying_it_uses_the_last_line(self) -> None:
        answer = f"Je dois finir par {SOURCES_MARKER} <titre>. Voici la réponse.\n{SOURCES_MARKER} {REAL_TITLE}"

        _, titles = split_sources(answer)

        self.assertEqual(titles, [REAL_TITLE])

    def test_decoration_around_a_title_is_stripped(self) -> None:
        _, titles = split_sources(f"x\n{SOURCES_MARKER} `{REAL_TITLE}`| **Autre**")

        self.assertEqual(titles, [REAL_TITLE, "Autre"])

    def test_a_title_declared_twice_is_one_title(self) -> None:
        _, titles = split_sources(f"x\n{SOURCES_MARKER} A| A| B")

        self.assertEqual(titles, ["A", "B"])


class TestLinks(unittest.TestCase):
    def test_a_real_title_becomes_a_link_to_its_page(self) -> None:
        self.assertEqual(
            source_links([REAL_TITLE], "fr"), [f"[{REAL_TITLE}](https://veaf.github.io/documentation/dev/SUPPORT/)"]
        )

    def test_the_english_corpus_answers_the_english_page(self) -> None:
        self.assertIn("/en/SUPPORT/", source_links([REAL_TITLE_EN], "en")[0])

    def test_a_title_the_corpus_does_not_have_yields_nothing(self) -> None:
        """Not a link, and not a bare title either — an uncheckable source is worse than none."""
        self.assertEqual(source_links(["Le Grand Livre Des Choses"], "fr"), [])

    def test_a_title_from_the_other_language_is_not_linked(self) -> None:
        """The two corpora share no titles; a cross-language hit would link the wrong page."""
        self.assertEqual(source_links([REAL_TITLE_EN], "fr"), [])

    def test_a_retyped_title_still_matches(self) -> None:
        """The model retypes headings rather than copying bytes, so case and spacing must survive."""
        self.assertEqual(len(source_links(["  obtenir   de L'AIDE.  "], "fr")), 1)

    def test_two_titles_resolving_to_one_page_are_one_source(self) -> None:
        self.assertEqual(len(source_links([REAL_TITLE, "OBTENIR DE L'AIDE"], "fr")), 1)

    def test_the_footer_does_not_become_a_wall(self) -> None:
        titles = [REAL_TITLE, "Référence CLI", "Lire les journaux de DCS", "Le build", "Les fiches", "Alias"]

        self.assertLessEqual(len(source_links(titles, "fr")), MAX_SOURCES)


class TestTheRenderedMessage(unittest.TestCase):
    def test_the_sources_are_shown_when_there_are_any(self) -> None:
        rendered = render("La réponse.", source_links([REAL_TITLE], "fr"), "fr")

        self.assertIn(REAL_TITLE, rendered)

    def test_no_source_routes_the_reader_to_the_support_page(self) -> None:
        """That is how "the documentation does not cover this" reaches the reader in this lot."""
        rendered = render("La réponse.", [], "fr")

        self.assertIn(support_page_url("fr"), rendered)

    def test_the_caveat_is_always_there(self) -> None:
        self.assertIn(text("ask.disclaimer", "fr"), render("x", [], "fr"))

    def test_a_long_answer_fits_in_a_discord_message(self) -> None:
        self.assertLessEqual(len(render("mot " * 900, [], "fr")), DISCORD_MESSAGE_LIMIT)

    def test_it_is_the_answer_that_is_cut_never_the_caveat(self) -> None:
        """An answer that loses its caveat looks authoritative. That is the wrong thing to lose."""
        rendered = render("mot " * 900, source_links([REAL_TITLE], "fr"), "fr")

        self.assertIn(text("ask.disclaimer", "fr"), rendered)
        self.assertIn(REAL_TITLE, rendered)

    def test_a_truncated_answer_says_it_was_truncated(self) -> None:
        self.assertIn(text("ask.truncated", "fr"), render("mot " * 900, [], "fr"))

    def test_an_answer_that_is_only_a_trailer_still_produces_a_message(self) -> None:
        """Discord refuses an empty message; a blank one would fail the edit and show nothing."""
        self.assertTrue(render("", [], "fr").strip())


class TestTheStreamingPlaceholder(unittest.TestCase):
    def test_nothing_yet_shows_the_thinking_line(self) -> None:
        self.assertEqual(render_partial("", "fr"), text("ask.thinking", "fr"))

    def test_a_partial_answer_carries_no_caveat_and_no_sources(self) -> None:
        """Neither is known yet, and a caveat under half an answer invites acting on it."""
        partial = render_partial("La moitié de la ré", "fr")

        self.assertNotIn(text("ask.disclaimer", "fr"), partial)
        self.assertIn("La moitié de la ré", partial)

    def test_a_half_arrived_trailer_is_not_shown_to_the_reader(self) -> None:
        self.assertNotIn(SOURCES_MARKER, render_partial(f"La réponse.\n{SOURCES_MARKER} Un ti", "fr"))

    def test_a_long_partial_still_fits_in_a_discord_message(self) -> None:
        self.assertLessEqual(len(render_partial("mot " * 900, "fr")), DISCORD_MESSAGE_LIMIT)


class TestTheThreadName(unittest.TestCase):
    def test_it_carries_the_question(self) -> None:
        self.assertIn("comment builder", thread_name("comment builder une mission ?"))

    def test_it_fits_discord_s_limit(self) -> None:
        self.assertLessEqual(len(thread_name("mot " * 200)), DISCORD_THREAD_NAME_LIMIT)

    def test_a_question_made_only_of_punctuation_still_names_the_thread(self) -> None:
        """Discord refuses a blank thread name, and a refused thread costs the answer its home."""
        self.assertTrue(thread_name("   ").strip())

    def test_newlines_do_not_reach_the_name(self) -> None:
        self.assertNotIn("\n", thread_name("comment\nbuilder ?"))


if __name__ == "__main__":
    unittest.main()
