"""Tests for the maintainer's Discord reader.

The interesting failures here are the ones that produce **no error**: a sweep that returns an empty
list because a filter stopped matching, or one that ends early on a channel the bot may not enter.
Both were real — see the comments in the module under test — and both look exactly like *nothing to
report*, which is the worst thing a triage tool can do.

The module lives under ``scripts/`` rather than in the package: it is a maintainer tool, not part of
the service, so it is loaded by path.
"""

from __future__ import annotations

import importlib.util
import pathlib
import unittest
from typing import Any
from unittest import mock

_PATH = pathlib.Path(__file__).resolve().parent.parent / "scripts" / "discord_read.py"
_SPEC = importlib.util.spec_from_file_location("discord_read", _PATH)
assert _SPEC and _SPEC.loader
discord_read = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(discord_read)

BOT = "1545777971649052692"
SOMEBODY = "421317390807203850"


def _thread(thread_id: str, owner: str = BOT) -> dict[str, Any]:
    """Build a minimal thread object."""
    return {"id": thread_id, "name": f"thread {thread_id}", "owner_id": owner, "message_count": 1}


class TheBotIdentity(unittest.TestCase):
    """The id the sweeps filter on is asked for, never assumed."""

    def test_it_comes_from_the_token(self) -> None:
        with mock.patch.object(discord_read, "_get", return_value={"id": "42"}) as get:
            self.assertEqual(discord_read._whoami("tok"), "42")
        get.assert_called_once_with("/users/@me", "tok")


class TheActiveSweep(unittest.TestCase):
    def test_it_keeps_only_the_threads_the_bot_opened(self) -> None:
        payload = {"threads": [_thread("1"), _thread("2", owner=SOMEBODY), _thread("3")]}
        with mock.patch.object(discord_read, "_get", return_value=payload):
            found = discord_read._bot_threads("tok", "guild", archived=False, bot_id=BOT)
        self.assertEqual([t["id"] for t in found], ["1", "3"])


class TheArchivedSweep(unittest.TestCase):
    """Two defects lived here, both measured on 2026-09-22 and both silent in their own way."""

    @staticmethod
    def _api(channels: list[dict[str, Any]], refused: set[str] | None = None) -> Any:
        """Return a `_get` double over a guild with the given channels.

        Args:
            channels: The channel objects `/guilds/{id}/channels` answers with.
            refused: Channel ids that answer as forbidden — `_get(optional=True)` returns None.

        Returns:
            A callable with `_get`'s signature.
        """
        refused = refused or set()

        def fake(path: str, token: str, optional: bool = False) -> Any:
            if path.endswith("/threads/active"):
                return {"threads": []}
            if path.endswith("/channels"):
                return channels
            channel_id = path.split("/")[2]
            if channel_id in refused:
                if not optional:
                    raise SystemExit(f"HTTP 403 on {path}")
                return None
            return {"threads": [_thread(f"t{channel_id}")]}

        return fake

    def test_a_forbidden_channel_does_not_end_the_sweep(self) -> None:
        """The one that made `--archived` fail every single time on a real guild."""
        channels = [{"id": "a", "type": 0}, {"id": "b", "type": 0}, {"id": "c", "type": 15}]
        with mock.patch.object(discord_read, "_get", self._api(channels, refused={"b"})):
            found = discord_read._bot_threads("tok", "guild", archived=True, bot_id=BOT)
        self.assertEqual([t["id"] for t in found], ["ta", "tc"], "a refused channel must be skipped, not fatal")

    def test_it_sweeps_the_text_channel_that_holds_the_ask_threads(self) -> None:
        """`/ask` hangs off a text channel, so sweeping forums alone would find none of it."""
        channels = [{"id": "text", "type": 0}, {"id": "forum", "type": 15}]
        with mock.patch.object(discord_read, "_get", self._api(channels)):
            found = discord_read._bot_threads("tok", "guild", archived=True, bot_id=BOT)
        self.assertIn("ttext", [t["id"] for t in found])

    def test_it_leaves_voice_and_category_channels_alone(self) -> None:
        """Those cannot hold threads; asking would spend a request per channel for nothing."""
        channels = [{"id": "voice", "type": 2}, {"id": "category", "type": 4}, {"id": "text", "type": 0}]
        with mock.patch.object(discord_read, "_get", self._api(channels)):
            found = discord_read._bot_threads("tok", "guild", archived=True, bot_id=BOT)
        self.assertEqual([t["id"] for t in found], ["ttext"])


