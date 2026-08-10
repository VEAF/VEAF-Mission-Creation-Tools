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
