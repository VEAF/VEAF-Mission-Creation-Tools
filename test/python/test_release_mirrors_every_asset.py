"""Every asset uploaded to the versioned release must also reach `published-latest`.

Why this test exists: 6.18.0 shipped `veaf-logs.exe` to `published-v6.18.0` only. GitHub points
every visitor at the floating "Latest" release, so the tool was published and invisible — the
release page a user actually opens did not list it. The capture kit and the standalone binaries
already mirrored; the veaf-logs step was written later and never got the same treatment.

The workflow is read as text, not as parsed YAML: the upload commands live inside `run:` shell
blocks, so YAML gives one long string per step and nothing structural to assert on. What matters
is the pairing — an upload to the versioned tag, and an upload to `published-latest` guarded by
the pre-release check.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

WORKFLOW = Path(__file__).resolve().parents[2] / ".github" / "workflows" / "release.yml"

# One `gh release upload` invocation and everything up to the end of its line. The target is not
# captured separately on purpose: it is written `"${{ steps.version.outputs.tag }}"`, which no
# whitespace-delimited pattern splits correctly.
UPLOAD = re.compile(r"gh release upload\s+(.*)$", re.M)

# The guard every mirror must carry: a pre-release leaves published-latest on the previous stable.
PRERELEASE_GUARD = re.compile(r'prerelease.*?!=.*?["\']true["\'].*?gh release view published-latest', re.S)

ASSET = re.compile(r'["\']?([^"\'\s]+\.(?:exe|zip))')


@pytest.fixture(scope="module")
def workflow() -> str:
    """Return the release workflow's source text."""
    return WORKFLOW.read_text(encoding="utf-8")


def _uploads(text: str) -> list[tuple[bool, set[str]]]:
    """Return (targets published-latest, asset file names) for each upload command."""
    result: list[tuple[bool, set[str]]] = []
    for arguments in UPLOAD.findall(text):
        # `published-latest` appears as the literal target; anything else is the versioned tag.
        to_latest = arguments.lstrip().startswith("published-latest")
        names = {Path(token.split("#")[0]).name for token in ASSET.findall(arguments)}
        result.append((to_latest, names))
    return result


def test_the_workflow_still_uploads_to_both_kinds_of_release(workflow: str) -> None:
    """Guard the assumption the rest of this module rests on."""
    uploads = _uploads(workflow)
    assert uploads, "no `gh release upload` found — the workflow was restructured"
    assert any(to_latest for to_latest, _ in uploads), "nothing is uploaded to published-latest"
    assert any(not to_latest for to_latest, _ in uploads), (
        "nothing is uploaded to a versioned release; the mirror check would be meaningless"
    )


def test_veaf_logs_reaches_the_latest_release(workflow: str) -> None:
    """The defect this test was written for: veaf-logs uploaded to the version tag only."""
    mirrored = {name for to_latest, names in _uploads(workflow) if to_latest for name in names}
    assert any("veaf-logs" in name for name in mirrored), (
        "veaf-logs is uploaded to the versioned release but never mirrored onto "
        "published-latest, which is the release GitHub shows every visitor"
    )


def test_every_asset_uploaded_to_the_version_tag_is_mirrored(workflow: str) -> None:
    """Not just veaf-logs: a sweep, so the next asset added does not repeat this."""
    versioned: set[str] = set()
    mirrored: set[str] = set()
    for to_latest, names in _uploads(workflow):
        (mirrored if to_latest else versioned).update(names)

    missing = versioned - mirrored
    assert not missing, (
        f"uploaded to the versioned release but never to published-latest: {sorted(missing)}. "
        "GitHub shows visitors the floating Latest release, so an asset missing there is "
        "published and unreachable."
    )


def test_each_mirror_is_guarded_against_a_pre_release(workflow: str) -> None:
    """A pre-release must not push its assets onto the release production users download."""
    mirrors = workflow.count("gh release upload published-latest")
    guards = len(PRERELEASE_GUARD.findall(workflow))
    assert mirrors > 0, "no mirror at all — the other tests should have caught this"
    assert guards >= mirrors, (
        f"{mirrors} uploads to published-latest but only {guards} pre-release guards: "
        "a release candidate would overwrite the stable assets users download"
    )
