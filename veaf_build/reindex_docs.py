"""
Rebuild the documentation chatbot embeddings index locally and upload it to Cloudflare KV.

Same work as the ``Rebuild docs chatbot index`` GitHub workflow, but run by hand. Useful when:
  - the CI workflow is temporarily disabled (e.g. during a large doc pass like DOC-REVIEW,
    to avoid hammering the Gemini free-tier embeddings quota on every push), or
  - you simply want to refresh the index on demand.

The local content-addressed cache (``poc/doc-chatbot/worker/.embed-cache.json``) persists on
disk, so only new/changed chunks are re-embedded — incremental re-indexing is effectively free
and stays well under the 1000/day free-tier cap.

Steps:
  1. ``node scripts/build-index.mjs`` — chunk ``doc/**``, embed changed chunks (Gemini), and
     write ``vec-{fr,en}.bin`` + ``txt-{fr,en}.json``.
  2. ``npx wrangler kv … put`` — upload the 4 index artifacts to the ``CHAT_KV`` namespace.

Environment:
  - ``GEMINI_API_KEY``                            — embeddings (build step); falls back to ``.dev.vars``.
  - ``CLOUDFLARE_API_TOKEN`` / ``CLOUDFLARE_ACCOUNT_ID`` — KV upload (upload step).

Usage:
    poetry run reindex-docs                 # build + upload
    poetry run reindex-docs --skip-upload   # build only (inspect vec-*.bin / txt-*.json locally)
    poetry run reindex-docs --skip-build    # upload an already-built index only
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

WORKER_DIR = Path(__file__).parent.parent / "poc" / "doc-chatbot" / "worker"


def kv_upload_commands() -> list[list[str]]:
    """Return the wrangler commands (as arg lists) that upload the built index to ``CHAT_KV``.

    Returns:
        Four command arg lists — two ``kv key put`` (binary vectors) and two ``kv bulk put``
        (chunk texts), one pair per language — run with ``WORKER_DIR`` as the working directory.
    """
    base = ["npx", "wrangler", "kv"]
    common = ["--binding", "CHAT_KV", "--preview", "false"]
    return [
        base + ["key", "put", *common, "idx:vec:fr", "--path", "vec-fr.bin"],
        base + ["key", "put", *common, "idx:vec:en", "--path", "vec-en.bin"],
        base + ["bulk", "put", *common, "txt-fr.json"],
        base + ["bulk", "put", *common, "txt-en.json"],
    ]


def _resolve(binary: str) -> str:
    """Resolve a binary on PATH (handles the ``.cmd`` shims for ``node``/``npx`` on Windows)."""
    path = shutil.which(binary)
    if not path:
        sys.exit(f"'{binary}' not found on PATH — install Node.js (node + npx) to (re)build the index.")
    return path


def _run(cmd: list[str]) -> None:
    """Run a command from ``WORKER_DIR``, resolving its executable on PATH first."""
    full = [_resolve(cmd[0]), *cmd[1:]]
    print(f"$ {' '.join(cmd)}")
    subprocess.run(full, cwd=WORKER_DIR, check=True)


def main() -> None:
    """Build the docs chatbot embeddings index locally and upload it to Cloudflare KV."""
    parser = argparse.ArgumentParser(
        description="Rebuild the docs chatbot index locally and upload it to Cloudflare KV."
    )
    parser.add_argument(
        "--skip-upload", action="store_true", help="Only build the index (vec-*.bin / txt-*.json); do not upload to KV."
    )
    parser.add_argument(
        "--skip-build", action="store_true", help="Only upload the already-built index; skip the embedding build."
    )
    args = parser.parse_args()

    if not WORKER_DIR.is_dir():
        sys.exit(f"worker directory not found: {WORKER_DIR}")

    if not args.skip_build:
        print("Building the docs chatbot embeddings index (node scripts/build-index.mjs)...")
        _run(["node", "scripts/build-index.mjs"])

    if not args.skip_upload:
        print("Uploading the index to Cloudflare KV (CHAT_KV)...")
        for cmd in kv_upload_commands():
            _run(cmd)

    print("Done.")


if __name__ == "__main__":
    main()
