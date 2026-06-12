"""Tests for the doc-chatbot Worker client — CHATBOT-CLI (Worker-only)."""

from __future__ import annotations

import unittest
from unittest import mock

from doc_chatbot import worker_client
from doc_chatbot.worker_client import WorkerChatWorker


class _StreamResp:
    def __init__(self, status: int, lines: list[str]):
        self.status_code = status
        self._lines = lines

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    def iter_lines(self, decode_unicode=False):
        yield from self._lines


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

    def test_network_error_raises_runtimeerror(self) -> None:
        worker = WorkerChatWorker(endpoint="https://x/chat")
        with mock.patch.object(
            worker_client.requests, "post", side_effect=worker_client.requests.RequestException("offline")
        ):
            with self.assertRaises(RuntimeError):
                list(worker.ask("q"))


if __name__ == "__main__":
    unittest.main()
