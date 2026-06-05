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
from veaf_libs.tui import run_wizard  # noqa: E402
from veaf_tools.app import app  # noqa: E402
from veaf_tools.helpers import _is_double_clicked  # noqa: E402

if __name__ == "__main__":
    # When launched with no arguments in an interactive terminal, run the wizard.
    if len(sys.argv) == 1 and sys.stdout.isatty():
        if wizard_args := run_wizard():
            sys.argv = sys.argv[:1] + wizard_args

    auto_pause = _is_double_clicked()
    try:
        app()
    finally:
        if auto_pause:
            input(t("help.pause_msg"))
