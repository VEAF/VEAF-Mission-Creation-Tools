"""Tests for the doc-chatbot worker — CHATBOT-CLI-003."""

from __future__ import annotations

import array
import unittest
from unittest import mock

from doc_chatbot import doc_chat_worker
from doc_chatbot.doc_chat_worker import DocChatWorker, MissingApiKeyError, _extract_text, resolve_api_key
from doc_chatbot.index_store import EMBED_DIMS, DocIndex


def _onehot(dim: int) -> list[float]:
    v = [0.0] * EMBED_DIMS
    v[dim] = 1.0
    return v


def _index(n: int) -> DocIndex:
    blob = array.array("f")
    for i in range(n):
        blob.extend(_onehot(i))
    texts = [{"text": f"text {i}", "title": f"T{i}", "path": f"p{i}"} for i in range(n)]
    return DocIndex(lang="fr", vectors=blob, texts=texts)


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


class TestResolveApiKey(unittest.TestCase):
    def test_explicit_wins(self) -> None:
        self.assertEqual(resolve_api_key("explicit"), "explicit")

    def test_env_used(self) -> None:
        with mock.patch.dict(doc_chat_worker.os.environ, {"GEMINI_API_KEY": "envkey"}, clear=False):
            self.assertEqual(resolve_api_key(None), "envkey")

    def test_config_fallback(self) -> None:
        with mock.patch.dict(doc_chat_worker.os.environ, {}, clear=True), mock.patch.object(
            doc_chat_worker.user_config, "get", return_value="cfgkey"
        ):
            self.assertEqual(resolve_api_key(None), "cfgkey")

    def test_missing_raises(self) -> None:
        with mock.patch.dict(doc_chat_worker.os.environ, {}, clear=True), mock.patch.object(
            doc_chat_worker.user_config, "get", return_value=None
        ):
            with self.assertRaises(MissingApiKeyError):
                resolve_api_key(None)


class TestRetrieve(unittest.TestCase):
    def _worker(self) -> DocChatWorker:
        worker = DocChatWorker(lang="fr", api_key="k")
        worker._index = _index(3)
        return worker

    def test_ranks_best_match_first(self) -> None:
        worker = self._worker()
        with mock.patch.object(worker, "_embed", return_value=_onehot(1)):
            passages = worker._retrieve("q", top_k=1)
        self.assertIn("# T1", passages)
        self.assertIn("text 1", passages)
        self.assertNotIn("text 0", passages)


class TestContents(unittest.TestCase):
    def test_trims_and_maps_roles(self) -> None:
        worker = DocChatWorker(lang="fr", api_key="k")
        history = [{"role": "user", "content": f"m{i}"} for i in range(20)]
        history.append({"role": "assistant", "content": "  "})  # empty → dropped
        contents = worker._contents("now", history)
        self.assertEqual(contents[-1], {"role": "user", "parts": [{"text": "now"}]})
        self.assertTrue(all(c["role"] in ("user", "model") for c in contents))
        self.assertTrue(all(c["parts"][0]["text"].strip() for c in contents))


class TestAskStreaming(unittest.TestCase):
    def test_streams_text_chunks(self) -> None:
        worker = DocChatWorker(lang="fr", api_key="k")
        lines = [
            'data: {"candidates":[{"content":{"parts":[{"text":"Hello "}]}}]}',
            "data: [DONE]",
            'data: {"candidates":[{"content":{"parts":[{"text":"world"}]}}]}',
        ]
        with mock.patch.object(worker, "_retrieve", return_value="ctx"), mock.patch.object(
            doc_chat_worker.requests, "post", return_value=_StreamResp(200, lines)
        ):
            out = "".join(worker.ask("q"))
        self.assertEqual(out, "Hello world")

    def test_gemini_error_raises(self) -> None:
        worker = DocChatWorker(lang="fr", api_key="k")
        with mock.patch.object(worker, "_retrieve", return_value="ctx"), mock.patch.object(
            doc_chat_worker.requests, "post", return_value=_StreamResp(429, [])
        ):
            with self.assertRaises(RuntimeError):
                list(worker.ask("q"))


class TestExtractText(unittest.TestCase):
    def test_extracts_parts(self) -> None:
        payload = '{"candidates":[{"content":{"parts":[{"text":"a"},{"text":"b"}]}}]}'
        self.assertEqual(list(_extract_text(payload)), ["a", "b"])

    def test_non_json_is_skipped(self) -> None:
        self.assertEqual(list(_extract_text("not json")), [])


if __name__ == "__main__":
    unittest.main()
