"""Registry of MCP actions exposed by the mission-editing server."""

from collections.abc import Callable
from typing import Any

from veaf_mission_mcp.models import ActionSpec

ActionHandler = Callable[[dict[str, Any]], Any]


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

    def register(self, spec: ActionSpec, handler: ActionHandler) -> None:
        """Register an action under its spec's name.

        Args:
            spec: The action's name, description and parameter JSON Schema.
            handler: Callable invoked by ``run_action`` with the ``params`` dict.
        """
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
        _check_parameters(name, self._specs[name].parameters_schema or {}, params)
        return handler(params)


def _check_parameters(name: str, schema: dict[str, Any], params: dict[str, Any]) -> None:
    """Refuse missing required parameters and undeclared ones, naming them.

    Only the top level: each handler still validates the values, as it always has. An undeclared
    parameter is refused because it is nearly always a misspelt one — ``miz_path`` where the action
    takes ``mission_path`` — and the handler would otherwise fail on the key it did not find.

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
