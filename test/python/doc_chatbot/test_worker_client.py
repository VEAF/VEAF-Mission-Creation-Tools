"""Tests for the doc-chatbot Worker client — CHATBOT-CLI (Worker-only)."""

from __future__ import annotations

import json
import unittest
from unittest import mock

from doc_chatbot import worker_client
from doc_chatbot.worker_client import WorkerChatWorker


class _StreamResp:
    def __init__(self, status: int, lines: list[str], text: str | None = None):
        self.status_code = status
        self._lines = lines
        self.text = "\n".join(lines) if text is None else text

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    def iter_lines(self, decode_unicode=False):
        yield from self._lines


class _BrokenBodyResp:
    """A refusal whose body cannot be read back (connection dropped mid-read)."""

    def __init__(self, status: int):
        self.status_code = status

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    @property
    def text(self) -> str:
        raise worker_client.requests.RequestException("connection dropped")

    def iter_lines(self, decode_unicode=False):
        yield from ()


class TestWorkerChatWorker(unittest.TestCase):
    def test_streams_text_and_stops_at_done(self) -> None:
        worker = WorkerChatWorker(lang="fr", endpoint="https://x/chat")
        lines = [
            'data: {"text": "Hello "}',
            "data: [DONE]",
            'data: {"text": "world"}',
        ]
        with mock.patch.object(worker_client.requests, "post", return_value=_StreamResp(200, lines)):
            self.assertEqual("".join(worker.ask("q")), "Hello world")

    def test_sends_cli_header_and_payload(self) -> None:
        worker = WorkerChatWorker(lang="en", endpoint="https://x/chat")
        captured: dict = {}

        def fake_post(url, json=None, headers=None, timeout=None, stream=None):
            captured["url"] = url
            captured["json"] = json
            captured["headers"] = headers
            return _StreamResp(200, ["data: [DONE]"])

        with mock.patch.object(worker_client.requests, "post", side_effect=fake_post):
            list(worker.ask("How?", history=[{"role": "user", "content": "hi"}]))
        self.assertEqual(captured["headers"]["X-VEAF-Client"], "cli")
        self.assertEqual(captured["json"]["lang"], "en")
        self.assertEqual(captured["json"]["messages"][-1], {"role": "user", "content": "How?"})
        self.assertEqual(captured["json"]["messages"][0], {"role": "user", "content": "hi"})

    def test_error_payload_raises(self) -> None:
        worker = WorkerChatWorker(endpoint="https://x/chat")
        with mock.patch.object(
            worker_client.requests, "post", return_value=_StreamResp(200, ['data: {"error": "rate limited"}'])
        ):
            with self.assertRaises(RuntimeError):
                list(worker.ask("q"))

    def test_non_200_raises(self) -> None:
        worker = WorkerChatWorker(endpoint="https://x/chat")
        with mock.patch.object(worker_client.requests, "post", return_value=_StreamResp(500, [])):
            with self.assertRaises(RuntimeError):
                list(worker.ask("q"))

    def test_non_200_surfaces_the_worker_message(self) -> None:
        """A 429 carries the Worker's own explanation in its body; it must reach the user.

        The daily allowance message says when the assistant comes back. Reporting only
        ``error 429`` threw that away and made a rationed assistant look like a broken one.
        """
        daily = "L'assistant a épuisé son allocation de questions pour la journée. Vers 9 h."
        resp = _StreamResp(429, [], text=f'data: {{"error": {json.dumps(daily, ensure_ascii=False)}}}\n\n')
        worker = WorkerChatWorker(endpoint="https://x/chat")
        with mock.patch.object(worker_client.requests, "post", return_value=resp):
            with self.assertRaises(RuntimeError) as caught:
                list(worker.ask("q"))
        self.assertEqual(daily, str(caught.exception))

    def test_non_200_without_a_message_falls_back_to_the_status(self) -> None:
        worker = WorkerChatWorker(endpoint="https://x/chat")
        resp = _StreamResp(502, [], text="<html>Bad gateway</html>")
        with mock.patch.object(worker_client.requests, "post", return_value=resp):
            with self.assertRaises(RuntimeError) as caught:
                list(worker.ask("q"))
        self.assertIn("502", str(caught.exception))

    def test_non_200_with_an_unreadable_body_falls_back_to_the_status(self) -> None:
        worker = WorkerChatWorker(endpoint="https://x/chat")
        with mock.patch.object(worker_client.requests, "post", return_value=_BrokenBodyResp(429)):
            with self.assertRaises(RuntimeError) as caught:
                list(worker.ask("q"))
        self.assertIn("429", str(caught.exception))

    def test_network_error_raises_runtimeerror(self) -> None:
        worker = WorkerChatWorker(endpoint="https://x/chat")
        with mock.patch.object(
            worker_client.requests, "post", side_effect=worker_client.requests.RequestException("offline")
        ):
            with self.assertRaises(RuntimeError):
                list(worker.ask("q"))


if __name__ == "__main__":
    unittest.main()
