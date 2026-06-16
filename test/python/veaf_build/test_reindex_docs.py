"""Tests for the local docs-chatbot reindex command (veaf_build.reindex_docs)."""

from __future__ import annotations

import unittest

from veaf_build.reindex_docs import WORKER_DIR, kv_upload_commands


class TestReindexDocs(unittest.TestCase):
    def test_worker_dir_points_at_the_chatbot_worker(self) -> None:
        self.assertEqual(WORKER_DIR.parts[-3:], ("poc", "doc-chatbot", "worker"))

    def test_kv_upload_commands_cover_both_languages_and_artifacts(self) -> None:
        cmds = kv_upload_commands()
        # Two binary-vector uploads (kv key put) + two chunk-text uploads (kv bulk put).
        self.assertEqual(len(cmds), 4)
        joined = [" ".join(c) for c in cmds]
        self.assertTrue(any("idx:vec:fr" in c and "vec-fr.bin" in c for c in joined))
        self.assertTrue(any("idx:vec:en" in c and "vec-en.bin" in c for c in joined))
        self.assertTrue(any("bulk put" in c and "txt-fr.json" in c for c in joined))
        self.assertTrue(any("bulk put" in c and "txt-en.json" in c for c in joined))
        # All target the CHAT_KV namespace, against production (not preview).
        for c in joined:
            self.assertIn("--binding CHAT_KV", c)
            self.assertIn("--preview false", c)


if __name__ == "__main__":
    unittest.main()
