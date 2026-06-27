"""``check-vendored`` -- report drift of vendored artifacts against upstream.

Thin CLI around :mod:`veaf_libs.vendored_check`. Loads ``vendored.yaml`` and
resolves each watch's live value through the **GitHub API only** (no artifact
download), then renders a Rich table (humans), JSON, or Markdown (the body of the
recap issue opened by the ``vendored-drift-watch`` workflow).

Exit code is non-zero when anything is actionable (drift or error); ``manual``
entries are reminders and do not by themselves fail the run. NOTIFY ONLY.

Usage:
    poetry run check-vendored                  # human table
    poetry run check-vendored --format json    # machine-readable
    poetry run check-vendored --format markdown # issue body (for CI)
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import asdict
from pathlib import Path

import requests
import yaml
from rich.console import Console
from rich.table import Table
from veaf_libs.vendored_check import (  # type: ignore[import-not-found]
    STATUS_DRIFTED,
    STATUS_ERROR,
    STATUS_MANUAL,
    STATUS_UP_TO_DATE,
    CheckReport,
    GitHubClient,
    check_artifacts,
    parse_manifest,
)

_REPO_ROOT = Path(__file__).resolve().parent.parent
_MANIFEST_PATH = _REPO_ROOT / "vendored.yaml"
_API = "https://api.github.com"
_TIMEOUT = 20


class _RequestsGitHubClient:
    """A :class:`GitHubClient` backed by the GitHub REST API via ``requests``."""

    def __init__(self, token: str | None = None) -> None:
        """Initialise with an optional auth token (raises rate limits)."""
        self._headers = {"Accept": "application/vnd.github+json"}
        if token:
            self._headers["Authorization"] = f"Bearer {token}"

    def _get(self, path: str, params: dict[str, str] | None = None) -> requests.Response:
        return requests.get(f"{_API}{path}", headers=self._headers, params=params, timeout=_TIMEOUT)

    def latest_release(self, repo: str) -> str | None:
        """Return the latest release tag of ``repo`` (``None`` if unresolved)."""
        try:
            resp = self._get(f"/repos/{repo}/releases/latest")
        except requests.RequestException:
            return None
        if resp.status_code != 200:
            return None
        tag = resp.json().get("tag_name")
        return str(tag) if tag else None

    def latest_file_commit(self, repo: str, ref: str, file: str | None) -> str | None:
        """Return the latest commit SHA on ``ref`` (for ``file`` if given)."""
        params = {"sha": ref, "per_page": "1"}
        if file:
            params["path"] = file
        try:
            resp = self._get(f"/repos/{repo}/commits", params=params)
        except requests.RequestException:
            return None
        if resp.status_code != 200:
            return None
        commits = resp.json()
        if not commits:
            return None
        return str(commits[0].get("sha")) or None


def run_check(client: GitHubClient | None = None) -> CheckReport:
    """Load the manifest and evaluate every watch.

    Args:
        client: GitHub client (defaults to a token-authenticated REST client).

    Returns:
        The :class:`~veaf_libs.vendored_check.CheckReport`.
    """
    if client is None:
        client = _RequestsGitHubClient(os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN"))
    data = yaml.safe_load(_MANIFEST_PATH.read_text(encoding="utf-8"))
    artifacts = parse_manifest(data)
    return check_artifacts(artifacts, client)


_STATUS_STYLE = {
    STATUS_DRIFTED: "bold red",
    STATUS_ERROR: "bold magenta",
    STATUS_MANUAL: "yellow",
    STATUS_UP_TO_DATE: "green",
}


def _render_table(report: CheckReport, console: Console) -> None:
    """Render the check report as a Rich table."""
    table = Table(title="Vendored artifact drift", show_header=True, expand=False)
    table.add_column("artifact", style="cyan")
    table.add_column("watch")
    table.add_column("pinned")
    table.add_column("latest")
    table.add_column("status")
    for r in report.results:
        watch = f"{r.kind} {r.repo}".strip()
        if r.role:
            watch += f" ({r.role})"
        style = _STATUS_STYLE.get(r.status, "white")
        table.add_row(r.artifact_id, watch, r.pinned or "-", r.latest or "-", f"[{style}]{r.status}[/{style}]")
    console.print(table)
    if report.has_actionable:
        console.print(
            f"[bold red]{len(report.drifted)} drifted, {len(report.errors)} error(s).[/bold red]"
            f" [yellow]{len(report.manual)} manual re-check(s).[/yellow]"
        )
    else:
        console.print(
            f"[bold green]All automatable pins up to date.[/bold green] [yellow]{len(report.manual)} manual.[/yellow]"
        )


def _render_markdown(report: CheckReport) -> str:
    """Render the recap-issue body as GitHub-flavoured Markdown."""
    lines = ["## Vendored artifact drift watch", ""]
    if report.has_actionable:
        lines.append(f"⚠️ **{len(report.drifted)} drifted, {len(report.errors)} error(s)** — action needed.")
    else:
        lines.append("✅ Every automatable pin is up to date.")

    if report.drifted:
        lines += ["", "### Drifted (upstream moved past the pin)", ""]
        for r in report.drifted:
            art = report.artifact(r.artifact_id)
            role = f" _{r.role}_" if r.role else ""
            lines.append(f"- **{r.artifact_id}** ({r.repo}{role}): `{r.pinned}` → `{r.latest}`")
            lines.append(f"  - _update_: {art.manual_steps}")

    if report.errors:
        lines += ["", "### Errors (could not resolve upstream)", ""]
        for r in report.errors:
            lines.append(
                f"- **{r.artifact_id}** ({r.kind} {r.repo}): pinned `{r.pinned}` — check the repo/ref still exists."
            )

    if report.manual:
        lines += ["", "### Manual re-checks (no automatable source)", ""]
        for r in report.manual:
            art = report.artifact(r.artifact_id)
            lines.append(f"- **{r.artifact_id}**: {art.manual_steps}")

    return "\n".join(lines) + "\n"


def _report_to_dict(report: CheckReport) -> dict[str, object]:
    """Serialise the report for ``--format json``."""
    return {
        "has_actionable": report.has_actionable,
        "drifted": len(report.drifted),
        "errors": len(report.errors),
        "manual": len(report.manual),
        "results": [asdict(r) for r in report.results],
    }


def main(argv: list[str] | None = None) -> int:
    """CLI entry point.

    Args:
        argv: Optional argument list (defaults to ``sys.argv``).

    Returns:
        Process exit code (1 when anything is actionable, else 0).
    """
    parser = argparse.ArgumentParser(description="Check vendored artifacts for upstream drift.")
    parser.add_argument("--format", choices=("table", "json", "markdown"), default="table", help="Output format.")
    args = parser.parse_args(argv)

    report = run_check()

    if args.format == "json":
        print(json.dumps(_report_to_dict(report), indent=2))
    elif args.format == "markdown":
        print(_render_markdown(report), end="")
    else:
        _render_table(report, Console())

    return 1 if report.has_actionable else 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
