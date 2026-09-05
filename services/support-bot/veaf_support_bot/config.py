"""Configuration of the support bot, read from the environment and nowhere else.

Two properties this module exists to guarantee:

* **No secret in the repository.** Every credential arrives through an environment variable. The
  repository carries ``.env.example`` with placeholder values and a ``.gitignore`` entry for the
  real ``.env``; nothing else.
* **A missing variable fails at startup, loudly.** :meth:`SupportBotConfig.from_env` collects
  *every* problem it finds and raises a single :class:`ConfigurationError` naming all of them, so an
  operator fixes one deployment rather than discovering the second mistake after the first restart.
  A service that starts and only fails on the first user question is the failure mode this avoids.

The token never reaches a log line: :meth:`SupportBotConfig.redacted` masks it, and ``repr`` of the
configuration object is redacted too, so an accidental ``logger.info(config)`` or a stack trace
cannot leak it.
"""

from __future__ import annotations

import os
from collections.abc import Mapping
from dataclasses import dataclass
from typing import Any, Final
from urllib.parse import urlparse

#: Prefix shared by every variable the service reads.
ENV_PREFIX: Final = "SUPPORT_BOT_"

#: Production Cloudflare Worker endpoint, the same one ``veaf-tools ask`` talks to.
DEFAULT_WORKER_ENDPOINT: Final = "https://veaf-docs-chatbot.veaf.workers.dev/chat"

#: Value of the ``X-VEAF-Client`` header the Worker uses to tell callers apart.
DEFAULT_WORKER_CLIENT: Final = "discord"

#: Loopback by default: the health endpoint is an operator interface, not a public one. The
#: container image overrides it to ``0.0.0.0`` because a container's loopback is unreachable from
#: the host.
DEFAULT_HEALTH_HOST: Final = "127.0.0.1"

DEFAULT_HEALTH_PORT: Final = 8081
DEFAULT_LOG_LEVEL: Final = "INFO"
DEFAULT_LOG_FORMAT: Final = "json"
DEFAULT_HEARTBEAT_SECONDS: Final = 60.0
DEFAULT_SHUTDOWN_GRACE_SECONDS: Final = 10.0

#: Accepted values of ``SUPPORT_BOT_LOG_FORMAT``.
LOG_FORMATS: Final = ("json", "text")

#: Accepted values of ``SUPPORT_BOT_LOG_LEVEL``.
LOG_LEVELS: Final = ("CRITICAL", "ERROR", "WARNING", "INFO", "DEBUG")

_TRUE: Final = frozenset({"1", "true", "yes", "on"})
_FALSE: Final = frozenset({"0", "false", "no", "off"})

#: What a redacted secret looks like in a log line or a ``repr``.
REDACTED: Final = "***redacted***"


class ConfigurationError(RuntimeError):
    """The environment does not describe a runnable service.

    Carries every problem found in one message rather than the first one, so a deployment is fixed
    in a single pass.
    """


