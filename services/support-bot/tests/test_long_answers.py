"""An answer longer than one Discord message, in a thread that has room for several.

Found by David an hour after the follow-up shipped: the continuation worked, and its answer ended on
*"✂️ Réponse tronquée"*. A thread is exactly the place where a second message costs nothing, and the
invitation added that evening had taken 146 of the body's 1849 characters — on the very exchanges
that produce the longest answers.
"""

from __future__ import annotations

import unittest

from veaf_support_bot.answer import (
    DISCORD_MESSAGE_LIMIT,
    MAX_ANSWER_MESSAGES,
    render,
    render_messages,
)
from veaf_support_bot.texts import text

A_LINK = "[une page](https://veaf.github.io/documentation/dev/x/)"


def _lines(count: int, width: int = 80) -> str:
    """Build a body of *count* lines.

    Args:
        count: How many lines.
        width: How wide each one is.

    Returns:
        The body.
    """
    return "\n".join(f"ligne {index:04d} " + "x" * width for index in range(count))


class TheAnswerArrivesWhole(unittest.TestCase):
    """The point of the lot: nothing is cut that a second message could carry."""

    def test_a_short_answer_is_still_one_message(self) -> None:
        parts = render_messages("une réponse courte", [A_LINK], "fr")

        self.assertEqual(len(parts), 1)
        self.assertEqual(parts[0], render("une réponse courte", [A_LINK], "fr"))

    def test_three_thousand_characters_arrive_in_two_messages(self) -> None:
        body = _lines(35)

        parts = render_messages(body, [A_LINK], "fr")

        self.assertGreater(len(body), DISCORD_MESSAGE_LIMIT)
        self.assertEqual(len(parts), 2)
        for part in parts:
            with self.subTest(part=part[:40]):
                self.assertLessEqual(len(part), DISCORD_MESSAGE_LIMIT)

    def test_nothing_of_the_answer_is_lost(self) -> None:
        body = _lines(35)

        joined = "\n".join(render_messages(body, [A_LINK], "fr"))

        for line in body.split("\n"):
            with self.subTest(line=line[:20]):
                self.assertIn(line, joined)

    def test_no_truncation_notice_when_it_simply_overflows(self) -> None:
        parts = render_messages(_lines(35), [A_LINK], "fr")

        self.assertNotIn(text("ask.truncated", "fr"), "\n".join(parts))


class TheFooterGoesOnTheLastMessage(unittest.TestCase):
    """Sources and caveat are what a reader needs to contradict the answer."""

    def test_the_sources_are_on_the_last_part_and_only_there(self) -> None:
        parts = render_messages(_lines(35), [A_LINK], "fr")

        self.assertIn(A_LINK, parts[-1])
        self.assertNotIn(A_LINK, parts[0])

    def test_the_caveat_is_on_the_last_part(self) -> None:
        parts = render_messages(_lines(35), [A_LINK], "fr")

        self.assertIn(text("ask.disclaimer", "fr"), parts[-1])
        self.assertNotIn(text("ask.disclaimer", "fr"), parts[0])

    def test_the_footer_still_fits_when_the_last_part_is_nearly_full(self) -> None:
        """The room for the footer is reserved on the last part before it is filled."""
        for count in range(20, 60):
            with self.subTest(lines=count):
                parts = render_messages(_lines(count), [A_LINK], "fr")
                self.assertLessEqual(len(parts[-1]), DISCORD_MESSAGE_LIMIT)
                self.assertIn(text("ask.disclaimer", "fr"), parts[-1])


class ACodeBlockSurvivesTheSplit(unittest.TestCase):
    """Half a fenced block renders as prose, which is worse than a cut sentence."""

    def _split_inside_a_block(self) -> list[str]:
        """Build an answer whose code block spans the boundary.

        Returns:
            The rendered parts.
        """
        body = "voici la configuration :\n\n```yaml\n" + _lines(30, width=60) + "\n```\n\net voilà."
        return render_messages(body, [A_LINK], "fr")

    def test_the_block_is_closed_at_the_end_of_a_part(self) -> None:
        parts = self._split_inside_a_block()

        self.assertGreater(len(parts), 1)
        for part in parts:
            with self.subTest(part=part[:30]):
                self.assertEqual(part.count("```") % 2, 0, "an odd number of fences leaves it open")

    def test_the_block_is_reopened_on_the_next_part(self) -> None:
        parts = self._split_inside_a_block()

        self.assertTrue(parts[1].lstrip().startswith("```"), "the continuation must be code, not prose")


class APreposterousAnswerIsStillBounded(unittest.TestCase):
    """Past a handful of messages, an answer is not an answer."""

    def test_it_stops_at_the_ceiling(self) -> None:
        parts = render_messages(_lines(400), [A_LINK], "fr")

        self.assertEqual(len(parts), MAX_ANSWER_MESSAGES)

    def test_and_it_says_it_was_cut(self) -> None:
        parts = render_messages(_lines(400), [A_LINK], "fr")

        self.assertIn(text("ask.truncated", "fr"), parts[-1])


class TheInvitationIsWrittenOncePerThread(unittest.TestCase):
    """146 characters, measured, and on a continuation it describes what the reader is doing."""

    def test_it_appears_when_asked_for(self) -> None:
        parts = render_messages("courte", [A_LINK], "fr", continuable=True)

        self.assertIn(text("ask.continue", "fr"), parts[-1])

    def test_it_appears_only_on_the_last_message(self) -> None:
        parts = render_messages(_lines(35), [A_LINK], "fr", continuable=True)

        self.assertNotIn(text("ask.continue", "fr"), parts[0])
        self.assertIn(text("ask.continue", "fr"), parts[-1])

    def test_without_it_the_body_has_more_room(self) -> None:
        """The whole reason ticket 02 exists."""
        with_line = render_messages(_lines(30), [A_LINK], "fr", continuable=True)
        without = render_messages(_lines(30), [A_LINK], "fr", continuable=False)

        self.assertGreaterEqual(len(with_line[-1]) + len(text("ask.continue", "fr")), len(without[-1]))


if __name__ == "__main__":
    unittest.main()
