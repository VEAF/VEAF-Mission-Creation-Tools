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
        """
        try:
            handler = self._handlers[name]
        except KeyError:
            raise ActionNotFoundError(name) from None
        return handler(params)
