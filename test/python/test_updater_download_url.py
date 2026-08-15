"""The updater refuses a release asset URL that is not https on GitHub (SECREV-2 / VMR-037).

The updater installs and then *runs* what it downloads, and the URL it uses comes from the GitHub API
reply rather than from us. These tests load `veaf-tools-updater.py` by path: its hyphenated filename
is not importable as a module, and the neighbouring `test_version_constraint.py` works around that by
keeping a **copy** of the functions under test — which cannot fail when the shipped code regresses.
Loading the real file is the whole point of a test guarding a security check.
"""

from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path
from types import ModuleType
from unittest import mock

_UPDATER_PATH = Path(__file__).parents[2] / "src" / "python" / "veaf-tools" / "veaf-tools-updater.py"


def _load_updater() -> ModuleType:
    """Import `veaf-tools-updater.py` under a valid module name and return it."""
    spec = importlib.util.spec_from_file_location("veaf_tools_updater_under_test", _UPDATER_PATH)
    assert spec is not None and spec.loader is not None, f"cannot load {_UPDATER_PATH}"
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class TestTrustedDownloadUrl(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.updater = _load_updater()

    def _accepts(self, url: str | None) -> bool:
        return bool(self.updater._is_trusted_download_url(url))

    def test_it_accepts_the_urls_github_actually_returns(self) -> None:
        for url in (
            "https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases/download/v6.13.0/veaf-tools.exe",
            "https://objects.githubusercontent.com/github-production-release-asset-abc/1/2",
            "https://raw.githubusercontent.com/VEAF/repo/develop/file.lua",
            "https://api.github.com/repos/VEAF/repo/releases/assets/42",
        ):
            with self.subTest(url=url):
                self.assertTrue(self._accepts(url))

    def test_it_refuses_another_host(self) -> None:
        self.assertFalse(self._accepts("https://evil.example.com/veaf-tools.exe"))

    def test_it_refuses_a_host_merely_ending_in_the_trusted_name(self) -> None:
        # `endswith` on the bare name would accept this; the check requires the dotted suffix.
        self.assertFalse(self._accepts("https://notgithubusercontent.com/veaf-tools.exe"))
        self.assertFalse(self._accepts("https://github.com.evil.example/veaf-tools.exe"))

    def test_it_refuses_plain_http_on_a_trusted_host(self) -> None:
        self.assertFalse(self._accepts("http://github.com/VEAF/repo/releases/download/v1/x.exe"))

    def test_it_refuses_a_non_web_scheme(self) -> None:
        self.assertFalse(self._accepts("file:///C:/Windows/System32/calc.exe"))

    def test_it_refuses_a_missing_url(self) -> None:
        # The callers pass `asset.get("browser_download_url")`, so None reaches here in practice
        # even though the annotation says str.
        self.assertFalse(self._accepts(None))
        self.assertFalse(self._accepts(""))


class _FakeResponse:
    """Minimal stand-in for a `requests.Response` — only what `download_asset` reads."""

    def __init__(
        self,
        status_code: int = 200,
        location: str | None = None,
        content: bytes = b"payload",
        *,
        declared_length: int | None = None,
        endless: bool = False,
    ) -> None:
        self.status_code = status_code
        self.headers = {"Location": location} if location else {}
        if declared_length is not None:
            self.headers["Content-Length"] = str(declared_length)
        self.content = content
        self.reason = "OK"
        # `endless` streams for ever, which is what an unbounded read has to survive: a response
        # with no Content-Length that simply never stops (SECREV-2, ticket 04's network half).
        self._endless = endless

    def iter_content(self, chunk_size: int = 8192):  # noqa: ANN201
        if self._endless:
            while True:
                yield b"x" * chunk_size
        for start in range(0, len(self.content), chunk_size):
            yield self.content[start : start + chunk_size]

    def close(self) -> None:
        pass

    @property
    def is_redirect(self) -> bool:
        return self.status_code in {301, 302, 303, 307, 308} and "Location" in self.headers

    @property
    def is_permanent_redirect(self) -> bool:
        return self.status_code in {301, 308} and "Location" in self.headers


class TestEveryRedirectHopIsChecked(unittest.TestCase):
    """Validating only the first URL was not enough — `requests` follows redirects anywhere.

    Sourcery caught this on PR #696: the guard checked `asset_url` and then called `requests.get`,
    which follows a 3xx to any host by default. The chain is now walked one hop at a time.
    """

    ASSET = "https://github.com/VEAF/repo/releases/download/v1/veaf-tools.exe"

    def setUp(self) -> None:
        self.updater_module = _load_updater()
        self.calls: list[tuple[str, dict]] = []

    def _updater(self, token: str | None = "secret-token") -> object:
        updater = object.__new__(self.updater_module.UpdateWorker)
        updater.headers = {"Accept": "application/vnd.github.v3+json"}
        if token:
            updater.headers["Authorization"] = f"token {token}"
        return updater

    def _run(self, responses: list[_FakeResponse], token: str | None = "secret-token") -> bytes | None:
        queued = list(responses)

        def fake_get(
            url: str, headers: dict | None = None, allow_redirects: bool = True, stream: bool = False
        ) -> _FakeResponse:
            # `stream` since the body is read chunk by chunk to honour the size cap.
            self.calls.append((url, dict(headers or {})))
            return queued.pop(0)

        with (
            mock.patch.object(self.updater_module.requests, "get", side_effect=fake_get),
            mock.patch.object(self.updater_module, "spinner_context", mock.MagicMock()),
        ):
            return self.updater_module.UpdateWorker.download_asset(self._updater(token), self.ASSET, "veaf-tools.exe")

    def test_a_redirect_to_github_object_storage_is_followed(self) -> None:
        content = self._run(
            [
                _FakeResponse(302, location="https://objects.githubusercontent.com/release/1"),
                _FakeResponse(200, content=b"the exe"),
            ]
        )

        self.assertEqual(content, b"the exe", "the normal GitHub redirect must still work")
        self.assertEqual(
            [url for url, _ in self.calls], [self.ASSET, "https://objects.githubusercontent.com/release/1"]
        )

    def test_a_redirect_off_github_is_refused_and_never_fetched(self) -> None:
        content = self._run([_FakeResponse(302, location="https://evil.example.com/payload.exe")])

        self.assertIsNone(content, "a hop off GitHub must abandon the download")
        self.assertEqual(
            [url for url, _ in self.calls],
            [self.ASSET],
            "the untrusted URL must never be requested — refusing after fetching it is not refusing",
        )

    def test_the_github_token_is_not_forwarded_to_another_host(self) -> None:
        # `requests` drops Authorization itself across hosts; walking the chain by hand means doing it
        # here, or the user's token reaches whatever host the redirect names.
        self._run(
            [
                _FakeResponse(302, location="https://objects.githubusercontent.com/release/1"),
                _FakeResponse(200),
            ]
        )

        first_headers, second_headers = self.calls[0][1], self.calls[1][1]
        self.assertIn("Authorization", first_headers, "the token belongs on the original GitHub host")
        self.assertNotIn("Authorization", second_headers, "the token must not follow the redirect")

    def test_a_relative_location_resolves_against_the_url_that_sent_it(self) -> None:
        content = self._run([_FakeResponse(302, location="/other/path.exe"), _FakeResponse(200, content=b"ok")])

        self.assertEqual(content, b"ok")
        self.assertEqual(self.calls[1][0], "https://github.com/other/path.exe")

    def test_an_endless_redirect_chain_gives_up(self) -> None:
        loop = [_FakeResponse(302, location=self.ASSET) for _ in range(20)]

        content = self._run(loop)

        self.assertIsNone(content, "a redirect loop must end in a refusal, not spin")
        self.assertLessEqual(len(self.calls), self.updater_module._MAX_DOWNLOAD_REDIRECTS + 1)


class TestTheDownloadIsCapped(unittest.TestCase):
    """SECREV-2 ticket 04 — the last of its integrity findings: the network side had no bound.

    `download_asset` read the whole response into memory with `response.content`. The updater
    installs and then *runs* what it downloads, and the size comes from whatever answered — so a
    response with no `Content-Length` that simply never ends filled the machine's memory.

    The cap is 256 MiB against a largest real asset of 61 MiB (`published.zip`, measured on the
    published release), and it matches `safe_zip.MAX_MEMBER_UNCOMPRESSED_BYTES` so the two bounds in
    the codebase agree.
    """

    ASSET = "https://github.com/VEAF/repo/releases/download/v1/veaf-tools.exe"

    def setUp(self) -> None:
        self.updater_module = _load_updater()

    def _updater(self) -> object:
        updater = object.__new__(self.updater_module.UpdateWorker)
        updater.headers = {"Accept": "application/vnd.github.v3+json"}
        return updater

    def _run(self, response: _FakeResponse, cap: int | None = None) -> bytes | None:
        def fake_get(url: str, headers: dict | None = None, allow_redirects: bool = True, stream: bool = False):  # noqa: ANN202, ARG001
            return response

        patches = [
            mock.patch.object(self.updater_module.requests, "get", side_effect=fake_get),
            mock.patch.object(self.updater_module, "spinner_context", mock.MagicMock()),
        ]
        if cap is not None:
            patches.append(mock.patch.object(self.updater_module, "_MAX_ASSET_BYTES", cap))
        with patches[0], patches[1], patches[2] if cap is not None else mock.MagicMock():
            return self.updater_module.UpdateWorker.download_asset(self._updater(), self.ASSET, "veaf-tools.exe")

    def test_the_cap_leaves_room_for_the_largest_real_asset(self) -> None:
        # 61 MiB measured on the published release; a cap below that would break every update.
        self.assertGreater(self.updater_module._MAX_ASSET_BYTES, 64_109_838)

    def test_an_asset_under_the_cap_is_returned(self) -> None:
        # The control: the cap must not get in the way of a normal download.
        self.assertEqual(self._run(_FakeResponse(200, content=b"payload" * 100)), b"payload" * 100)

    def test_a_declared_length_over_the_cap_is_refused(self) -> None:
        response = _FakeResponse(200, content=b"x" * 10, declared_length=999_999_999)
        self.assertIsNone(self._run(response, cap=1024), "a declared oversize must be refused")

    def test_an_endless_response_is_refused_rather_than_read(self) -> None:
        # No Content-Length, no end: this is the case `response.content` could not survive.
        self.assertIsNone(self._run(_FakeResponse(200, endless=True), cap=4096))

    def test_a_response_exactly_at_the_cap_is_accepted(self) -> None:
        # The boundary matters both ways: an off-by-one here would refuse a legitimate asset.
        payload = b"x" * 4096
        self.assertEqual(self._run(_FakeResponse(200, content=payload), cap=4096), payload)


class TestTheDeferredUpdateScriptBailsOnAFailedCd(unittest.TestCase):
    """A failed `cd` used to leave every relative rename and delete running elsewhere (VMR-036)."""

    def test_the_script_aborts_when_it_cannot_enter_the_target_directory(self) -> None:
        source = _UPDATER_PATH.read_text(encoding="utf-8")
        cd_index = source.index('cd /d "{current_dir}"')
        after_cd = source[cd_index : cd_index + 400]

        self.assertIn("if errorlevel 1 (", after_cd)
        self.assertIn("exit /b 1", after_cd)
        # The guard has to come before the destructive part, or it guards nothing.
        self.assertLess(after_cd.index("exit /b 1"), after_cd.index("del /f /q"))


if __name__ == "__main__":
    unittest.main()
