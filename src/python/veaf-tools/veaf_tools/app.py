import sys
from importlib.metadata import PackageNotFoundError
from importlib.metadata import version as _pkg_version

import typer
from veaf_libs.i18n import set_language, set_language_from_argv, t, tn  # noqa: F401  (tn re-exported for commands)
from veaf_libs.logger import configure_stdio_encoding, console, install_excepthook, logger  # noqa: F401
from veaf_libs.update_checker import check_for_updates

try:
    VERSION: str = _pkg_version("veaf-tools")
except PackageNotFoundError:
    try:
        from veaf_tools._version import __version__ as _fallback

        VERSION = _fallback
    except ImportError:
        VERSION = "unknown"

README_HELP: str = t("help.readme")
PAUSE_HELP: str = t("help.pause")
VERBOSE_HELP: str = t("help.verbose")

DEFAULT_MISSION_FILE = "mission.miz"
DEFAULT_PRESETS_FILE = "./src/presets.yaml"

app = typer.Typer(no_args_is_help=True)

#: CLI commands driven by tooling, not the interactive TUI wizard/double-click (they would block or
#: make no sense from a menu). The TUI-completeness guard excludes these. Single source of truth.
MACHINE_ONLY_COMMANDS: set[str] = {"mcp", "capture-map", "inject-bridge", "smoke-test"}


@app.callback(help=t("app.description"))
def main_callback(
    lang: str | None = typer.Option(None, "--lang", help=t("help.lang")),
) -> None:
    # Force UTF-8 stdout/stderr first so no command output (reports, the chatbot
    # answer, …) is truncated by a UnicodeEncodeError under a legacy Windows code page.
    configure_stdio_encoding()
    if lang:
        set_language(lang)
    from veaf_libs.user_config import get_check_updates

    if get_check_updates():
        check_for_updates(VERSION, console)


def main() -> None:
    """Run the CLI. **The** implementation: both entry points end up here.

    The frozen-executable entry script (``src/python/veaf-tools/veaf-tools.py``, what
    PyInstaller reads) used to be a copy of this function, and the copy is what let the two
    diverge: it never grew the :func:`build_cli_tree` call, so ``veaf-tools.exe content
    extract-aircraft-groups`` did not exist while ``poetry run veaf-tools`` had it
    (FIX-EXE-COMMAND-TREE). It now calls this function instead.
    """
    # A crash must leave something behind: the traceback goes to the log file before it reaches
    # stderr, where it used to scroll away with nothing kept (FEAT-SUPPORT-DIAGNOSTIC ticket 02).
    install_excepthook()

    # Parse --lang early so --help is rendered in the right language.
    set_language_from_argv()

    from veaf_libs.tui import maybe_bridge_to_tui

    import veaf_tools.commands  # noqa: F401  — side effect: registers all commands
    from veaf_tools.command_tree import build_cli_tree

    # Reshape the flat registrations into the themed tree. Every flat name survives as a
    # hidden alias, so existing scripts and doc pages keep working while --help shows the tree.
    build_cli_tree(app)
    from veaf_tools.helpers import should_auto_pause

    console.print(f"[bold]veaf-tools[/bold] v{VERSION}")

    # CLI ↔ TUI bridge (CLI-TUI-BRIDGE): a bare invocation, `--tui`, or a command
    # invoked without a required option drops into the wizard — pre-filled with the
    # args already given on the command line — then runs the completed command.
    if bridged := maybe_bridge_to_tui(sys.argv[1:]):
        sys.argv = sys.argv[:1] + bridged

    auto_pause = should_auto_pause()
    try:
        app()
    finally:
        logger.stop_status()
        if auto_pause:
            input(t("help.pause_msg"))
