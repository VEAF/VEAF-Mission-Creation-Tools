"""Tests for the local docs-chatbot reindex command (veaf_build.reindex_docs)."""

from __future__ import annotations

import unittest

from veaf_build.reindex_docs import (
    WORKER_DIR,
    kv_readback_commands,
    kv_upload_commands,
    verify_command,
)


class TestReindexDocs(unittest.TestCase):
    def test_worker_dir_points_at_the_chatbot_worker(self) -> None:
        self.assertEqual(WORKER_DIR.parts[-3:], ("poc", "doc-chatbot", "worker"))

    def test_kv_upload_commands_cover_both_languages_and_artifacts(self) -> None:
        cmds = kv_upload_commands()
        # Two keys per language — the vector blob and the passage texts — and no more. The count is
        # spent against a 1000/day account-wide cap, so it must not grow with the documentation.
        self.assertEqual(len(cmds), 4)
        joined = [" ".join(c) for c in cmds]
        for lang in ("fr", "en"):
            self.assertTrue(any(f"idx:vec:{lang}" in c and f"vec-{lang}.bin" in c for c in joined))
            self.assertTrue(any(f"idx:txt:{lang}" in c and f"txt-{lang}.json" in c for c in joined))
        for c in joined:
            self.assertIn("--binding CHAT_KV", c)
            self.assertIn("--preview false", c)
            # Without --remote, wrangler 4 writes to its local store and still prints Success!.
            # This command shipped without the flag from the wrangler 4 bump until 2026-09-21, so
            # every hand-run reindex in between uploaded nothing while reporting success.
            self.assertIn("--remote", c)
            self.assertNotIn("bulk", c, "a per-chunk bulk upload is what blew the write quota")

    def test_the_index_is_read_back_out_of_the_remote_namespace(self) -> None:
        readbacks = kv_readback_commands()
        self.assertEqual(len(readbacks), len(kv_upload_commands()), "every uploaded value is checked")
        for cmd, destination in readbacks:
            joined = " ".join(cmd)
            self.assertIn("key get", joined)
            self.assertIn("--remote", joined, "reading the local store would prove nothing")
            self.assertTrue(destination.startswith("remote-"))

    def test_every_uploaded_key_is_compared_with_what_was_built(self) -> None:
        cmd = verify_command()
        self.assertEqual(cmd[:2], ["node", "scripts/verify-index-upload.mjs"])
        joined = " ".join(cmd)
        # Each read-back file named by kv_readback_commands must appear in the comparison, and each
        # comparison must name the local file the build produced.
        for _, destination in kv_readback_commands():
            self.assertIn(destination, joined)
            self.assertIn(destination.removeprefix("remote-"), joined)


if __name__ == "__main__":
    unittest.main()
