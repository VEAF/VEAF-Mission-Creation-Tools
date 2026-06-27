"""Drift detection for vendored third-party artifacts (VENDORED-DRIFT-WATCH).

Reads the ``vendored.yaml`` manifest and, for each artifact's ``watch`` entries,
compares the pinned baseline against the live upstream value (latest release tag or
latest file commit) **via an injected GitHub client** — the logic here performs no
network I/O, so it is unit-tested with a fake client.

Per-watch status:
- ``up-to-date`` -- live value equals the pin;
- ``drifted`` -- live value differs from the pin (upstream moved);
- ``manual`` -- no automatable source; surfaced as a re-check reminder;
- ``error`` -- the live value could not be resolved (repo renamed, API failure…).

NOTIFY ONLY: this module detects drift; it never updates a pin.
"""

from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass
from typing import Any, Protocol

STATUS_UP_TO_DATE = "up-to-date"
STATUS_DRIFTED = "drifted"
STATUS_MANUAL = "manual"
STATUS_ERROR = "error"

KIND_RELEASE = "github-release"
KIND_FILE = "github-file"
KIND_MANUAL = "manual"


@dataclass(frozen=True)
class Watch:
    """A single drift check attached to an artifact.

    Attributes:
        kind: One of ``github-release`` / ``github-file`` / ``manual``.
        repo: ``OWNER/NAME`` of the watched repo (empty for ``manual``).
        ref: Branch to track for ``github-file`` (empty otherwise).
        file: Path inside ``repo`` for ``github-file`` (empty -> track branch HEAD).
        pinned: Baseline value (a release tag, or a commit SHA).
        role: Optional marker, e.g. ``upstream-ref``.
    """

    kind: str
    repo: str
    ref: str
    file: str
    pinned: str
    role: str


@dataclass(frozen=True)
class Artifact:
    """A vendored artifact and its watches.

    Attributes:
        id: Short identifier.
        source: Repo we vendor from (may be empty).
        upstream: Reference origin repo.
        pinned: Human-readable shipped version (display only).
        vendoring: ``verbatim`` / ``adapted`` / ``fork`` / ``compiled``.
        path: Repo-relative path of the vendored copy.
        manual_steps: The real update work.
        watches: The drift checks for this artifact.
    """

    id: str
    source: str
    upstream: str
    pinned: str
    vendoring: str
    path: str
    manual_steps: str
    watches: tuple[Watch, ...]


@dataclass(frozen=True)
class WatchResult:
    """Outcome of evaluating one :class:`Watch`."""

    artifact_id: str
    kind: str
    repo: str
    role: str
    pinned: str
    latest: str | None
    status: str


@dataclass(frozen=True)
class CheckReport:
    """Full result of a manifest check."""

    artifacts: tuple[Artifact, ...]
    results: tuple[WatchResult, ...]

    @property
    def drifted(self) -> tuple[WatchResult, ...]:
        """Watches whose upstream moved past the pin."""
        return tuple(r for r in self.results if r.status == STATUS_DRIFTED)

    @property
    def errors(self) -> tuple[WatchResult, ...]:
        """Watches whose live value could not be resolved."""
        return tuple(r for r in self.results if r.status == STATUS_ERROR)

    @property
    def manual(self) -> tuple[WatchResult, ...]:
        """Manual re-check reminders."""
        return tuple(r for r in self.results if r.status == STATUS_MANUAL)

    @property
    def has_actionable(self) -> bool:
        """Whether anything needs attention (drift or error)."""
        return bool(self.drifted or self.errors)

    def artifact(self, artifact_id: str) -> Artifact:
        """Return the artifact with the given id."""
        return next(a for a in self.artifacts if a.id == artifact_id)


class GitHubClient(Protocol):
    """Minimal GitHub read interface the checker needs (injected for testing)."""

    def latest_release(self, repo: str) -> str | None:
        """Return the latest release tag of ``repo`` (``None`` if none/unresolved)."""
        ...

    def latest_file_commit(self, repo: str, ref: str, file: str | None) -> str | None:
        """Return the latest commit SHA on ``ref`` (for ``file`` if given)."""
        ...


def parse_manifest(data: dict[str, Any]) -> tuple[Artifact, ...]:
    """Build the artifact list from a parsed ``vendored.yaml`` document.

    Args:
        data: The decoded manifest (with a top-level ``artifacts`` list).

    Returns:
        The parsed artifacts.
    """
    artifacts: list[Artifact] = []
    for entry in data.get("artifacts", []) or []:
        watches = tuple(
            Watch(
                kind=str(w.get("kind", "")),
                repo=str(w.get("repo", "")),
                ref=str(w.get("ref", "")),
                file=str(w.get("file", "")),
                pinned=str(w.get("pinned", "")),
                role=str(w.get("role", "")),
            )
            for w in (entry.get("watch") or [])
        )
        artifacts.append(
            Artifact(
                id=str(entry.get("id", "")),
                source=str(entry.get("source", "")),
                upstream=str(entry.get("upstream", "")),
                pinned=str(entry.get("pinned", "")),
                vendoring=str(entry.get("vendoring", "")),
                path=str(entry.get("path", "")),
                manual_steps=str(entry.get("manual_steps", "")),
                watches=watches,
            )
        )
    return tuple(artifacts)


def _shas_match(pinned: str, latest: str) -> bool:
    """Whether two commit SHAs refer to the same commit (lenient on short SHAs)."""
    a, b = pinned.lower(), latest.lower()
    return bool(a) and bool(b) and (a.startswith(b) or b.startswith(a))


def evaluate_watch(artifact: Artifact, watch: Watch, client: GitHubClient) -> WatchResult:
    """Evaluate a single watch against the live upstream value.

    Args:
        artifact: The owning artifact.
        watch: The watch to evaluate.
        client: GitHub read client.

    Returns:
        The :class:`WatchResult`.
    """
    if watch.kind == KIND_MANUAL:
        return WatchResult(artifact.id, watch.kind, watch.repo, watch.role, watch.pinned, None, STATUS_MANUAL)

    if watch.kind == KIND_RELEASE:
        latest = client.latest_release(watch.repo)
        if latest is None:
            return WatchResult(artifact.id, watch.kind, watch.repo, watch.role, watch.pinned, None, STATUS_ERROR)
        status = STATUS_UP_TO_DATE if latest == watch.pinned else STATUS_DRIFTED
        return WatchResult(artifact.id, watch.kind, watch.repo, watch.role, watch.pinned, latest, status)

    if watch.kind == KIND_FILE:
        latest = client.latest_file_commit(watch.repo, watch.ref, watch.file or None)
        if latest is None:
            return WatchResult(artifact.id, watch.kind, watch.repo, watch.role, watch.pinned, None, STATUS_ERROR)
        status = STATUS_UP_TO_DATE if _shas_match(watch.pinned, latest) else STATUS_DRIFTED
        return WatchResult(artifact.id, watch.kind, watch.repo, watch.role, watch.pinned, latest, status)

    # Unknown kind -> surface as an error rather than silently passing.
    return WatchResult(artifact.id, watch.kind, watch.repo, watch.role, watch.pinned, None, STATUS_ERROR)


def check_artifacts(artifacts: Iterable[Artifact], client: GitHubClient) -> CheckReport:
    """Evaluate every watch of every artifact.

    Args:
        artifacts: The artifacts to check.
        client: GitHub read client.

    Returns:
        The :class:`CheckReport`.
    """
    artifacts = tuple(artifacts)
    results = tuple(evaluate_watch(a, w, client) for a in artifacts for w in a.watches)
    return CheckReport(artifacts=artifacts, results=results)
