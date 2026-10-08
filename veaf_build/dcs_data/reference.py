"""Fetch the ``dcs-world-schema`` reference database at a pinned release.

Since ``v0.4.0``, ``YoloWingPixie/dcs-world-schema`` attaches to each release a SQLite database
read from DCS itself: airbases, beacons, liveries, callsigns, sensors, weapons... Providers that
read it are as reproducible as the datamine ones: the asset is pinned by release **and** by
SHA-256, so a re-published asset fails loudly instead of changing a committed artifact.

The repository also carries the same records as JSON, but some file names exceed the Windows
path limit once checked out; the single SQLite asset has no such problem.

To pick up newer DCS data, bump :data:`REFERENCE_TAG`, :data:`REFERENCE_ASSET` and
:data:`REFERENCE_SHA256` together, re-run ``veaf-build update-dcs-data`` and commit the diff.
"""

from __future__ import annotations

import hashlib
import sqlite3
import tempfile
from collections.abc import Callable, Iterator
from contextlib import contextmanager
from pathlib import Path

import requests

REFERENCE_TAG = "v0.5.0"
"""Pinned ``dcs-world-schema`` release."""

REFERENCE_ASSET = "dcs-world-reference-0.5.0-dcs2.9.30.28536.sqlite"
"""The release's SQLite asset (its name carries the DCS version it was read from)."""

REFERENCE_SHA256 = "934ef175c09e8237a526b76ee86830e43e4f5cefc32e0d4591b2c8fa0cca5dee"
"""SHA-256 of :data:`REFERENCE_ASSET`, as GitHub publishes it in the asset's ``digest``."""

REFERENCE_URL = f"https://github.com/YoloWingPixie/dcs-world-schema/releases/download/{REFERENCE_TAG}/{REFERENCE_ASSET}"

_TIMEOUT_SECONDS = 120


def _http_get(url: str) -> bytes:
    """Download *url* and return its body.

    Args:
        url: The address to fetch.

    Returns:
        The response body.

    Raises:
        requests.HTTPError: If the server answers with an error status.
    """
    response = requests.get(url, timeout=_TIMEOUT_SECONDS)
    response.raise_for_status()
    return response.content


def download_reference(
    dest: Path,
    url: str = REFERENCE_URL,
    sha256: str = REFERENCE_SHA256,
    fetch: Callable[[str], bytes] = _http_get,
) -> Path:
    """Download the reference database into *dest* and check its SHA-256.

    Args:
        dest: Directory to write the database into (created if missing).
        url: Where to fetch it. Defaults to the pinned :data:`REFERENCE_URL`.
        sha256: The expected digest. Defaults to the pinned :data:`REFERENCE_SHA256`.
        fetch: Returns the bytes at a URL; replaced in tests.

    Returns:
        The path of the downloaded database.

    Raises:
        RuntimeError: If the downloaded bytes do not have the expected digest.
    """
    body = fetch(url)
    digest = hashlib.sha256(body).hexdigest()
    if digest != sha256:
        raise RuntimeError(
            f"The reference database at {url} has SHA-256 {digest}, expected {sha256}: "
            "the asset changed upstream; check it and bump REFERENCE_SHA256 deliberately."
        )
    dest.mkdir(parents=True, exist_ok=True)
    path = dest / url.rsplit("/", 1)[-1]
    path.write_bytes(body)
    return path


@contextmanager
def open_reference() -> Iterator[sqlite3.Connection]:
    """Download the pinned reference database and open it read-only.

    Yields:
        A connection to the database; the file is deleted when the context exits.
    """
    with tempfile.TemporaryDirectory() as tmp:
        path = download_reference(Path(tmp))
        connection = sqlite3.connect(f"file:{path.as_posix()}?mode=ro", uri=True)
        try:
            yield connection
        finally:
            connection.close()
