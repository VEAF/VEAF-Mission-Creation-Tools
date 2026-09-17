"""Every asset uploaded to the versioned release must also reach `published-latest`.

Why this test exists: 6.18.0 shipped `veaf-logs.exe` to `published-v6.18.0` only. GitHub points
every visitor at the floating "Latest" release, so the tool was published and invisible — the
release page a user actually opens did not list it. The capture kit and the standalone binaries
already mirrored; the veaf-logs step was written later and never got the same treatment.

The workflow is read as text, not as parsed YAML: the upload commands live inside `run:` shell
blocks, so YAML gives one long string per step and nothing structural to assert on. What matters
is the pairing — an upload to the versioned tag, and an upload to `published-latest` guarded by
the pre-release check.

**An asset is identified by the argument as it is written**, not by a filename the test tries to
recognise. The workflow passes `"dist/veaf-logs.exe#veaf-logs-${{ … }}.exe"`, `"$KIT"` and
`"dist/${{ matrix.asset }}"` — a shell variable and two templates. Matching on spelling pairs all
three with their mirror without the test having to expand shell or Actions syntax; the earlier
version matched filenames ending in `.exe` or `.zip` and, measured against this workflow, saw one
upload argument out of seven. The cost of the spelling rule is that a mirror which names the same
file differently reads as unmirrored, which the failure message says.
"""

from __future__ import annotations

import re
import shlex
from pathlib import Path

import pytest

WORKFLOW = Path(__file__).resolve().parents[2] / ".github" / "workflows" / "release.yml"

# A shell command continued on the next line. Joined before anything else is read: two of the six
# upload commands carry their assets past a `\`, where a line-anchored pattern never sees them.
CONTINUATION = re.compile(r"\\\n\s*")

# One `gh release upload` invocation and everything up to the end of its (joined) line.
UPLOAD = re.compile(r"gh release upload\s+(.*)$", re.M)

# The guard every mirror must carry: a pre-release leaves published-latest on the previous stable.
PRERELEASE_GUARD = re.compile(r'prerelease.*?!=.*?["\']true["\'].*?gh release view published-latest', re.S)

LATEST = "published-latest"


@pytest.fixture(scope="module")
def workflow() -> str:
    """Return the release workflow's source text."""
    return WORKFLOW.read_text(encoding="utf-8")


def _asset(argument: str) -> str:
    """Normalise one upload argument into the identity this module compares.

    Drops the `file#label` suffix `gh release upload` accepts, and collapses the whitespace inside
    `${{ … }}` so the same template written two ways still pairs.

    Args:
        argument: One argument of a `gh release upload` command, already unquoted.

    Returns:
        The argument's asset identity.
    """
    return " ".join(argument.split("#", 1)[0].split())


def _uploads(text: str) -> list[tuple[bool, set[str]]]:
    """Return (targets published-latest, asset identities) for each upload command.

    Args:
        text: The release workflow's source.

    Returns:
        One entry per `gh release upload` found, in file order.

    Raises:
        ValueError: If an upload command cannot be split into shell words, which means the
            workflow was written in a form this module no longer reads correctly.
    """
    result: list[tuple[bool, set[str]]] = []
    for arguments in UPLOAD.findall(CONTINUATION.sub(" ", text)):
        try:
            words = shlex.split(arguments)
        except ValueError as error:  # pragma: no cover - a malformed workflow, not a code path
            raise ValueError(f"cannot read the upload command `{arguments}`: {error}") from error
        target, operands = words[0], words[1:]
        assets = {_asset(word) for word in operands if not word.startswith("-")}
        result.append((_asset(target) == LATEST, assets))
    return result


def test_the_workflow_still_uploads_to_both_kinds_of_release(workflow: str) -> None:
    """Guard the assumption the rest of this module rests on."""
    uploads = _uploads(workflow)
    assert uploads, "no `gh release upload` found — the workflow was restructured"
    assert any(to_latest for to_latest, _ in uploads), "nothing is uploaded to published-latest"
    assert any(not to_latest for to_latest, _ in uploads), (
        "nothing is uploaded to a versioned release; the mirror check would be meaningless"
    )


