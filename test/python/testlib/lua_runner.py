"""Run a Lua chunk under the repository's Lua 5.1 interpreter, from a Python test.

Some defects only show when generated Lua **runs**: a reference evaluated at load time, an
error that stops the rest of a file. Checking the text cannot see them, and ``lupa`` is gone
(CLEANUP-LUPA), so these tests hand the chunk to the same interpreter ``poetry run test-lua``
uses.

Without an interpreter the test is skipped locally, but **fails in CI**: a skipped test and a
passing one look the same in a summary line, and the Python CI job installs ``lua5.1`` so that
these tests actually run there.
"""

from __future__ import annotations

import os
import subprocess
import tempfile
from pathlib import Path

import pytest

from veaf_build.lua_tests import _find_lua


def run_lua(source: str) -> subprocess.CompletedProcess[str]:
    """Execute *source* as a Lua 5.1 chunk and return the finished process.

    Args:
        source: The Lua source to run.

    Returns:
        The completed process, with ``stdout`` / ``stderr`` as text.
    """
    try:
        lua = _find_lua()
    except Exception as exc:  # typer.BadParameter when no 5.1 interpreter is installed
        if os.environ.get("CI"):
            pytest.fail(f"no Lua 5.1 interpreter in CI: {exc}")
        pytest.skip(f"no Lua 5.1 interpreter: {exc}")
    with tempfile.NamedTemporaryFile("w", suffix=".lua", encoding="utf-8", delete=False) as handle:
        handle.write(source)
        path = Path(handle.name)
    try:
        return subprocess.run([lua, str(path)], capture_output=True, text=True, timeout=30, check=False)
    finally:
        path.unlink(missing_ok=True)
