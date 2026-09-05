"""Entry point: the same code path whether the process is launched directly or in a container.

The two run modes differ only in the environment they are handed — there is no "container mode" in
the code, which is what makes the documented direct-run command a real rehearsal of the deployment
rather than a different program.

``--healthcheck`` is the second face of the same module: it probes a *running* instance and exits
0/1, which is what the image's ``HEALTHCHECK`` calls. It reads only the two variables that locate
the endpoint, never the full configuration — a probe that fails because a credential is missing
would report the wrong thing.
"""

from __future__ import annotations

import asyncio
import os
import signal
import sys
import urllib.error
import urllib.request
from collections.abc import Mapping, Sequence
from types import FrameType
from typing import Final

from veaf_support_bot import __version__
from veaf_support_bot.config import (
    DEFAULT_HEALTH_PORT,
    ENV_PREFIX,
    ConfigurationError,
    SupportBotConfig,
)
from veaf_support_bot.logging_setup import configure_logging, get_logger
from veaf_support_bot.service import SupportBotService

#: ``sysexits.h`` EX_CONFIG. A supervisor can tell "this deployment is misconfigured, restarting
#: will not help" from "it crashed, try again".
EXIT_CONFIG_ERROR: Final = 78

#: Timeout of the ``--healthcheck`` probe, in seconds.
_PROBE_TIMEOUT: Final = 4.0


def _run(config: SupportBotConfig) -> None:
    """Run the service until a signal or an internal stop request.

    Args:
        config: The resolved configuration.
    """

    async def _main() -> None:
        service = SupportBotService(config)
        loop = asyncio.get_running_loop()
        for name in ("SIGINT", "SIGTERM"):
            sig = getattr(signal, name, None)
            if sig is None:
                continue
            try:
                loop.add_signal_handler(sig, service.request_stop, f"signal {name}")
            except NotImplementedError:
                # Windows has no loop signal handlers. `signal.signal` still delivers SIGINT there,
                # which is what a developer running the service directly will press.
                def _handler(_signum: int, _frame: FrameType | None, _name: str = name) -> None:
                    service.request_stop(f"signal {_name}")

                signal.signal(sig, _handler)
        await service.run()

    asyncio.run(_main())


def healthcheck(env: Mapping[str, str] | None = None) -> int:
    """Probe a running instance's readiness endpoint.

    Args:
        env: Environment mapping; defaults to ``os.environ``.

    Returns:
        ``0`` when the instance answered ``200`` on ``/readyz``, ``1`` otherwise — including when
        the configuration makes the endpoint unreachable by this probe at all.
    """
    environ = os.environ if env is None else env
    host = (environ.get(f"{ENV_PREFIX}HEALTH_HOST") or "").strip() or "127.0.0.1"
    if host in ("0.0.0.0", "::", ""):
        # The bind address is not a dial address: probe the loopback the server also answers on.
        host = "127.0.0.1"
    raw_port = (environ.get(f"{ENV_PREFIX}HEALTH_PORT") or "").strip()
    try:
        port = int(raw_port) if raw_port else DEFAULT_HEALTH_PORT
    except ValueError:
        port = DEFAULT_HEALTH_PORT

    logger = get_logger("healthcheck")
    if port == 0:
        # `HEALTH_PORT=0` asks the OS for an ephemeral port, and the number it picked exists only in
        # the running process — never in this probe's environment. Dialling port 0 would fail with a
        # connection error that reads like a dead service, so say what is actually wrong instead.
        logger.warning(
            "readiness cannot be probed on an ephemeral port",
            extra={"event": "healthcheck.ephemeral_port", "variable": f"{ENV_PREFIX}HEALTH_PORT"},
        )
        return 1
    url = f"http://{host}:{port}/readyz"
    try:
        # The URL is built here from a host and a port, never taken from user input.
        with urllib.request.urlopen(url, timeout=_PROBE_TIMEOUT) as response:
            return 0 if response.status == 200 else 1
    except (urllib.error.URLError, OSError, ValueError) as error:
        logger.warning("readiness probe failed", extra={"event": "healthcheck.failed", "url": url, "error": str(error)})
        return 1


def main(argv: Sequence[str] | None = None) -> int:
    """Run the service, or a one-shot probe.

    Args:
        argv: Command-line arguments without the program name; defaults to ``sys.argv[1:]``.

    Returns:
        The process exit code: ``0`` on a clean stop, :data:`EXIT_CONFIG_ERROR` when the environment
        does not describe a runnable service, ``2`` on an unknown argument.
    """
    args = list(sys.argv[1:] if argv is None else argv)

    if "--version" in args:
        configure_logging(log_format="text")
        get_logger("cli").info(__version__, extra={"event": "cli.version", "version": __version__})
        return 0

    if "--healthcheck" in args:
        configure_logging(log_format="text")
        return healthcheck()

    unknown = [arg for arg in args if arg.startswith("-")]
    if unknown:
        configure_logging(log_format="text")
        get_logger("cli").error("unknown argument", extra={"event": "cli.unknown_argument", "arguments": unknown})
        return 2

    try:
        config = SupportBotConfig.from_env()
    except ConfigurationError as error:
        # Configured before the configuration is known, on purpose: the point of this branch is that
        # the failure is *visible*, and text on stdout is what a first deployment reads.
        configure_logging(log_format="text")
        get_logger("cli").critical(str(error), extra={"event": "config.invalid"})
        return EXIT_CONFIG_ERROR

    configure_logging(level=config.log_level, log_format=config.log_format)
    _run(config)
    return 0
