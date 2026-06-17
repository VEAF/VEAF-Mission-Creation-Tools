import sys

from veaf_libs.i18n import set_language, t

# Parse --lang early from sys.argv so that --help is also rendered in the
# requested language (Typer's --help is eager and fires before main_callback).
for _i, _a in enumerate(sys.argv[1:]):
    if _a == "--lang" and _i + 1 < len(sys.argv) - 1:
        set_language(sys.argv[_i + 2])
        break
    if _a.startswith("--lang="):
        set_language(_a.split("=", 1)[1])
        break

# These imports must come after the lang-setup block above.
import veaf_tools.commands  # noqa: E402, F401  — side effect: registers all commands
from veaf_libs.logger import console  # noqa: E402
from veaf_libs.tui import maybe_bridge_to_tui  # noqa: E402
from veaf_tools.app import VERSION, app  # noqa: E402
from veaf_tools.helpers import _is_double_clicked  # noqa: E402

if __name__ == "__main__":
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
        if auto_pause:
            input(t("help.pause_msg"))
