"""Tests for the `ask` command answer streaming (CHATBOT-CLI).

Regression guard for the Windows truncation bug: `_stream_answer` must consume the
whole stream and return the full text, never stop early.
"""

from __future__ import annotations

import unittest
from collections.abc import Iterator

from veaf_tools.commands import ask as ask_mod


class _FakeWorker:
    """A worker whose ``ask`` yields a fixed list of text chunks."""

    def __init__(self, chunks: list[str]) -> None:
        self._chunks = chunks

    def ask(self, question: str, history: list[dict[str, str]] | None = None) -> Iterator[str]:
        yield from self._chunks


class TestStreamAnswer(unittest.TestCase):
    def test_returns_full_concatenated_text(self) -> None:
        worker = _FakeWorker(["`build_variants` ", "is a list ", "of profiles."])
        out = ask_mod._stream_answer(worker, "q", [])
        self.assertEqual(out, "`build_variants` is a list of profiles.")

    def test_empty_stream_returns_empty_string(self) -> None:
        out = ask_mod._stream_answer(_FakeWorker([]), "q", [])
        self.assertEqual(out, "")

    def test_consumes_every_chunk(self) -> None:
        chunks = [f"chunk{i} " for i in range(20)]
        out = ask_mod._stream_answer(_FakeWorker(chunks), "q", [])
        self.assertEqual(out, "".join(chunks).strip())


if __name__ == "__main__":
    unittest.main()
