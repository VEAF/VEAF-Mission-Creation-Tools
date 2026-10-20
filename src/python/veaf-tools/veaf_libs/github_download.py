"""Download a GitHub release asset, refusing any hop off GitHub and any answer over a cap.

Moved out of ``veaf-tools-updater.py`` (FEAT-TERRAIN-DATA-DOWNLOAD) so the terrain download uses the
same checks as the updater rather than a second copy of them: the updater installs and runs what it
downloads (SECREV-2 / VMR-037), and the terrain download writes what it gets into the VEAF home.
"""

from __future__ import annotations

from typing import Any
from urllib.parse import urljoin, urlparse

import requests

#: Hosts a release asset may legitimately come from (SECREV-2 / VMR-037). GitHub serves
#: `browser_download_url` from github.com and redirects to its object storage; both are named so a
#: redirect chain that leaves GitHub entirely is refused.
TRUSTED_DOWNLOAD_HOSTS = frozenset({"github.com", "www.github.com", "api.github.com"})
TRUSTED_DOWNLOAD_HOST_SUFFIX = ".githubusercontent.com"

#: How many redirects to follow while checking each hop. GitHub uses one (asset -> object storage);
#: a few more costs nothing and a bounded walk cannot loop.
MAX_DOWNLOAD_REDIRECTS = 5


class GithubDownloadError(Exception):
    """A download refused or failed.

    Args:
        kind: ``untrusted_url``, ``too_many_redirects``, ``http_status`` or ``too_large``.
        url: The URL concerned — the refused hop for ``untrusted_url``, else the one asked for.
        size: For ``too_large``, the size declared or read so far.
        response: For ``http_status``, the answer, so a caller can tell a rate limit from the rest.
    """

    def __init__(self, kind: str, url: str, *, size: int = 0, response: Any = None) -> None:
        super().__init__(f"{kind}: {url}")
        self.kind = kind
        self.url = url
        self.size = size
        self.response = response


def is_trusted_download_url(url: str | None) -> bool:
    """Whether *url* is an https URL on a GitHub host we are willing to download from.

    Args:
        url: The candidate URL (may be missing).

    Returns:
        True when the URL uses https and its host is GitHub's.
    """
    if not url:
        return False
    parsed = urlparse(url)
    if parsed.scheme != "https":
        return False
    host = (parsed.hostname or "").lower()
    return host in TRUSTED_DOWNLOAD_HOSTS or host.endswith(TRUSTED_DOWNLOAD_HOST_SUFFIX)


def fetch_github_asset(
    url: str, *, max_bytes: int, headers: dict[str, str] | None = None, timeout: float | None = None
) -> bytes:
    """Download a release asset, walking the redirect chain one checked hop at a time.

    ``requests`` follows redirects to any host by default, and GitHub does redirect release assets to
    its object storage, so each hop is checked here; the ``Authorization`` header is dropped when a
    hop changes host, as ``requests`` would have done.

    Args:
        url: The asset URL.
        max_bytes: Refuse an answer longer than this — declared, or counted while it is read, since a
            reply may declare nothing and never end.
        headers: Request headers (a GitHub token stays on the first host only).
        timeout: Seconds before giving up on a connection or a read; ``None`` waits as ``requests`` does.

    Returns:
        The asset's bytes.

    Raises:
        GithubDownloadError: On a hop off GitHub, too many redirects, an error status or an oversize.
        requests.RequestException: On a network failure.
    """
    current = url
    origin_host = (urlparse(url or "").hostname or "").lower()
    extra: dict[str, Any] = {} if timeout is None else {"timeout": timeout}
    for _ in range(MAX_DOWNLOAD_REDIRECTS + 1):
        if not is_trusted_download_url(current):
            raise GithubDownloadError("untrusted_url", current)
        hop_headers = dict(headers or {})
        if (urlparse(current).hostname or "").lower() != origin_host:
            hop_headers.pop("Authorization", None)
        # `stream=True` so the body is not pulled into memory before its size is known.
        response = requests.get(current, headers=hop_headers, allow_redirects=False, stream=True, **extra)
        if not response.is_redirect and not response.is_permanent_redirect:
            break
        # A Location may be relative, so resolve it against the URL that produced it.
        current = urljoin(current, response.headers.get("Location", ""))
    else:
        raise GithubDownloadError("too_many_redirects", url)

    if response.status_code != 200:
        raise GithubDownloadError("http_status", url, response=response)
    return _read_capped(response, url, max_bytes)


def _read_capped(response: Any, url: str, max_bytes: int) -> bytes:
    """Read a streaming answer, refusing anything past ``max_bytes``.

    Args:
        response: The answer — only ``headers``, ``iter_content`` and ``close`` are used.
        url: The URL, for the error.
        max_bytes: The cap.

    Returns:
        The body.

    Raises:
        GithubDownloadError: ``too_large``, on the declared length or on the bytes read.
    """
    declared = response.headers.get("Content-Length")
    if declared and declared.isdigit() and int(declared) > max_bytes:
        raise GithubDownloadError("too_large", url, size=int(declared))
    chunks: list[bytes] = []
    total = 0
    for chunk in response.iter_content(chunk_size=64 * 1024):
        if not chunk:
            continue
        total += len(chunk)
        if total > max_bytes:
            response.close()
            raise GithubDownloadError("too_large", url, size=total)
        chunks.append(chunk)
    return b"".join(chunks)
