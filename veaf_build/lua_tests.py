"""Run the Lua 5.1 unit test suite via `poetry run test-lua`."""

import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Optional

import typer
from rich.console import Console
from rich.table import Table

console = Console()
app = typer.Typer(help="Run the Lua unit test suite (test/lua/test_*.lua).", no_args_is_help=False)

_PROJECT_ROOT = Path(__file__).parent.parent.resolve()
_TEST_DIR = _PROJECT_ROOT / "test" / "lua"
_STATS_FILE = _PROJECT_ROOT / "luacov.stats.out"
_REPORT_FILE = _PROJECT_ROOT / "luacov.report.out"

# Matches a coverage summary line: <path> <hits> <missed> <pct>%
# Note: separator is 1+ spaces (short paths get only 1 space before the numbers).
_COVERAGE_LINE_RE = re.compile(r"^(.+?)\s+(\d+)\s+(\d+)\s+([\d.]+%)\s*$")
_VEAF_SRC = _PROJECT_ROOT / "src" / "scripts" / "veaf"


def _find_lua() -> str:
    """Return the path to a Lua 5.1 interpreter, or raise if none found."""
    for candidate in ["lua5.1", "lua"]:
        if shutil.which(candidate):
            return candidate
    if sys.platform == "win32":
        fallback = Path(r"C:\Program Files (x86)\Lua\5.1\lua.exe")
        if fallback.exists():
            return str(fallback)
    raise typer.BadParameter(
        "Lua 5.1 interpreter not found. Install lua5.1 (Linux/macOS) "
        r"or Lua 5.1 from https://luabinaries.sourceforge.net/ (Windows, "
        r"default path: C:\Program Files (x86)\Lua\5.1\lua.exe)."
    )


def _luacov_module_available(lua: str) -> bool:
    """Return True if the luacov Lua module can be loaded."""
    result = subprocess.run(
        [lua, "-e", "require('luacov'); print('ok')"],
        capture_output=True,
        text=True,
        cwd=_PROJECT_ROOT,
    )
    return result.returncode == 0 and "ok" in result.stdout


def _run_luacov_reporter(lua: str) -> bool:
    """Generate luacov.report.out from luacov.stats.out. Returns True on success."""
    if shutil.which("luacov"):
        # shell=True required on Windows so .bat wrappers (luarocks) are executed correctly.
        result = subprocess.run(
            "luacov" if sys.platform == "win32" else ["luacov"],
            cwd=_PROJECT_ROOT,
            capture_output=True,
            shell=sys.platform == "win32",
        )
        return result.returncode == 0
    # luacov CLI not on PATH — invoke the reporter via the Lua module directly
    result = subprocess.run(
        [lua, "-e", "require('luacov.runner').run()"],
        cwd=_PROJECT_ROOT,
        capture_output=True,
    )
    return result.returncode == 0


def _pct_color(pct_str: str) -> str:
    val = float(pct_str.rstrip("%"))
    if val >= 80:
        return f"[green]{pct_str}[/green]"
    elif val >= 60:
        return f"[yellow]{pct_str}[/yellow]"
    return f"[red]{pct_str}[/red]"


def _display_coverage_report() -> None:
    if not _REPORT_FILE.exists():
        console.print("[yellow]No coverage report generated.[/yellow]")
        return

    table = Table(title="Lua Coverage Report")
    table.add_column("File", style="cyan")
    table.add_column("Hits", justify="right")
    table.add_column("Missed", justify="right")
    table.add_column("Coverage", justify="right")

    rows = []
    for line in _REPORT_FILE.read_text(encoding="utf-8").splitlines():
        m = _COVERAGE_LINE_RE.match(line)
        if not m:
            continue
        path_str, hits, missed = m.group(1).strip(), int(m.group(2)), int(m.group(3))
        if path_str.lower() == "total":
            continue  # we compute our own total from filtered rows

        # Resolve to canonical absolute path (handles `..` in dofile-computed paths)
        raw = Path(path_str)
        resolved = raw.resolve() if raw.is_absolute() else (_PROJECT_ROOT / raw).resolve()

        # Only show VEAF source modules (skip luaunit, dcs_mocks, test files, etc.)
        try:
            resolved.relative_to(_VEAF_SRC)
        except ValueError:
            continue

        try:
            display = str(resolved.relative_to(_PROJECT_ROOT))
        except ValueError:
            display = str(resolved)

        rows.append((display, hits, missed))

    if not rows:
        console.print("[yellow]No coverage data found for src/scripts/veaf/.[/yellow]")
        return

    for display, hits, missed in rows:
        total = hits + missed
        pct = f"{100 * hits / total:.2f}%" if total > 0 else "N/A"
        table.add_row(display, str(hits), str(missed), _pct_color(pct))

    total_hits = sum(r[1] for r in rows)
    total_missed = sum(r[2] for r in rows)
    total_lines = total_hits + total_missed
    if total_lines > 0:
        total_pct = f"{100 * total_hits / total_lines:.2f}%"
        table.add_row(
            "[bold]TOTAL[/bold]",
            f"[bold]{total_hits}[/bold]",
            f"[bold]{total_missed}[/bold]",
            _pct_color(total_pct),
        )

    console.print(table)


@app.command()
def run(
    suite_filter: Optional[str] = typer.Option(None, "--filter", "-f", help="Run only suites whose filename contains this string."),
    coverage: bool = typer.Option(False, "--coverage", "-c", help="Collect and display Lua line coverage via luacov (requires: luarocks install luacov)."),
) -> None:
    """Run the Lua unit test suite (test/lua/test_*.lua)."""
    lua = _find_lua()

    if coverage and not _luacov_module_available(lua):
        console.print(
            "[red]luacov not found.[/red] Install it with:\n"
            "  [cyan]luarocks install luacov[/cyan]  (Linux / DevContainer)\n"
            "  [cyan]luarocks install luacov[/cyan]  (Windows — may need admin rights)"
        )
        raise typer.Exit(1)

    test_files = sorted(_TEST_DIR.glob("test_*.lua"))
    if suite_filter:
        test_files = [f for f in test_files if suite_filter in f.name]

    if not test_files:
        console.print(f"[yellow]No test files found (filter={suite_filter!r}).[/yellow]")
        raise typer.Exit(0)

    if coverage:
        _STATS_FILE.unlink(missing_ok=True)

    passed = 0
    failed = 0
    failures: list[str] = []

    lua_cmd = [lua, "-l", "luacov"] if coverage else [lua]

    for test_file in test_files:
        console.print(f"\n[cyan]--- {test_file.name} ---[/cyan]")
        result = subprocess.run([*lua_cmd, str(test_file)], cwd=_PROJECT_ROOT)
        if result.returncode == 0:
            passed += 1
        else:
            failed += 1
            failures.append(test_file.name)

    console.print("\n[white]======================================[/white]")
    if failed == 0:
        console.print(f"[green]ALL {passed} SUITE(S) PASSED[/green]")
    else:
        console.print(f"[red]{passed} suite(s) passed, {failed} FAILED:[/red]")
        for name in failures:
            console.print(f"[red]  - {name}[/red]")
    console.print("[white]======================================[/white]")

    if coverage:
        console.print("\nGenerating coverage report...")
        if _run_luacov_reporter(lua):
            _display_coverage_report()
        else:
            console.print("[yellow]Coverage report generation failed.[/yellow]")
        _STATS_FILE.unlink(missing_ok=True)

    raise typer.Exit(1 if failed > 0 else 0)


def main() -> None:
    """Entry point for `poetry run test-lua`."""
    app()


if __name__ == "__main__":
    main()