class _Reader:
    """Collects configuration problems instead of raising on the first one."""

    def __init__(self, env: Mapping[str, str]) -> None:
        """Initialize the reader.

        Args:
            env: The environment mapping to read from.
        """
        self._env = env
        self.problems: list[str] = []

    def _raw(self, name: str) -> str | None:
        """Return the trimmed value of ``SUPPORT_BOT_<name>``, or None when unset or blank.

        Args:
            name: Variable name without the :data:`ENV_PREFIX` prefix.

        Returns:
            The trimmed value, or ``None`` when the variable is absent or holds only whitespace.
        """
        value = self._env.get(ENV_PREFIX + name)
        if value is None:
            return None
        value = value.strip()
        return value or None

    def required(self, name: str) -> str:
        """Return a mandatory string value, recording a problem when it is missing.

        Args:
            name: Variable name without the prefix.

        Returns:
            The value, or an empty string when it is missing (the caller still gets a usable object;
            :meth:`raise_if_broken` is what stops the startup).
        """
        value = self._raw(name)
        if value is None:
            self.problems.append(f"{ENV_PREFIX}{name} is required but not set")
            return ""
        return value

    def text(self, name: str, default: str) -> str:
        """Return an optional string value.

        Args:
            name: Variable name without the prefix.
            default: Value used when the variable is unset.

        Returns:
            The configured value, or *default*.
        """
        return self._raw(name) or default

    def choice(self, name: str, default: str, allowed: tuple[str, ...], *, upper: bool = False) -> str:
        """Return an optional value constrained to a fixed vocabulary.

        Args:
            name: Variable name without the prefix.
            default: Value used when the variable is unset.
            allowed: The accepted values.
            upper: Uppercase the value before checking (log levels), otherwise lowercase it.

        Returns:
            The normalised value, or *default* when the value is not accepted (the problem is
            recorded).
        """
        raw = self._raw(name)
        if raw is None:
            return default
        value = raw.upper() if upper else raw.lower()
        if value not in allowed:
            self.problems.append(f"{ENV_PREFIX}{name}={raw!r} is not one of {', '.join(allowed)}")
            return default
        return value

    def integer(self, name: str, default: int | None = None, *, minimum: int | None = None) -> int:
        """Return an integer value.

        Args:
            name: Variable name without the prefix.
            default: Value used when the variable is unset; ``None`` makes the variable required.
            minimum: Lowest accepted value, when there is one.

        Returns:
            The parsed value, or *default* (or ``0``) when it could not be parsed.
        """
        raw = self._raw(name)
        if raw is None:
            if default is None:
                self.problems.append(f"{ENV_PREFIX}{name} is required but not set")
                return 0
            return default
        try:
            value = int(raw)
        except ValueError:
            self.problems.append(f"{ENV_PREFIX}{name}={raw!r} is not an integer")
            return default or 0
        if minimum is not None and value < minimum:
            self.problems.append(f"{ENV_PREFIX}{name}={raw!r} must be >= {minimum}")
            return default or 0
        return value

    def port(self, name: str, default: int) -> int:
        """Return a TCP port number.

        Args:
            name: Variable name without the prefix.
            default: Value used when the variable is unset.

        Returns:
            The parsed port, or *default* when it is out of range or unparseable.
        """
        raw = self._raw(name)
        if raw is None:
            return default
        try:
            value = int(raw)
        except ValueError:
            self.problems.append(f"{ENV_PREFIX}{name}={raw!r} is not an integer")
            return default
        # 0 is allowed on purpose: it asks the OS for an ephemeral port, which is how the tests bind
        # a real server without racing on a fixed number.
        if not 0 <= value <= 65535:
            self.problems.append(f"{ENV_PREFIX}{name}={raw!r} is not a TCP port (0-65535)")
            return default
        return value

    def seconds(self, name: str, default: float) -> float:
        """Return a strictly positive duration in seconds.

        Args:
            name: Variable name without the prefix.
            default: Value used when the variable is unset.

        Returns:
            The parsed duration, or *default* when it is not a positive number.
        """
        raw = self._raw(name)
        if raw is None:
            return default
        try:
            value = float(raw)
        except ValueError:
            self.problems.append(f"{ENV_PREFIX}{name}={raw!r} is not a number of seconds")
            return default
        if value <= 0:
            self.problems.append(f"{ENV_PREFIX}{name}={raw!r} must be > 0")
            return default
        return value

    def flag(self, name: str, default: bool) -> bool:
        """Return a boolean value.

        An unrecognised value is a recorded problem, never a silent ``False``: reading
        ``DRY_RUN=maybe`` as "off" would start a real bot when the operator asked for a smoke run.

        Args:
            name: Variable name without the prefix.
            default: Value used when the variable is unset.

        Returns:
            The parsed flag, or *default*.
        """
        raw = self._raw(name)
        if raw is None:
            return default
        value = raw.lower()
        if value in _TRUE:
            return True
        if value in _FALSE:
            return False
        self.problems.append(
            f"{ENV_PREFIX}{name}={raw!r} is not a boolean ({'/'.join(sorted(_TRUE))} or {'/'.join(sorted(_FALSE))})"
        )
        return default

    def url(self, name: str, default: str) -> str:
        """Return an ``http(s)`` URL.

        Args:
            name: Variable name without the prefix.
            default: Value used when the variable is unset.

        Returns:
            The configured URL, or *default* when it is not a usable ``http(s)`` URL.
        """
        raw = self._raw(name)
        if raw is None:
            return default
        parsed = urlparse(raw)
        if parsed.scheme not in ("http", "https") or not parsed.netloc:
            self.problems.append(f"{ENV_PREFIX}{name}={raw!r} is not an http(s) URL")
            return default
        return raw

    def raise_if_broken(self) -> None:
        """Raise a single error listing every problem found.

        Raises:
            ConfigurationError: When at least one problem was recorded.
        """
        if not self.problems:
            return
        listed = "\n".join(f"  - {problem}" for problem in self.problems)
        raise ConfigurationError(
            f"the support bot cannot start: {len(self.problems)} configuration problem(s)\n{listed}\n"
            f"See services/support-bot/.env.example for the full list of variables."
        )


