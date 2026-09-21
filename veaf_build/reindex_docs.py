"""
Rebuild the documentation chatbot embeddings index locally and upload it to Cloudflare KV.

Same work as the ``Rebuild docs chatbot index`` GitHub workflow, but run by hand. Useful when:
  - the CI workflow is temporarily disabled (e.g. during a large doc pass like DOC-REVIEW,
    to avoid hammering the Gemini free-tier embeddings quota on every push), or
  - you simply want to refresh the index on demand.

Two free-tier quotas of 1000/day sit on a rebuild, not one:
  - Gemini embeddings. Guarded by the local content-addressed cache
    (``poc/doc-chatbot/worker/.embed-cache.json``), which persists on disk, so only new or changed
    chunks are re-embedded.
  - Cloudflare KV writes, account-wide, and shared with the Worker's own rate-limit counters.
    Guarded by the index layout: two keys per language, so an upload is four writes whatever
    changed. It used to be one key per chunk — 1397 writes, measured 2026-09-21.

Steps:
  1. ``node scripts/build-index.mjs`` — chunk ``doc/**``, embed changed chunks (Gemini), and
     write ``vec-{fr,en}.bin`` + ``txt-{fr,en}.json``.
  2. ``npx wrangler kv key put --remote`` — upload the 4 index values to the ``CHAT_KV`` namespace.
  3. Read all four back out of the namespace and compare them byte for byte. Without that, a green
     run means nothing: ``kv key put`` without ``--remote`` writes to wrangler's local store and
     still prints ``Success!``, which is how the live index sat frozen for six weeks in 2026. This
     command was missing ``--remote`` until 2026-09-21 — the workflow was fixed and this path was
     not, so every hand-run reindex since the wrangler 4 bump uploaded nothing.

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


LANGUAGES = ("fr", "en")

#: ``--remote`` is load-bearing: without it wrangler 4 writes to its local Miniflare store and
#: still prints ``Success!``. ``--preview false`` picks the production namespace over the preview
#: one; the two are unrelated and both are needed.
_KV_COMMON = ["--remote", "--binding", "CHAT_KV", "--preview", "false"]


def kv_upload_commands() -> list[list[str]]:
    """Return the wrangler commands (as arg lists) that upload the built index to ``CHAT_KV``.

    Returns:
        Four command arg lists — ``idx:vec:{lang}`` and ``idx:txt:{lang}`` per language, all
        ``kv key put`` — run with ``WORKER_DIR`` as the working directory. Four, and that count
        must not grow with the documentation: it is spent against a 1000/day account-wide cap.
    """
    base = ["npx", "wrangler", "kv", "key", "put", *_KV_COMMON]
    return [base + [f"idx:vec:{lang}", "--path", f"vec-{lang}.bin"] for lang in LANGUAGES] + [
        base + [f"idx:txt:{lang}", "--path", f"txt-{lang}.json"] for lang in LANGUAGES
    ]


def kv_readback_commands() -> list[tuple[list[str], str]]:
    """Return the ``kv key get`` commands that read the uploaded index back, with their outputs.

    Returns:
        One ``(command, destination file)`` pair per uploaded value. ``kv key get`` writes the raw
        value to stdout with no banner, so redirecting it into a file yields the stored bytes —
        except for a missing key, which prints ``Value not found`` and **exits 0**, which is why
        the comparison afterwards is a byte comparison and not an exit-code check.
    """
    base = ["npx", "wrangler", "kv", "key", "get", *_KV_COMMON]
    return [(base + [f"idx:vec:{lang}"], f"remote-vec-{lang}.bin") for lang in LANGUAGES] + [
        (base + [f"idx:txt:{lang}"], f"remote-txt-{lang}.json") for lang in LANGUAGES
    ]


def verify_command() -> list[str]:
    """Return the command comparing every read-back value with what the build produced."""
    cmd = ["node", "scripts/verify-index-upload.mjs"]
    for lang in LANGUAGES:
        cmd += ["--vec", lang, f"vec-{lang}.bin", f"remote-vec-{lang}.bin"]
    for lang in LANGUAGES:
        cmd += ["--txt", lang, f"txt-{lang}.json", f"remote-txt-{lang}.json"]
    return cmd


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


def _run_to_file(cmd: list[str], destination: str) -> None:
    """Run a command from ``WORKER_DIR``, writing its stdout to a file inside that directory."""
    full = [_resolve(cmd[0]), *cmd[1:]]
    print(f"$ {' '.join(cmd)} > {destination}")
    with (WORKER_DIR / destination).open("wb") as out:
        subprocess.run(full, cwd=WORKER_DIR, check=True, stdout=out)


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
        upload = kv_upload_commands()
        print(f"Uploading the index to Cloudflare KV (CHAT_KV) — {len(upload)} writes...")
        for cmd in upload:
            _run(cmd)

        # A green upload proves nothing on its own: see the module docstring.
        print("Reading the index back out of the namespace...")
        for cmd, destination in kv_readback_commands():
            _run_to_file(cmd, destination)
        _run(verify_command())

    print("Done.")


if __name__ == "__main__":
    main()
