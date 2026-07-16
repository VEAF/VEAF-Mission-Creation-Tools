"""Scaffold a fresh VEAF mission folder from GitHub (wave 9).

Turns an **empty** folder into a ready mission folder by driving the **real VEAF binaries** the
way a maker would on first run — download the updater from the release, run it (it fetches +
installs the tools and ``published/`` into the folder), then ``veaf-tools prepare`` to lay down the
default scaffold for the chosen template. This is the "upstream" of the wave-8 composite builders:
create the folder, then fill it. See ``.backlog/FEAT-MCP-MISSION-EDITOR/PRD.md`` (wave 9).
"""

import json
import os
import subprocess
from pathlib import Path
from typing import Any

import requests
from veaf_libs import platform_assets

#: GitHub repository the release assets are fetched from.
_GITHUB_OWNER = "VEAF"
_GITHUB_REPO = "VEAF-Mission-Creation-Tools"
#: Default release tag (the rolling "latest published" pointer the updater also defaults to).
_DEFAULT_TAG = "published-latest"
#: Templates accepted here. ``custom`` is excluded: it opens an interactive TUI picker with no TTY
#: under a subprocess. The template question is the calling LLM's job (a required parameter).
_TEMPLATES = ("minimal", "standard", "full")

#: Seconds before a stalled asset download is abandoned.
_DOWNLOAD_TIMEOUT = 300


def _asset_download_url(tag: str, asset_name: str) -> str:
    """Build the stable release-download URL for an asset (no GitHub API, no rate limit)."""
    return f"https://github.com/{_GITHUB_OWNER}/{_GITHUB_REPO}/releases/download/{tag}/{asset_name}"


def _download_updater(url: str, dest: Path, token: str | None) -> None:
    """Download the updater binary at ``url`` into ``dest`` (executable bit set on Unix).

    Streamed to disk in chunks so the ~20-25 MB binary never sits fully in memory.
    """
    headers = {"Authorization": f"token {token}"} if token else {}
    with requests.get(url, headers=headers, timeout=_DOWNLOAD_TIMEOUT, stream=True) as response:
        response.raise_for_status()
        with dest.open("wb") as handle:
            for chunk in response.iter_content(chunk_size=65536):
                handle.write(chunk)
    if not platform_assets.is_windows():
        os.chmod(dest, 0o755)


def _run(cmd: list[str], cwd: Path, step: str) -> None:
    """Run ``cmd`` in ``cwd``; raise ``RuntimeError`` naming ``step`` on a non-zero exit."""
    # Not a shell command (shell=False): `cmd` is built here from binary paths we just installed
    # and fixed flags, so there is no shell to inject into and nothing external drives the argv.
    result = subprocess.run(  # nosemgrep: python.lang.security.audit.dangerous-subprocess-use-audit
        cmd, cwd=str(cwd), capture_output=True, text=True
    )
    if result.returncode != 0:
        raise RuntimeError(f"{step} failed (exit {result.returncode}): {result.stderr or result.stdout}".strip())


def _installed_version(folder: Path) -> str | None:
    """Best-effort read of the installed tools version from ``published/package.json``."""
    package_json = folder / "published" / "package.json"
    if not package_json.exists():
        return None
    try:
        return json.loads(package_json.read_text(encoding="utf-8")).get("version")
    except (OSError, json.JSONDecodeError):
        return None


def scaffold_mission(
    target_folder: str,
    *,
    template: str,
    github_token: str | None = None,
    tag: str | None = None,
) -> dict[str, Any]:
    """Scaffold a fresh VEAF mission folder in an empty ``target_folder``.

    Drives the real bootstrap: download the OS's updater asset from the release, run it (installs
    the VEAF tools + ``published/`` into the folder), then ``veaf-tools prepare --template`` to lay
    down the default scaffold.

    Args:
        target_folder: The folder to initialize. Created if missing; **must be empty**.
        template: Coverage tier — one of ``minimal`` / ``standard`` / ``full`` (``custom`` is not
            supported: its interactive picker has no TTY under a subprocess).
        github_token: Optional GitHub token, relayed to the updater (``--token``) to bypass the
            API rate limit on its own ``published.zip`` fetch.
        tag: Release tag to install from (default ``published-latest``); relayed to the updater
            (``--tag``) and used to build the updater download URL.

    Returns:
        ``{"folder", "template", "veaf_tools_version", "updater_asset"}``.

    Raises:
        ValueError: when ``template`` is invalid, the folder is not empty, or the platform has no
            updater asset.
        RuntimeError: when the updater or ``prepare`` exits non-zero, or the updater did not install
            ``veaf-tools`` / ``published/``.
    """
    if template not in _TEMPLATES:
        raise ValueError(f"Unsupported template '{template}' (expected one of: {', '.join(_TEMPLATES)}).")

    tag = tag or _DEFAULT_TAG
    folder = Path(target_folder)
    folder.mkdir(parents=True, exist_ok=True)
    if any(folder.iterdir()):
        raise ValueError(f"Target folder is not empty: {folder} — scaffolding only initializes an empty folder.")

    asset_name = platform_assets.release_updater_asset_name()
    if asset_name is None:
        raise ValueError("No VEAF updater asset for this platform — scaffolding is unsupported here.")

    # 1. Download the updater into the folder.
    updater_path = folder / platform_assets.updater_binary_name()
    _download_updater(_asset_download_url(tag, asset_name), updater_path, github_token)

    # 2. Run the updater (it fetches + installs the tools and published/ into the folder).
    updater_cmd = [str(updater_path)]
    if github_token:
        updater_cmd += ["--token", github_token]
    updater_cmd += ["--tag", tag]
    _run(updater_cmd, cwd=folder, step="updater")

    veaf_tools = folder / platform_assets.veaf_tools_binary_name()
    if not veaf_tools.exists() or not (folder / "published").is_dir():
        raise RuntimeError(
            f"The updater did not install veaf-tools / published/ into {folder} — "
            "check the updater output or the release tag."
        )

    # 3. Lay down the default scaffold for the chosen template.
    _run([str(veaf_tools), "prepare", "--template", template, "--force"], cwd=folder, step="prepare")

    return {
        "folder": str(folder),
        "template": template,
        "veaf_tools_version": _installed_version(folder),
        "updater_asset": asset_name,
    }