@dataclass(frozen=True, repr=False)
class SupportBotConfig:
    """Everything the service needs to run, resolved from the environment.

    Attributes:
        discord_token: The Discord bot token. Secret; never logged.
        discord_guild_id: The one guild the bot serves. The lot deliberately keeps the bot
            un-invitable to arbitrary servers, and this is where that decision is expressed.
        worker_endpoint: The documentation chatbot Worker ``/chat`` URL.
        worker_client: Value sent as ``X-VEAF-Client``, so the Worker can quota Discord separately
            from the CLI and the website.
        health_host: Interface the health server binds to.
        health_port: Port the health server binds to; ``0`` asks the OS for an ephemeral one.
        log_level: Root level of the service logger.
        log_format: ``json`` for production, ``text`` for a readable local run.
        heartbeat_seconds: Interval between heartbeat log lines.
        shutdown_grace_seconds: How long in-flight work is given to finish on shutdown.
        dry_run: Start every moving part except the outside world. Used by the container smoke test.
    """

    discord_token: str
    discord_guild_id: int
    worker_endpoint: str
    worker_client: str
    health_host: str
    health_port: int
    log_level: str
    log_format: str
    heartbeat_seconds: float
    shutdown_grace_seconds: float
    dry_run: bool

    @classmethod
    def from_env(cls, env: Mapping[str, str] | None = None) -> SupportBotConfig:
        """Build the configuration from environment variables.

        Args:
            env: Mapping to read from; defaults to ``os.environ``.

        Returns:
            The resolved configuration.

        Raises:
            ConfigurationError: When one or more variables are missing or malformed. The message
                lists every problem at once.
        """
        reader = _Reader(os.environ if env is None else env)

        # Read first: it decides whether the credentials are mandatory.
        dry_run = reader.flag("DRY_RUN", default=False)

        if dry_run:
            # A smoke run has no Discord identity by design, and must not invent one.
            discord_token = reader.text("DISCORD_TOKEN", default="")
            discord_guild_id = reader.integer("DISCORD_GUILD_ID", default=0, minimum=0)
        else:
            discord_token = reader.required("DISCORD_TOKEN")
            discord_guild_id = reader.integer("DISCORD_GUILD_ID", minimum=1)

        config = cls(
            discord_token=discord_token,
            discord_guild_id=discord_guild_id,
            worker_endpoint=reader.url("WORKER_ENDPOINT", DEFAULT_WORKER_ENDPOINT),
            worker_client=reader.text("WORKER_CLIENT", DEFAULT_WORKER_CLIENT),
            health_host=reader.text("HEALTH_HOST", DEFAULT_HEALTH_HOST),
            health_port=reader.port("HEALTH_PORT", DEFAULT_HEALTH_PORT),
            log_level=reader.choice("LOG_LEVEL", DEFAULT_LOG_LEVEL, LOG_LEVELS, upper=True),
            log_format=reader.choice("LOG_FORMAT", DEFAULT_LOG_FORMAT, LOG_FORMATS),
            heartbeat_seconds=reader.seconds("HEARTBEAT_SECONDS", DEFAULT_HEARTBEAT_SECONDS),
            shutdown_grace_seconds=reader.seconds("SHUTDOWN_GRACE_SECONDS", DEFAULT_SHUTDOWN_GRACE_SECONDS),
            dry_run=dry_run,
        )
        reader.raise_if_broken()
        return config

    def redacted(self) -> dict[str, Any]:
        """Return the configuration as a loggable mapping, with secrets masked.

        Returns:
            Every field, the Discord token replaced by :data:`REDACTED` when it holds anything.
        """
        return {
            "discord_token": REDACTED if self.discord_token else "",
            "discord_guild_id": self.discord_guild_id,
            "worker_endpoint": self.worker_endpoint,
            "worker_client": self.worker_client,
            "health_host": self.health_host,
            "health_port": self.health_port,
            "log_level": self.log_level,
            "log_format": self.log_format,
            "heartbeat_seconds": self.heartbeat_seconds,
            "shutdown_grace_seconds": self.shutdown_grace_seconds,
            "dry_run": self.dry_run,
        }

    def __repr__(self) -> str:
        """Return a redacted representation.

        The dataclass-generated ``repr`` would put the bot token in any stack trace or careless log
        line, so it is replaced rather than merely discouraged.

        Returns:
            A ``repr`` in which the token is masked.
        """
        fields = ", ".join(f"{key}={value!r}" for key, value in self.redacted().items())
        return f"{type(self).__name__}({fields})"
