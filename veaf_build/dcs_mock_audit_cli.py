"""``audit-dcs-mocks`` -- report DCS calls used by VEAF Lua but not mocked.

Thin CLI around :mod:`veaf_libs.dcs_mock_audit`. It locates the inputs (the
vendored schema, ``test/lua/dcs_mocks.lua`` and ``src/scripts/veaf/*.lua``), runs
the presence-only audit and renders the result as a Rich table (humans), JSON or
GitHub-flavoured Markdown (CI summary).

Exit code is non-zero when the real gap (``missing``) is non-empty; whether that
fails a build is decided by the caller (the CI job runs it non-blocking).

Usage:
    poetry run audit-dcs-mocks                 # human table
    poetry run audit-dcs-mocks --format json   # machine-readable
    poetry run audit-dcs-mocks --format markdown >> "$GITHUB_STEP_SUMMARY"
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import asdict
from pathlib import Path

from rich.console import Console
from rich.table import Table
from veaf_libs.bundled_data import read_bundled_text  # type: ignore[import-not-found]
from veaf_libs.dcs_mock_audit import AuditResult, audit_mocks  # type: ignore[import-not-found]

_REPO_ROOT = Path(__file__).resolve().parent.parent
_MOCK_PATH = _REPO_ROOT / "test" / "lua" / "dcs_mocks.lua"
_VEAF_SCRIPTS_DIR = _REPO_ROOT / "src" / "scripts" / "veaf"
_SCHEMA_PARTS = ("data", "dcs-schema", "dcs-world-api-schema.json")


def run_audit() -> AuditResult:
    """Load the inputs from disk and run the audit.

    Returns:
        The :class:`~veaf_libs.dcs_mock_audit.AuditResult`.
    """
    schema_json = read_bundled_text("veaf_libs", *_SCHEMA_PARTS)
    mock_lua = _MOCK_PATH.read_text(encoding="utf-8")
    sources = [path.read_text(encoding="utf-8") for path in sorted(_VEAF_SCRIPTS_DIR.glob("*.lua"))]
    return audit_mocks(schema_json=schema_json, mock_lua=mock_lua, veaf_sources=sources)


def _render_table(result: AuditResult, console: Console) -> None:
    """Render the audit result as Rich tables on ``console``."""
    sections = (
        ("Missing mocks (used + in-schema + NOT mocked)", "red", result.missing),
        ("Used but not in schema (typo / undocumented)", "yellow", result.unknown),
        ("Mocked but never used (cleanup candidate)", "cyan", result.unused),
    )
    for title, style, items in sections:
        table = Table(title=title, title_style=f"bold {style}", show_header=True, expand=False)
        table.add_column("#", justify="right", style="dim")
        table.add_column("DCS call", style=style)
        for index, name in enumerate(items, start=1):
            table.add_row(str(index), name)
        if not items:
            table.add_row("-", "[dim]none[/dim]")
        console.print(table)
    verdict = (
        f"[bold red]GAP: {len(result.missing)} DCS call(s) used by VEAF are not mocked.[/bold red]"
        if result.has_gap
        else "[bold green]OK: every DCS call used by VEAF is mocked.[/bold green]"
    )
    console.print(verdict)


def _render_markdown(result: AuditResult) -> str:
    """Render the audit result as a GitHub-flavoured Markdown summary."""
    lines = ["## DCS mock-coverage audit", ""]
    if result.has_gap:
        lines.append(f"⚠️ **{len(result.missing)} DCS call(s) used by VEAF are not mocked.**")
    else:
        lines.append("✅ Every DCS call used by VEAF is mocked.")
    sections = (
        ("Missing mocks (used + in-schema + NOT mocked)", result.missing),
        ("Used but not in schema (typo / undocumented)", result.unknown),
        ("Mocked but never used (cleanup candidate)", result.unused),
    )
    for title, items in sections:
        lines += ["", f"### {title} ({len(items)})", ""]
        lines += [f"- `{name}`" for name in items] if items else ["_none_"]
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    """CLI entry point.

    Args:
        argv: Optional argument list (defaults to ``sys.argv``).

    Returns:
        Process exit code (1 when the real gap is non-empty, else 0).
    """
    parser = argparse.ArgumentParser(description="Audit DCS-mock coverage of the VEAF Lua runtime.")
    parser.add_argument(
        "--format",
        choices=("table", "json", "markdown"),
        default="table",
        help="Output format (default: table).",
    )
    args = parser.parse_args(argv)

    result = run_audit()

    if args.format == "json":
        print(json.dumps(asdict(result), indent=2))
    elif args.format == "markdown":
        print(_render_markdown(result), end="")
    else:
        _render_table(result, Console())

    return 1 if result.has_gap else 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
