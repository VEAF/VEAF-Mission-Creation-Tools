from importlib.metadata import PackageNotFoundError
from importlib.metadata import version as _pkg_version

import typer
from veaf_libs.i18n import set_language, t
from veaf_libs.logger import console, logger  # noqa: F401
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
    if lang:
        set_language(lang)
    from veaf_libs.user_config import get_check_updates

    if get_check_updates():
        check_for_updates(VERSION, console)
