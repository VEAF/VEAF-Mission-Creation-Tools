"""Registry of MCP actions exposed by the mission-editing server."""

from collections.abc import Callable
from pathlib import Path
from typing import Any

from veaf_mission_mcp.models import ActionSpec

ActionHandler = Callable[[dict[str, Any]], Any]

#: The one name under which every action takes "the mission folder or `.miz`".
#:
#: Until 2026-09-28 the catalogue used five: `miz_path` (17 actions), `target` (9), `folder_path`
#: (6), `mission_path` (4) — all meaning the same thing — and `mission_yaml_path` (6), which names a
#: different file. Running actions in batches, an agent lost a retry each time it guessed wrong
#: (FIX-OPEN-TRAINING-PROMPT-FINDINGS ticket 05). The catalogue now publishes `mission_path` for all
#: of them and translates it back to the handler's own key, so no handler changed.
MISSION_PARAMETER = "mission_path"

#: The former names, still accepted so no caller breaks.
MISSION_PARAMETER_ALIASES: tuple[str, ...] = ("miz_path", "target", "folder_path")

#: Kept under its own name: it names the mission's `mission.yaml`, not the mission. A
#: `mission_path` given to an action that takes it is read as the folder holding that file.
MISSION_YAML_PARAMETER = "mission_yaml_path"


#: The longest summary ``list_catalog`` gives an action, in characters.
_SUMMARY_MAX = 200


def summary(description: str) -> str:
    """Return a description's first sentence, cut at :data:`_SUMMARY_MAX` characters.

    Args:
        description: The action's full description.

    Returns:
        Its first sentence; the start of it, ended by an ellipsis, when the sentence is longer.
    """
    text = " ".join(description.split())
    end = text.find(". ")
    first = text if end < 0 else text[: end + 1]
    return first if len(first) <= _SUMMARY_MAX else first[: _SUMMARY_MAX - 1].rstrip() + "…"


class ActionNotFoundError(Exception):
    """Raised by ``describe_action``/``run_action`` for an unregistered action name."""

    def __init__(self, name: str) -> None:
        super().__init__(f"Unknown action: {name!r}")
        self.name = name


class ActionCatalog:
    """Registers and dispatches the actions exposed by the mission-editing MCP server."""

    def __init__(self) -> None:
        self._specs: dict[str, ActionSpec] = {}
        self._handlers: dict[str, ActionHandler] = {}
        self._mission_keys: dict[str, str] = {}

    def register(self, spec: ActionSpec, handler: ActionHandler) -> None:
        """Register an action under its spec's name.

        Args:
            spec: The action's name, description and parameter JSON Schema.
            handler: Callable invoked by ``run_action`` with the ``params`` dict.
        """
        properties = (spec.parameters_schema or {}).get("properties") or {}
        native = next((key for key in (MISSION_PARAMETER, *MISSION_PARAMETER_ALIASES) if key in properties), None)
        if native is not None:
            self._mission_keys[spec.name] = native
            if native != MISSION_PARAMETER:
                spec = spec.model_copy(update={"parameters_schema": _renamed(spec.parameters_schema, native)})
        self._specs[spec.name] = spec
        self._handlers[spec.name] = handler

    def list_catalog(self) -> list[ActionSpec]:
        """Return every registered action's spec, in registration order.

        Returns:
            The list of registered action specs.
        """
        return list(self._specs.values())

    def describe_action(self, name: str) -> ActionSpec:
        """Return one action's spec.

        Args:
            name: The action's registered name.

        Returns:
            The action's spec.

        Raises:
            ActionNotFoundError: If no action is registered under ``name``.
        """
        try:
            return self._specs[name]
        except KeyError:
            raise ActionNotFoundError(name) from None

    def run_action(self, name: str, params: dict[str, Any]) -> Any:
        """Dispatch to a registered action's handler.

        Args:
            name: The action's registered name.
            params: Parameters forwarded to the handler as-is.

        Returns:
            Whatever the handler returns.

        Raises:
            ActionNotFoundError: If no action is registered under ``name``.
            ValueError: If a required parameter is missing, or one the schema does not declare is
                passed — named, with the expected ones, rather than surfacing later as a bare
                ``KeyError`` from inside the handler.
        """
        try:
            handler = self._handlers[name]
        except KeyError:
            raise ActionNotFoundError(name) from None
        schema = self._specs[name].parameters_schema or {}
        params = _published_mission_key(name, params, schema)
        _check_parameters(name, schema, params)
        native = self._mission_keys.get(name)
        if native is not None and native != MISSION_PARAMETER and MISSION_PARAMETER in params:
            params = {native if key == MISSION_PARAMETER else key: value for key, value in params.items()}
        return handler(params)


