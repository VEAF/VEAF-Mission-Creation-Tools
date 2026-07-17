"""Tests for GitHubPublisher pre-release detection.

The floating `published-latest` tag must only move for a real release. A pre-release is
signalled either by the explicit flag or by a semver pre-release suffix in the version
(`6.9.21-rc1`). `_is_prerelease` is the single source of truth both the CLI publish path
and the release workflow key off.
"""

from __future__ import annotations

from pathlib import Path
from unittest import mock

import pytest
from typer.testing import CliRunner

from veaf_build.cli import app
from veaf_build.github import GitHubPublisher


def _publisher(version: str, *, prerelease: bool = False) -> GitHubPublisher:
    return GitHubPublisher(
        owner="VEAF",
        repo="VEAF-Mission-Creation-Tools",
        token=None,
        version=version,
        script_root=Path("."),
        dist_dir=Path("."),
        output_path=Path("."),
        prerelease=prerelease,
    )


def test_stable_version_is_not_prerelease() -> None:
    assert _publisher("6.9.21")._is_prerelease is False


def test_explicit_flag_marks_prerelease() -> None:
    assert _publisher("6.9.21", prerelease=True)._is_prerelease is True


def test_semver_suffix_marks_prerelease() -> None:
    # No explicit flag, but the version carries a pre-release suffix.
    assert _publisher("6.9.21-rc1")._is_prerelease is True
    assert _publisher("6.9.21-pre")._is_prerelease is True


def test_flag_and_suffix_together() -> None:
    assert _publisher("6.9.21-rc1", prerelease=True)._is_prerelease is True


def test_publish_rejects_prerelease_without_semver_suffix() -> None:
    # --prerelease on a plain version is the trap that once shipped dev to production:
    # locally a pre-release, but CI would still advance published-latest. Reject it early.
    result = CliRunner().invoke(app, ["publish", "--version", "6.9.20", "--prerelease", "--token", "x", "--ci"])
    assert result.exit_code == 1
    assert "semver pre-release version" in result.output


def test_publish_allows_prerelease_with_semver_suffix(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    # A suffixed version passes the guard. Run in a temp cwd with a dummy published.zip and
    # mock the real GitHub publish, so the command proceeds past the guard without touching
    # git or the network — and assert the publish was actually reached.
    monkeypatch.chdir(tmp_path)
    (tmp_path / "published.zip").write_bytes(b"zip")
    with mock.patch("veaf_build.worker.BuildAndReleaseWorker._do_publish_to_github") as publish_mock:
        result = CliRunner().invoke(
            app, ["publish", "--version", "6.9.20-rc1", "--prerelease", "--token", "x", "--ci"]
        )
    assert "semver pre-release version" not in result.output
    publish_mock.assert_called_once()
