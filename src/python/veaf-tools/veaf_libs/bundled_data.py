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


def bundled_dir(package: str, *parts: str) -> Path:
    """Return the filesystem path of a packaged data **directory**.

    Same resolution as :func:`read_bundled_text`, for callers that must enumerate a
    directory rather than read one known file (e.g. the shipped checklist catalogue,
    whose contents are not known in advance).

    Args:
        package: Top-level package the directory ships under (e.g. ``"veaf_libs"``).
        *parts: Path components under the package (e.g. ``"data"``, ``"checklists"``).

    Returns:
        The directory path. It may not exist — callers decide whether an absent
        directory is an error or simply "nothing shipped".
    """
    bundle_path = Path(getattr(sys, "_MEIPASS", "")) / package / Path(*parts)
    if bundle_path.is_dir():
        return bundle_path
    resource = importlib.resources.files(package)
    for part in parts:
        resource = resource / part
    return Path(str(resource))