def _renamed(schema: dict[str, Any], native: str) -> dict[str, Any]:
    """Return a copy of `schema` publishing its `native` mission key as :data:`MISSION_PARAMETER`.

    Args:
        schema: The action's parameter JSON Schema.
        native: The key the handler reads.

    Returns:
        The schema with that property, and its entry in ``required``, renamed in place of order.
    """
    renamed = dict(schema)
    renamed["properties"] = {
        MISSION_PARAMETER if key == native else key: value for key, value in schema["properties"].items()
    }
    if "required" in schema:
        renamed["required"] = [MISSION_PARAMETER if key == native else key for key in schema["required"]]
    return renamed


def _published_mission_key(name: str, params: dict[str, Any], schema: dict[str, Any]) -> dict[str, Any]:
    """Bring whichever mission name the caller used back to the one the schema publishes.

    Args:
        name: The action's name, for the message.
        params: The parameters received.
        schema: The action's published parameter JSON Schema.

    Returns:
        ``params`` with the mission under the published key; unchanged when the action takes no
        mission, or when the caller already used the published key alone.

    Raises:
        ValueError: If the mission is given twice, under two names, with two different values.
    """
    properties = schema.get("properties") or {}
    names = [key for key in (MISSION_PARAMETER, *MISSION_PARAMETER_ALIASES) if key in params]
    if MISSION_PARAMETER in properties:
        published = MISSION_PARAMETER
    elif MISSION_YAML_PARAMETER in properties and MISSION_YAML_PARAMETER not in params and names:
        published = MISSION_YAML_PARAMETER
    else:
        return params
    names = [key for key in names if key != published]
    if not names:
        return params
    values = {str(params[key]) for key in names} | ({str(params[published])} if published in params else set())
    if len(values) > 1:
        raise ValueError(f"{name}: the mission is given twice with different values ({', '.join(sorted(names))})")
    value = params[names[0]]
    if published == MISSION_YAML_PARAMETER and Path(str(value)).is_dir():
        value = str(Path(str(value)) / "mission.yaml")
    result = {key: item for key, item in params.items() if key not in names}
    result[published] = value
    return result


def _check_parameters(name: str, schema: dict[str, Any], params: dict[str, Any]) -> None:
    """Refuse missing required parameters and undeclared ones, naming them.

    Only the top level: each handler still validates the values, as it always has. An undeclared
    parameter is refused because it is nearly always a misspelt one — ``group`` where the action
    takes ``group_name`` — and the handler would otherwise fail on the key it did not find. (The
    mission's former names are not misspellings: :func:`_published_mission_key` translates them first.)

    Args:
        name: The action's name, for the message.
        schema: The action's parameter JSON Schema.
        params: The parameters received.

    Raises:
        ValueError: On a missing required parameter or an undeclared one.
    """
    properties = schema.get("properties")
    if not isinstance(properties, dict):
        return
    problems: list[str] = []
    missing = [key for key in schema.get("required", []) if key not in params]
    if missing:
        problems.append(f"missing required parameter(s) {', '.join(missing)}")
    # A schema declaring no property says nothing about which ones are allowed.
    if properties and schema.get("additionalProperties") is not True:
        unknown = sorted(key for key in params if key not in properties)
        if unknown:
            problems.append(f"unknown parameter(s) {', '.join(unknown)}")
    if problems:
        # Both in one message: a misspelt key is at once unknown and the required one missing, and
        # the agent needs to see the two side by side to fix it.
        raise ValueError(f"{name}: {'; '.join(problems)}; expected {', '.join(sorted(properties))}")
