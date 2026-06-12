"""Download and cache the documentation chatbot embeddings index (CHATBOT-CLI-002).

The docs CI publishes the index as GitHub Release assets (rolling ``doc-index`` tag):

* ``vec-{lang}.bin``  — a binary little-endian Float32 blob of ``N × EMBED_DIMS``
  L2-normalized vectors (the same blob the Cloudflare Worker loads from KV).
* ``txt-{lang}.json`` — a ``wrangler kv bulk put`` file: a list of
  ``{"key": "idx:txt:{lang}:{i}", "value": "<json>"}`` where ``value`` is a JSON
  string ``{"text", "title", "path"}`` and ``i`` matches the blob order.

This module downloads both into ``~/.veaf/doc-index/`` with an ETag conditional
request (so an unchanged index is not re-downloaded) and exposes the vectors and
texts for in-process cosine retrieval. When the network is unavailable it falls
back to a previously cached copy.
"""

from __future__ import annotations

import array
import json
import sys
from dataclasses import dataclass
from pathlib import Path

import requests
from veaf_libs.i18n import t
from veaf_libs.logger import logger

#: Embedding dimensionality — must match the index built by ``build-index.mjs``.
EMBED_DIMS = 768

#: Public base URL of the published index (GitHub Release rolling ``doc-index`` tag).
DEFAULT_INDEX_BASE_URL = "https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases/download/doc-index"

#: Local cache directory for the downloaded index files.
DEFAULT_CACHE_DIR = Path.home() / ".veaf" / "doc-index"

_DOWNLOAD_TIMEOUT = 30


@dataclass
class DocIndex:
    """A language-scoped documentation index ready for cosine retrieval.

    Attributes:
        lang: The language code (``"fr"`` / ``"en"``).
        vectors: Flat ``array('f')`` of ``count * EMBED_DIMS`` L2-normalized floats.
        texts: Per-chunk dicts ``{"text", "title", "path"}`` in blob order.
    """

    lang: str
    vectors: array.array
    texts: list[dict[str, str]]

    @property
    def count(self) -> int:
        """Number of indexed chunks."""
        return len(self.texts)


def _cache_paths(lang: str, cache_dir: Path) -> tuple[Path, Path, Path]:
    """Return the (vector, text, etag) cache paths for a language."""
    return (
        cache_dir / f"vec-{lang}.bin",
        cache_dir / f"txt-{lang}.json",
        cache_dir / f".etag-{lang}.json",
    )


def _load_etags(etag_path: Path) -> dict[str, str]:
    """Load the stored ETags ({filename: etag}); empty when none cached yet."""
    try:
        return json.loads(etag_path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def _download_file(url: str, dest: Path, etags: dict[str, str]) -> None:
    """Download ``url`` to ``dest`` unless the server reports it unchanged (304).

    Uses a conditional ``If-None-Match`` request keyed by the destination name so
    an unchanged asset is not re-fetched. On a network error an existing cached
    copy is kept (and reused); only a missing file with no cache is fatal.

    Args:
        url: The remote asset URL.
        dest: The local cache destination.
        etags: Mutable {filename: etag} map, updated in place on a fresh download.

    Raises:
        FileNotFoundError: The asset could not be downloaded and no cache exists.
    """
    headers = {}
    cached_etag = etags.get(dest.name)
    if cached_etag and dest.exists():
        headers["If-None-Match"] = cached_etag
    try:
        resp = requests.get(url, headers=headers, timeout=_DOWNLOAD_TIMEOUT)
    except requests.RequestException as exc:
        if dest.exists():
            logger.warning(t("chatbot.index_refresh_failed", file=dest.name, reason=str(exc)))
            return
        raise FileNotFoundError(f"Cannot download {url}: {exc}") from exc

    if resp.status_code == 304 and dest.exists():
        logger.debug(f"{dest.name} is up to date (304)")
        return
    if resp.status_code != 200:
        if dest.exists():
            logger.warning(t("chatbot.index_refresh_failed", file=dest.name, reason=f"HTTP {resp.status_code}"))
            return
        raise FileNotFoundError(f"Cannot download {url}: HTTP {resp.status_code}")

    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(resp.content)
    new_etag = resp.headers.get("ETag")
    if new_etag:
        etags[dest.name] = new_etag


def _read_vectors(vec_path: Path) -> array.array:
    """Read a little-endian Float32 blob into a native ``array('f')``."""
    vectors = array.array("f")
    vectors.frombytes(vec_path.read_bytes())
    if sys.byteorder == "big":
        vectors.byteswap()
    return vectors


def _read_texts(txt_path: Path, lang: str) -> list[dict[str, str]]:
    """Parse the ``txt-{lang}.json`` bulk file into a blob-ordered list of dicts."""
    raw = json.loads(txt_path.read_text(encoding="utf-8"))
    prefix = f"idx:txt:{lang}:"
    by_index: dict[int, dict[str, str]] = {}
    for entry in raw:
        key = entry.get("key", "")
        if not key.startswith(prefix):
            continue
        try:
            idx = int(key[len(prefix) :])
        except ValueError:
            continue
        value = entry.get("value")
        by_index[idx] = json.loads(value) if isinstance(value, str) else value
    return [by_index[i] for i in sorted(by_index)]


def load_index_from_files(vec_path: Path, txt_path: Path, lang: str) -> DocIndex:
    """Load a :class:`DocIndex` from already-downloaded cache files.

    Args:
        vec_path: Path to ``vec-{lang}.bin``.
        txt_path: Path to ``txt-{lang}.json``.
        lang: Language code.

    Returns:
        The loaded index.

    Raises:
        ValueError: The vector blob length is inconsistent with the texts count.
    """
    vectors = _read_vectors(vec_path)
    texts = _read_texts(txt_path, lang)
    if len(vectors) != len(texts) * EMBED_DIMS:
        raise ValueError(f"Index mismatch for '{lang}': {len(vectors)} floats vs {len(texts)} texts × {EMBED_DIMS}")
    return DocIndex(lang=lang, vectors=vectors, texts=texts)


def fetch_index(
    lang: str,
    base_url: str = DEFAULT_INDEX_BASE_URL,
    cache_dir: Path = DEFAULT_CACHE_DIR,
) -> DocIndex:
    """Download (if changed) and load the documentation index for a language.

    Args:
        lang: Language code (``"fr"`` / ``"en"``).
        base_url: Base URL the ``vec-`` / ``txt-`` assets are published under.
        cache_dir: Local cache directory.

    Returns:
        The loaded :class:`DocIndex`.
    """
    vec_path, txt_path, etag_path = _cache_paths(lang, cache_dir)
    etags = _load_etags(etag_path)
    _download_file(f"{base_url}/vec-{lang}.bin", vec_path, etags)
    _download_file(f"{base_url}/txt-{lang}.json", txt_path, etags)
    try:
        etag_path.parent.mkdir(parents=True, exist_ok=True)
        etag_path.write_text(json.dumps(etags), encoding="utf-8")
    except OSError:
        pass
    return load_index_from_files(vec_path, txt_path, lang)
