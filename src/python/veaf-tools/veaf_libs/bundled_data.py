"""Read package data files in both source and PyInstaller-bundled runs.

PyInstaller extracts ``--add-data`` files under ``sys._MEIPASS`` keyed by their
declared destination, while a source/editable install keeps them inside the
package directory. This helper resolves either case so callers do not each
reimplement the lookup.
"""

from __future__ import annotations

import importlib.resources
import sys
from pathlib import Path


def read_bundled_text(package: str, *parts: str) -> str:
    """Read a packaged data file as UTF-8 text.

    Args:
        package: Top-level package the data ships under (e.g. ``"veaf_libs"``).
        *parts: Path components under the package (e.g. ``"data"``, ``"x.yaml"``).

    Returns:
        The file contents.
    """
    bundle_path = Path(getattr(sys, "_MEIPASS", "")) / package / Path(*parts)
    if bundle_path.exists():
        return bundle_path.read_text(encoding="utf-8")
    resource = importlib.resources.files(package)
    for part in parts:
        resource = resource / part
    return resource.read_text(encoding="utf-8")
