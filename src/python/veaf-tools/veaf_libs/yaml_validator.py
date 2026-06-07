"""YAML file validation with user-friendly, localised error reporting."""

from pathlib import Path

import yaml

from veaf_libs.i18n import t
from veaf_libs.logger import logger


def _hint_key(problem: str) -> str:
    """Return the i18n hint key that best matches the PyYAML error problem string.

    Args:
        problem: The raw problem string from a yaml.YAMLError exception.

    Returns:
        An i18n key from the ``yaml.error.hint.*`` namespace.
    """
    if "cannot start any token" in problem or "\t" in problem:
        return "yaml.error.hint.tab"
    if "could not find expected ':'" in problem:
        return "yaml.error.hint.colon"
    if any(kw in problem for kw in ("block mapping", "block end", "block sequence")):
        return "yaml.error.hint.indentation"
    return "yaml.error.hint.generic"


def validate_yaml_file(path: Path) -> None:
    """Validate a YAML file for syntax errors and report them in plain language.

    Tries to parse *path* with :func:`yaml.safe_load`. If a
    :exc:`yaml.YAMLError` is raised, the function builds a localised,
    human-readable error message (file name, line, column, contextual hint)
    and forwards it to :func:`veaf_libs.logger.logger.error`, which prints
    the message and raises :exc:`typer.Abort` to terminate the CLI cleanly.

    Args:
        path: Path to the YAML file to validate.
    """
    try:
        with path.open(encoding="utf-8") as fh:
            yaml.safe_load(fh)
    except yaml.YAMLError as exc:
        problem_mark = getattr(exc, "problem_mark", None)
        context_mark = getattr(exc, "context_mark", None)
        problem: str = getattr(exc, "problem", None) or str(exc)

        if problem_mark is not None:
            line = problem_mark.line + 1
            col = problem_mark.column + 1
            msg = t("yaml.error.syntax", filename=path.name, line=line, col=col)
        else:
            msg = t("yaml.error.syntax_unknown", filename=path.name)

        if context_mark is not None and (
            problem_mark is None or context_mark.line != problem_mark.line
        ):
            msg += "\n" + t(
                "yaml.error.context",
                line=context_mark.line + 1,
                col=context_mark.column + 1,
            )

        msg += "\n" + t(_hint_key(problem))

        logger.error(msg)
