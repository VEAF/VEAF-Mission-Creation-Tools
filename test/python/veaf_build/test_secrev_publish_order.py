"""SECREV-2 / VMR-104, VMR-105 — tags were pushed before the release existed.

`publish` ran `_publish_with_git_tags` first and `_publish_with_gh_cli` second. So when `gh` is
absent — or when creating the release fails — the tags are already on the remote: `published-v<x>`
points at a commit with no release, and for a full release the floating `published-latest` has been
force-moved there too. Anything that resolves `published-latest` (the updater, a documentation
link, a user clicking through) then lands on a tag that promises a release GitHub cannot serve.

The order is the fix: check `gh` is usable *before* touching the remote, and move the floating tag
only once the release is created.
"""

from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path
from unittest import mock

import pytest
import typer

from veaf_build.github import GitHubPublisher


def _prepared_root() -> Path:
    """A throwaway root holding what the publisher requires, and nothing else.

    Using the repository root instead made these tests pass locally and fail in CI: a
    `published-metadata.json` left over from a local build is there on this machine and absent on a
    fresh checkout, and the publisher refuses to create a release without it. Same for
    `RELEASE_NOTES.md`, which would silently change the command line.
    """
    root = Path(tempfile.mkdtemp())
    (root / "published-metadata.json").write_text('{"published_zip_sha256": "deadbeef"}', encoding="utf-8")
    return root


def _publisher(*, token: str | None = "t0ken", version: str = "6.13.72", prerelease: bool = False) -> GitHubPublisher:
    root = _prepared_root()
    return GitHubPublisher(
        owner="VEAF",
        repo="VEAF-Mission-Creation-Tools",
        token=token,
        version=version,
        script_root=root,
        dist_dir=root,
        output_path=root,
        prerelease=prerelease,
    )


class _Recorder:
    """Records every subprocess.run call, and can fail a chosen command."""

    def __init__(self, fail_on: str | None = None, missing: str | None = None) -> None:
        self.calls: list[list[str]] = []
        self.fail_on = fail_on
        self.missing = missing

    def __call__(self, cmd, *args, **kwargs):  # noqa: ANN001, ANN002, ANN003
        self.calls.append(list(cmd))
        joined = " ".join(str(c) for c in cmd)
        if self.missing and joined.startswith(self.missing):
            raise FileNotFoundError(self.missing)
        if self.fail_on and self.fail_on in joined:
            if kwargs.get("check"):
                raise subprocess.CalledProcessError(1, cmd)
            return subprocess.CompletedProcess(cmd, 1, stdout="", stderr="boom")
        return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")

    def pushed_tags(self) -> list[str]:
        return [c[-1] for c in self.calls if c[:3] == ["git", "push", "origin"]]

    def index_of(self, fragment: str) -> int:
        for i, c in enumerate(self.calls):
            if fragment in " ".join(str(x) for x in c):
                return i
        return -1


def _run(recorder: _Recorder, publisher: GitHubPublisher) -> None:
    # The asset uploads are inline in _publish_with_gh_cli and guarded by `.exists()`; the prepared
    # root holds only published-metadata.json, so they are skipped without extra mocking.
    with mock.patch("veaf_build.github.subprocess.run", recorder):
        publisher.publish(Path("pkg.zip"), "deadbeef")


class TestNothingIsPushedWhenGhIsUnusable:
    def test_no_tag_is_pushed_when_gh_is_absent(self) -> None:
        recorder = _Recorder(missing="gh")
        _run(recorder, _publisher())
        assert recorder.pushed_tags() == [], f"tags reached the remote without a release: {recorder.pushed_tags()}"

    def test_the_absence_is_reported(self) -> None:
        recorder = _Recorder(missing="gh")
        with mock.patch("veaf_build.github.logger") as log:
            _run(recorder, _publisher())
        assert log.warning.called or log.error.called, "an unusable gh CLI must be reported"


class TestTheFloatingTagWaitsForTheRelease:
    def test_latest_is_not_moved_when_the_release_creation_fails(self) -> None:
        recorder = _Recorder(fail_on="gh release create")
        # `logger.error` raises typer.Abort, so a failed release creation aborts the publish —
        # which is what keeps the floating tag where it was. Both properties are asserted.
        with pytest.raises(typer.Abort):
            _run(recorder, _publisher())
        assert "published-latest" not in recorder.pushed_tags(), (
            "published-latest was moved onto a commit with no release"
        )

    def test_the_release_is_created_before_the_floating_tag_moves(self) -> None:
        recorder = _Recorder()
        _run(recorder, _publisher())
        created = recorder.index_of("gh release create")
        moved = recorder.index_of("push origin -f published-latest")
        assert created != -1, f"the release was never created: {recorder.calls}"
        assert moved != -1, f"the floating tag was never moved: {recorder.calls}"
        assert created < moved, "published-latest moved before the release existed"


class TestASuccessfulPublishStillDoesEverything:
    """The control: the assertions above would all hold on a publisher that does nothing."""

    def test_both_tags_are_pushed(self) -> None:
        recorder = _Recorder()
        _run(recorder, _publisher())
        assert "published-v6.13.72" in recorder.pushed_tags()
        assert "published-latest" in recorder.pushed_tags()

    def test_a_prerelease_pushes_only_its_own_tag(self) -> None:
        recorder = _Recorder()
        _run(recorder, _publisher(version="6.13.72-rc1"))
        assert "published-v6.13.72-rc1" in recorder.pushed_tags()
        assert "published-latest" not in recorder.pushed_tags()

    def test_the_release_is_created(self) -> None:
        recorder = _Recorder()
        _run(recorder, _publisher())
        assert recorder.index_of("gh release create") != -1


class TestTagsOnlyModeIsUnaffected:
    """Without a token there is no release to wait for, so the tags-only path must still run."""

    def test_tags_are_pushed_without_a_token(self) -> None:
        recorder = _Recorder()
        _run(recorder, _publisher(token=None))
        assert "published-v6.13.72" in recorder.pushed_tags()
        assert recorder.index_of("gh release create") == -1
