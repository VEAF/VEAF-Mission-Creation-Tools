"""Downloads from GitHub refuse any hop off GitHub and any answer over a cap (FEAT-TERRAIN-DATA-DOWNLOAD).

The updater's own tests (`test_updater_download_url.py`) still guard it through `download_asset`; these
guard what the terrain download uses directly.
"""

from __future__ import annotations

import pytest
import requests
from veaf_libs import github_download
from veaf_libs.github_download import GithubDownloadError, fetch_github_asset, is_trusted_download_url

ASSET = "https://github.com/VEAF/repo/releases/download/terrain-data/Syria.terrain"


class _Response:
    def __init__(self, status: int, *, location: str = "", content: bytes = b"", declared: int | None = None):
        self.status_code = status
        self.reason = "Found" if status in (301, 302) else "OK"
        self.headers = {"Location": location} if location else {}
        if declared is not None:
            self.headers["Content-Length"] = str(declared)
        self._content = content
        self.is_redirect = status in (302, 303, 307)
        self.is_permanent_redirect = status in (301, 308)

    def iter_content(self, chunk_size: int):  # noqa: ANN201
        for i in range(0, len(self._content), chunk_size):
            yield self._content[i : i + chunk_size]

    def close(self) -> None:
        pass


def _serve(monkeypatch: pytest.MonkeyPatch, responses: list[_Response]) -> list[tuple[str, dict]]:
    calls: list[tuple[str, dict]] = []
    queued = list(responses)

    def fake_get(url: str, **kwargs):  # noqa: ANN202, ANN003
        calls.append((url, dict(kwargs.get("headers") or {})))
        return queued.pop(0)

    monkeypatch.setattr(requests, "get", fake_get)
    return calls


def test_the_trusted_hosts_are_github_s_over_https() -> None:
    assert is_trusted_download_url(ASSET)
    assert is_trusted_download_url("https://objects.githubusercontent.com/x")
    assert not is_trusted_download_url("http://github.com/x")
    assert not is_trusted_download_url("https://notgithubusercontent.com/x")
    assert not is_trusted_download_url(None)


def test_the_github_redirect_is_followed_without_the_token(monkeypatch: pytest.MonkeyPatch) -> None:
    calls = _serve(
        monkeypatch,
        [_Response(302, location="https://objects.githubusercontent.com/1"), _Response(200, content=b"grid")],
    )

    assert fetch_github_asset(ASSET, headers={"Authorization": "token t"}, max_bytes=100) == b"grid"
    assert "Authorization" in calls[0][1]
    assert "Authorization" not in calls[1][1]


def test_a_hop_off_github_is_never_requested(monkeypatch: pytest.MonkeyPatch) -> None:
    calls = _serve(monkeypatch, [_Response(302, location="https://evil.example.com/x")])

    with pytest.raises(GithubDownloadError) as refused:
        fetch_github_asset(ASSET, max_bytes=100)

    assert refused.value.kind == "untrusted_url"
    assert [url for url, _ in calls] == [ASSET]


def test_an_endless_redirect_chain_gives_up(monkeypatch: pytest.MonkeyPatch) -> None:
    calls = _serve(monkeypatch, [_Response(302, location=ASSET) for _ in range(20)])

    with pytest.raises(GithubDownloadError) as refused:
        fetch_github_asset(ASSET, max_bytes=100)

    assert refused.value.kind == "too_many_redirects"
    assert len(calls) == github_download.MAX_DOWNLOAD_REDIRECTS + 1


def test_an_error_status_carries_the_response(monkeypatch: pytest.MonkeyPatch) -> None:
    _serve(monkeypatch, [_Response(404)])

    with pytest.raises(GithubDownloadError) as refused:
        fetch_github_asset(ASSET, max_bytes=100)

    assert refused.value.kind == "http_status"
    assert refused.value.response is not None and refused.value.response.status_code == 404


@pytest.mark.parametrize(
    ("response", "accepted"),
    [
        (_Response(200, content=b"x" * 100), True),
        (_Response(200, content=b"x" * 101), False),
        (_Response(200, content=b"x", declared=10_000), False),
    ],
    ids=["exactly-the-cap", "one-byte-over", "declared-over"],
)
def test_the_answer_is_capped(monkeypatch: pytest.MonkeyPatch, response: _Response, accepted: bool) -> None:
    _serve(monkeypatch, [response])

    if accepted:
        assert fetch_github_asset(ASSET, max_bytes=100) == b"x" * 100
    else:
        with pytest.raises(GithubDownloadError) as refused:
            fetch_github_asset(ASSET, max_bytes=100)
        assert refused.value.kind == "too_large"


def test_a_timeout_is_passed_only_when_asked(monkeypatch: pytest.MonkeyPatch) -> None:
    seen: list[dict] = []

    def fake_get(url: str, **kwargs):  # noqa: ANN202, ANN003, ARG001
        seen.append(kwargs)
        return _Response(200, content=b"ok")

    monkeypatch.setattr(requests, "get", fake_get)
    fetch_github_asset(ASSET, max_bytes=10)
    fetch_github_asset(ASSET, max_bytes=10, timeout=7.0)

    assert "timeout" not in seen[0]
    assert seen[1]["timeout"] == 7.0
