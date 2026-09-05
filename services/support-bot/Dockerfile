# The support bot, containerised.
#
# The image runs exactly the module a direct launch runs — `python -m veaf_support_bot` — so the
# documented direct-run command is a rehearsal of the deployment, not a second code path.
#
# Build from THIS directory:
#   docker build -t veaf-support-bot services/support-bot
FROM python:3.13-slim

# Unbuffered so a supervisor sees each log line as it happens rather than in 8 KiB bursts — a
# buffered log is how a silent death stays silent for one more page.
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    SUPPORT_BOT_HEALTH_HOST=0.0.0.0 \
    SUPPORT_BOT_HEALTH_PORT=8081 \
    SUPPORT_BOT_QUOTA_STATE_FILE=/app/state/quota.json \
    SUPPORT_BOT_GITHUB_LEDGER_FILE=/app/state/filed-issues.json

WORKDIR /app

# The runtime dependencies, on their own layer and before the package is copied, so editing the code
# does not re-resolve them on every build. The bounds match the service's `pyproject.toml`.
#
# `typer` is not used by this service at all: it is what the tools' own `.miz` parser imports, and
# `/bug` summarises a mission through that parser rather than forking a second one. See the comment
# in `pyproject.toml`.
#
# `cryptography` signs the GitHub App's JWT. It is the only way to do RS256 — no stdlib module signs
# one — and hand-rolling PKCS1v15 in a service that writes to a public repository is not a trade
# worth making.
RUN pip install --no-cache-dir "discord.py>=2.4,<3" "typer>=0.12,<1" "cryptography>=42"

COPY veaf_support_bot ./veaf_support_bot

# Unprivileged, with exactly one writable directory: the per-user quota counters, and the ledger of
# what `/bug` has already filed.
#
# Both must survive a restart — otherwise restarting the container is how anyone gets a fresh
# allowance, and how one report becomes two issues — so mount a volume here in production. Without
# one they survive a restart of the process but not a `docker rm`. The service does not hide the
# difference: as soon as it cannot read or write the counters it drops to a much stricter ceiling
# and says so, in the log and in `/status`; a ledger it cannot read falls back to the marker each
# filed issue carries in its own body.
RUN useradd --system --uid 10001 --user-group --no-create-home veaf \
    && mkdir -p /app/state \
    && chown -R veaf:veaf /app
VOLUME ["/app/state"]
USER veaf

EXPOSE 8081

# What turns "the container is running" into "the bot is working". `--healthcheck` probes /readyz
# and exits 0/1; Docker (and a compose or systemd unit reading the same signal) restarts on failure.
#
# Readiness means the Discord gateway is connected, so a container started with
# SUPPORT_BOT_DRY_RUN=true reports **unhealthy** — deliberately. A dry run answers nobody, and a
# health check that called it healthy would let one sit in production looking fine.
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD ["python", "-m", "veaf_support_bot", "--healthcheck"]

# SIGTERM must reach the process, not a shell: exec form, no wrapper. That is what makes the
# graceful shutdown in service.py run at all on `docker stop`.
ENTRYPOINT ["python", "-m", "veaf_support_bot"]
