"""VEAF support bot — the long-running service behind the Discord documentation assistant.

This package is a **service**, not part of the ``veaf-tools`` distribution: it is deployed on its
own cadence and its version is deliberately independent of ``pyproject.toml`` at the repository
root and of the two agent manifests (see ``services/support-bot/README.md``).

Ticket 01 of ``FEAT-SUPPORT-DISCORD-QA`` delivers the skeleton only: configuration, logging,
liveness/readiness reporting and a clean shutdown. The Discord gateway and the ``/ask`` command
arrive in ticket 02.
"""

from __future__ import annotations

#: Service version. Independent of the tools release; kept in step with the service's own
#: ``pyproject.toml`` by ``tests/test_version.py``.
__version__ = "0.1.0"

__all__ = ["__version__"]
