import sys
from importlib.metadata import PackageNotFoundError
from importlib.metadata import version as _pkg_version

import typer
from veaf_libs.i18n import set_language, t, tn  # noqa: F401  (tn re-exported for commands)
from veaf_libs.logger import configure_stdio_encoding, console, logger  # noqa: F401
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
    # Parse --lang early so --help is rendered in the right language.
    for _i, _a in enumerate(sys.argv[1:]):
        if _a == "--lang" and _i + 1 < len(sys.argv) - 1:
            set_language(sys.argv[_i + 2])
            break
        if _a.startswith("--lang="):
            set_language(_a.split("=", 1)[1])
            break

    from veaf_libs.tui import maybe_bridge_to_tui

    import veaf_tools.commands  # noqa: F401  — side effect: registers all commands
    from veaf_tools.helpers import _is_double_clicked

    console.print(f"[bold]veaf-tools[/bold] v{VERSION}")

    # CLI ↔ TUI bridge (CLI-TUI-BRIDGE): a bare invocation, `--tui`, or a command
    # invoked without a required option drops into the wizard — pre-filled with the
    # args already given on the command line — then runs the completed command.
    if bridged := maybe_bridge_to_tui(sys.argv[1:]):
        sys.argv = sys.argv[:1] + bridged

    auto_pause = _is_double_clicked()
    try:
        app()
    finally:
        logger.stop_status()
        if auto_pause:
            input(t("help.pause_msg"))
