"""Tests for the doc-chatbot index store — CHATBOT-CLI-002."""

from __future__ import annotations

import array
import json
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import mock

from doc_chatbot import index_store
from doc_chatbot.index_store import EMBED_DIMS, fetch_index, load_index_from_files


def _vec_bytes(vectors: list[list[float]]) -> bytes:
    blob = array.array("f")
    for v in vectors:
        assert len(v) == EMBED_DIMS
        blob.extend(v)
    return blob.tobytes()


def _txt_bytes(lang: str, n: int) -> bytes:
    bulk = [
        {"key": f"idx:txt:{lang}:{i}", "value": json.dumps({"text": f"text {i}", "title": f"T{i}", "path": f"p{i}"})}
        for i in range(n)
    ]
    return json.dumps(bulk).encode("utf-8")


def _onehot(dim: int) -> list[float]:
    v = [0.0] * EMBED_DIMS
    v[dim] = 1.0
    return v


class _Resp:
    def __init__(self, status: int, content: bytes = b"", etag: str | None = None):
        self.status_code = status
        self.content = content
        self.headers = {"ETag": etag} if etag else {}


class TestLoadIndexFromFiles(unittest.TestCase):
    def test_loads_vectors_and_texts_in_order(self) -> None:
        with TemporaryDirectory() as td:
            base = Path(td)
            (base / "vec-fr.bin").write_bytes(_vec_bytes([_onehot(0), _onehot(1)]))
            (base / "txt-fr.json").write_bytes(_txt_bytes("fr", 2))
            idx = load_index_from_files(base / "vec-fr.bin", base / "txt-fr.json", "fr")
            self.assertEqual(idx.count, 2)
            self.assertEqual(len(idx.vectors), 2 * EMBED_DIMS)
            self.assertEqual(idx.texts[0]["text"], "text 0")

    def test_mismatch_raises(self) -> None:
        with TemporaryDirectory() as td:
            base = Path(td)
            (base / "vec-fr.bin").write_bytes(_vec_bytes([_onehot(0), _onehot(1)]))  # 2 vectors
            (base / "txt-fr.json").write_bytes(_txt_bytes("fr", 1))  # 1 text
            with self.assertRaises(ValueError):
                load_index_from_files(base / "vec-fr.bin", base / "txt-fr.json", "fr")

    def test_texts_reordered_by_index(self) -> None:
        with TemporaryDirectory() as td:
            base = Path(td)
            (base / "vec-fr.bin").write_bytes(_vec_bytes([_onehot(0), _onehot(1)]))
            bulk = [
                {"key": "idx:txt:fr:1", "value": json.dumps({"text": "second"})},
                {"key": "idx:txt:fr:0", "value": json.dumps({"text": "first"})},
            ]
            (base / "txt-fr.json").write_bytes(json.dumps(bulk).encode("utf-8"))
            idx = load_index_from_files(base / "vec-fr.bin", base / "txt-fr.json", "fr")
            self.assertEqual([t["text"] for t in idx.texts], ["first", "second"])


class TestFetchIndex(unittest.TestCase):
    def test_downloads_and_caches(self) -> None:
        with TemporaryDirectory() as td:
            cache = Path(td)
            responses = {
                "vec-fr.bin": _Resp(200, _vec_bytes([_onehot(0)]), etag='"v1"'),
                "txt-fr.json": _Resp(200, _txt_bytes("fr", 1), etag='"t1"'),
            }

            def fake_get(url, headers=None, timeout=None):
                return responses[url.rsplit("/", 1)[1]]

            with mock.patch.object(index_store.requests, "get", side_effect=fake_get):
                idx = fetch_index("fr", base_url="https://x", cache_dir=cache)
            self.assertEqual(idx.count, 1)
            self.assertTrue((cache / "vec-fr.bin").exists())
            self.assertTrue((cache / "txt-fr.json").exists())
            # ETag persisted for a future conditional request.
            etags = json.loads((cache / ".etag-fr.json").read_text(encoding="utf-8"))
            self.assertEqual(etags["vec-fr.bin"], '"v1"')

    def test_304_uses_cache(self) -> None:
        with TemporaryDirectory() as td:
            cache = Path(td)
            cache.mkdir(exist_ok=True)
            (cache / "vec-fr.bin").write_bytes(_vec_bytes([_onehot(0)]))
            (cache / "txt-fr.json").write_bytes(_txt_bytes("fr", 1))
            (cache / ".etag-fr.json").write_text(json.dumps({"vec-fr.bin": '"v1"', "txt-fr.json": '"t1"'}))

            with mock.patch.object(index_store.requests, "get", return_value=_Resp(304)):
                idx = fetch_index("fr", base_url="https://x", cache_dir=cache)
            self.assertEqual(idx.count, 1)

    def test_network_error_falls_back_to_cache(self) -> None:
        with TemporaryDirectory() as td:
            cache = Path(td)
            (cache / "vec-fr.bin").write_bytes(_vec_bytes([_onehot(0)]))
            (cache / "txt-fr.json").write_bytes(_txt_bytes("fr", 1))

            with mock.patch.object(
                index_store.requests, "get", side_effect=index_store.requests.RequestException("offline")
            ):
                idx = fetch_index("fr", base_url="https://x", cache_dir=cache)
            self.assertEqual(idx.count, 1)


if __name__ == "__main__":
    unittest.main()