def test_every_upload_command_yields_at_least_one_asset(workflow: str) -> None:
    """The sweep is only a sweep if every command contributes.

    This is the check whose absence let the previous version pass while reading one upload
    argument out of seven: four of the six commands yielded an empty set and an empty set is
    subtracted away without a trace.
    """
    empty = [index for index, (_, assets) in enumerate(_uploads(workflow), 1) if not assets]
    assert not empty, (
        f"upload command(s) {empty} carry no asset the sweep can see, so whatever they publish is "
        "outside it — the mirror check would silently pass over them"
    )


def test_veaf_logs_reaches_the_latest_release(workflow: str) -> None:
    """The defect this test was written for: veaf-logs uploaded to the version tag only."""
    mirrored = {name for to_latest, names in _uploads(workflow) if to_latest for name in names}
    assert any("veaf-logs" in name for name in mirrored), (
        "veaf-logs is uploaded to the versioned release but never mirrored onto "
        "published-latest, which is the release GitHub shows every visitor"
    )


def _unmirrored(text: str) -> set[str]:
    """Return the assets uploaded to a versioned release and to no `published-latest` one.

    Args:
        text: The release workflow's source.

    Returns:
        The asset identities that reach the versioned release only.
    """
    versioned: set[str] = set()
    mirrored: set[str] = set()
    for to_latest, assets in _uploads(text):
        (mirrored if to_latest else versioned).update(assets)
    return versioned - mirrored


def test_every_asset_uploaded_to_the_version_tag_is_mirrored(workflow: str) -> None:
    """Not just veaf-logs: a sweep, so the next asset added does not repeat this."""
    missing = _unmirrored(workflow)
    assert not missing, (
        f"uploaded to the versioned release but never to published-latest: {sorted(missing)}. "
        "GitHub shows visitors the floating Latest release, so an asset missing there is "
        "published and unreachable. An asset is matched on the argument as written, so a mirror "
        "that spells the same file differently reads as missing and should be spelled alike."
    )


def test_the_sweep_notices_an_unmirrored_asset() -> None:
    """Prove the sweep can fail, on each shape the workflow actually uses.

    A check that cannot come out negative proves nothing, and the previous version of this module
    could not: an asset it did not recognise left both sides of the subtraction untouched. Each
    fragment below is a versioned upload with no mirror, in one of the three spellings the
    workflow writes — a literal path with a `#label`, a shell variable, and a matrix template
    continued past a backslash.
    """
    fragments = {
        "dist/veaf-logs.exe": 'gh release upload "$TAG" "dist/veaf-logs.exe#veaf-logs-1.0.exe" --clobber\n',
        "$KIT": 'gh release upload "$TAG" "$KIT" --clobber\n',
        "dist/${{ matrix.asset }}": 'gh release upload "$TAG" \\\n  "dist/${{ matrix.asset }}" --clobber\n',
    }
    mirror = 'gh release upload published-latest "$OTHER" --clobber\n'
    for asset, fragment in fragments.items():
        assert _unmirrored(fragment + mirror) == {asset}, (
            f"the sweep does not see `{asset}` going to the versioned release alone"
        )
        assert not _unmirrored(fragment + fragment.replace('"$TAG"', LATEST)), (
            f"the sweep reports `{asset}` as unmirrored although it is mirrored"
        )


def test_each_mirror_is_guarded_against_a_pre_release(workflow: str) -> None:
    """A pre-release must not push its assets onto the release production users download."""
    mirrors = workflow.count(f"gh release upload {LATEST}")
    guards = len(PRERELEASE_GUARD.findall(workflow))
    assert mirrors > 0, "no mirror at all — the other tests should have caught this"
    assert guards >= mirrors, (
        f"{mirrors} uploads to published-latest but only {guards} pre-release guards: "
        "a release candidate would overwrite the stable assets users download"
    )
