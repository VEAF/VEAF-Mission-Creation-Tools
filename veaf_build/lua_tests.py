"""Run the Lua 5.1 unit test suite via `poetry run test-lua`."""

import shutil
import subprocess
import sys
from pathlib import Path
from typing import Optional

import typer
from rich.console import Console

console = Console()
app = typer.Typer(help="Run the Lua unit test suite (test/lua/test_*.lua).", no_args_is_help=False)

_PROJECT_ROOT = Path(__file__).parent.parent.resolve()
_TEST_DIR = _PROJECT_ROOT / "test" / "lua"


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


@app.command()
def run(
    filter: Optional[str] = typer.Option(None, "--filter", "-f", help="Run only suites whose filename contains this string."),
) -> None:
    """Run the Lua unit test suite (test/lua/test_*.lua)."""
    lua = _find_lua()

    test_files = sorted(_TEST_DIR.glob("test_*.lua"))
    if filter:
        test_files = [f for f in test_files if filter in f.name]

    if not test_files:
        console.print(f"[yellow]No test files found (filter={filter!r}).[/yellow]")
        raise typer.Exit(0)

    passed = 0
    failed = 0
    failures: list[str] = []

    for test_file in test_files:
        console.print(f"\n[cyan]--- {test_file.name} ---[/cyan]")
        result = subprocess.run([lua, str(test_file)])
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

    raise typer.Exit(1 if failed > 0 else 0)


def main() -> None:
    """Entry point for `poetry run test-lua`."""
    app()


if __name__ == "__main__":
    main()