class TheMessageFetch(unittest.TestCase):
    def test_a_single_message_asks_for_one_not_a_hundred(self) -> None:
        """The triage sweep does this once per thread; a page of 100 each time is all payload."""
        calls: list[str] = []

        def fake(path: str, token: str, optional: bool = False) -> Any:
            calls.append(path)
            return [{"id": "9", "timestamp": "2026-09-22T10:00:00.000000+00:00", "author": {"username": "x"}}]

        with mock.patch.object(discord_read, "_get", fake):
            discord_read._messages("chan", "tok", limit=1)
        # Compared whole, not with `assertIn("limit=1", ...)`: that substring is also in `limit=100`,
        # so the loose form stayed green against the very code it was written to catch.
        self.assertEqual(calls[0], "/channels/chan/messages?limit=1")

    def test_the_newest_message_is_last(self) -> None:
        """Discord answers newest-first; everything downstream reads `[-1]` as *the latest*."""
        page = [
            {"id": "2", "timestamp": "2026-09-22T11:00:00+00:00", "author": {"username": "b"}},
            {"id": "1", "timestamp": "2026-09-22T10:00:00+00:00", "author": {"username": "a"}},
        ]
        with mock.patch.object(discord_read, "_get", return_value=page):
            got = discord_read._messages("chan", "tok", limit=2)
        self.assertEqual(got[-1]["id"], "2")


class TheRendering(unittest.TestCase):
    def test_it_keeps_embeds_and_names_attachments(self) -> None:
        message = {
            "timestamp": "2026-09-22T10:00:00+00:00",
            "author": {"username": "zip9285", "global_name": "Zip", "bot": False},
            "content": "the question",
            "embeds": [{"title": "A page", "description": "what it says"}],
            "attachments": [{"filename": "dcs.log", "url": "https://example.invalid/dcs.log"}],
        }
        out = discord_read._render([message])
        self.assertIn("Zip", out)
        self.assertIn("the question", out)
        self.assertIn("A page", out)
        self.assertIn("dcs.log", out)
        self.assertNotIn("(BOT)", out)

    def test_it_marks_the_bot(self) -> None:
        message = {
            "timestamp": "2026-09-22T10:00:00+00:00",
            "author": {"username": "VEAF Tools Bot", "bot": True},
            "content": "an answer",
        }
        self.assertIn("(BOT)", discord_read._render([message]))


class TheCredentials(unittest.TestCase):
    def test_an_empty_token_is_refused_by_name(self) -> None:
        """Rather than a 401 from Discord three calls later."""
        env = pathlib.Path(self.enterContext(__import__("tempfile").TemporaryDirectory())) / ".env"
        env.write_text("SUPPORT_BOT_DISCORD_TOKEN=\nSUPPORT_BOT_DISCORD_GUILD_ID=1\n", encoding="utf-8")
        with mock.patch.object(discord_read, "_ENV", env):
            with self.assertRaises(SystemExit) as raised:
                discord_read._load_env()
        self.assertIn("SUPPORT_BOT_DISCORD_TOKEN", str(raised.exception))

    def test_a_missing_file_says_which_one(self) -> None:
        with mock.patch.object(discord_read, "_ENV", pathlib.Path("nowhere/.env")):
            with self.assertRaises(SystemExit) as raised:
                discord_read._load_env()
        self.assertIn(".env", str(raised.exception))


class TheLinkParsing(unittest.TestCase):
    def test_a_message_link_yields_channel_and_message(self) -> None:
        link = "https://discord.com/channels/471061487662792715/1551871856972271616/1551989490485301339"
        match = discord_read._LINK.search(link)
        assert match
        self.assertEqual(match.group(2), "1551871856972271616")
        self.assertEqual(match.group(3), "1551989490485301339")

    def test_a_thread_link_has_no_message_part(self) -> None:
        match = discord_read._LINK.search("https://discord.com/channels/471061487662792715/1551871856972271616")
        assert match
        self.assertIsNone(match.group(3))

    def test_a_bare_id_is_not_a_link(self) -> None:
        """Which is why `message` refuses one: the API cannot resolve a message id alone."""
        self.assertIsNone(discord_read._LINK.search("1551989490485301339"))


if __name__ == "__main__":
    unittest.main()
