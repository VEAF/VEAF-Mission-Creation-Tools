"""YAML file validation with user-friendly, localised error reporting."""

from functools import lru_cache
from pathlib import Path

import yaml

from veaf_libs.i18n import t
from veaf_libs.logger import logger

#: Legacy top-level sections removed by MODULES-UNIFY (hard break).
_REMOVED_SECTIONS: tuple[str, ...] = ("external_modules", "qra")


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
    msg = check_yaml_syntax(path)
    if msg is not None:
        logger.error(msg)


def check_yaml_syntax(path: Path) -> str | None:
    """Return a localised YAML syntax-error message for *path*, or ``None`` if it parses.

    Non-aborting counterpart of :func:`validate_yaml_file` — used by the pre-build
    ``validate`` command to aggregate issues instead of terminating on the first one.

    Args:
        path: Path to the YAML file to check.

    Returns:
        A human-readable, localised error message (file, line, column, hint) when the
        file fails to parse; ``None`` when it is syntactically valid.
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

        if context_mark is not None and (problem_mark is None or context_mark.line != problem_mark.line):
            msg += "\n" + t(
                "yaml.error.context",
                line=context_mark.line + 1,
                col=context_mark.column + 1,
            )

        msg += "\n" + t(_hint_key(problem))
        return msg
    return None


@lru_cache(maxsize=1)
def _known_module_keys() -> frozenset[str]:
    """Return the set of valid ``modules:`` keys (VEAF + community), upper-cased.

    Cached: the VEAF module and community-script lists are static per process.
    """
    from mission_tools.mission_constants import get_community_script_files

    from veaf_libs.lua_config_generator import get_modules

    keys = {m["id"].upper() for m in get_modules()}
    keys |= {s["id"].upper() for s in get_community_script_files()}
    return frozenset(keys)


def validate_modules_semantics(yaml_data: dict) -> None:
    """Semantically validate the unified ``modules:`` block of a mission.yaml.

    Distinct from :func:`validate_yaml_file` (which only checks YAML *syntax*),
    this checks the *meaning* of the ``modules:`` block so that a typo no longer
    silently produces wrong Lua (MODULES-UNIFY-006):

    - a removed top-level section (``external_modules:`` / ``qra:``) → error;
    - an unknown module key → error;
    - a module value that is neither bool, null nor a mapping → error;
    - a wrongly-typed ``enabled`` / ``logLevel`` → error;
    - an unrecognised ``init:`` parameter → warning.

    Errors are aggregated and reported via :func:`logger.error` (which aborts the
    CLI); warnings are emitted individually and do not abort.

    Args:
        yaml_data: The parsed (un-normalized) mission.yaml content.
    """
    errors, warnings = collect_module_issues(yaml_data)
    for warning in warnings:
        logger.warning(warning)
    if errors:
        logger.error("\n".join(errors))


def collect_module_issues(yaml_data: dict) -> tuple[list[str], list[str]]:
    """Collect ``modules:`` semantic issues without aborting (errors, warnings).

    Non-aborting counterpart of :func:`validate_modules_semantics` — used by the
    pre-build ``validate`` command to aggregate issues. Same checks; the messages are
    returned instead of being sent to the logger.

    Args:
        yaml_data: The parsed (un-normalized) mission.yaml content.

    Returns:
        A ``(errors, warnings)`` tuple of localised message strings.
    """
    from veaf_libs.lua_config_generator import _MODULE_INIT_PARAMS

    errors: list[str] = []
    warnings: list[str] = []

    for section in _REMOVED_SECTIONS:
        if section in yaml_data:
            errors.append(t("yaml.semantic.removed_section", section=section))

    modules = yaml_data.get("modules")
    if isinstance(modules, dict):
        known = _known_module_keys()
        for key, cfg in modules.items():
            if key.upper() not in known:
                errors.append(t("yaml.semantic.unknown_module", module=key))
                continue
            if cfg is None or isinstance(cfg, bool):
                continue
            if not isinstance(cfg, dict):
                errors.append(t("yaml.semantic.wrong_type", module=key, type=type(cfg).__name__))
                continue
            if "enabled" in cfg and not isinstance(cfg["enabled"], bool):
                errors.append(t("yaml.semantic.bad_enabled", module=key, type=type(cfg["enabled"]).__name__))
            if "logLevel" in cfg and not isinstance(cfg["logLevel"], str):
                errors.append(t("yaml.semantic.bad_loglevel", module=key, type=type(cfg["logLevel"]).__name__))
            if "settings" in cfg and not isinstance(cfg["settings"], dict):
                errors.append(t("yaml.semantic.bad_settings", module=key, type=type(cfg["settings"]).__name__))
            init = cfg.get("init")
            if isinstance(init, dict):
                allowed = {param for param, _ in _MODULE_INIT_PARAMS.get(key.upper(), [])}
                for param in init:
                    if param not in allowed:
                        warnings.append(t("yaml.semantic.unknown_init_param", module=key, param=param))

    return errors, warnings
