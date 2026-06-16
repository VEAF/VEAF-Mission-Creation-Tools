"""`_version.py` is generated with LF line endings (FIX-VERSION-PY-EOL).

On Windows, `Path.write_text` in text mode translates ``\n`` to ``\r\n``, which
left the git-tracked stub (`.gitattributes` forces ``eol=lf``) permanently
"modified" after every build. `_write_version_py` / `_restore_version_py` now
pass ``newline="\n"`` so the file stays LF on every platform.
"""

from __future__ import annotations

from pathlib import Path

from veaf_build.worker import _VERSION_PY_STUB, BuildAndReleaseWorker


def _worker(tmp_path: Path) -> BuildAndReleaseWorker:
    return BuildAndReleaseWorker(output_path=tmp_path)


def test_write_version_py_uses_lf(tmp_path: Path) -> None:
    worker = _worker(tmp_path)
    worker.version = "6.5.0"
    path = tmp_path / "_version.py"

    worker._write_version_py(path)

    raw = path.read_bytes()
    assert b"\r\n" not in raw
    assert b'__version__ = "6.5.0"' in raw


def test_restore_version_py_uses_lf(tmp_path: Path) -> None:
    worker = _worker(tmp_path)
    path = tmp_path / "_version.py"

    worker._restore_version_py(path)

    raw = path.read_bytes()
    assert b"\r\n" not in raw
    assert path.read_text(encoding="utf-8") == _VERSION_PY_STUB
