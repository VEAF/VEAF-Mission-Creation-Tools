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
    SUPPORT_BOT_GITHUB_LEDGER_FILE=/app/state/filed-issues.json \
    SUPPORT_BOT_ENRICH_STATE_FILE=/app/state/enrichment.json \
    SUPPORT_BOT_RELAY_LINKS_FILE=/app/state/relay-links.json \
    SUPPORT_BOT_CHECKOUT_PATH=/app/checkout

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
# `git`, because the service owns a clone it refreshes itself: `git fetch --prune`, then
# `git reset --hard`. Without it `open_checkout` raises on a directory with no `.git` and **neither
# `/bug` nor `/suggest` is published** — the image ran for a whole lot in that state, answering only
# `/ask`, and no test noticed. The CI now runs `git --version` in the built image.
RUN apt-get update \
    && apt-get install --no-install-recommends -y git \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir "discord.py>=2.4,<3" "typer>=0.12,<1" "cryptography>=42"

COPY veaf_support_bot ./veaf_support_bot
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

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
    && mkdir -p /app/state /app/checkout \
    && chmod +x /usr/local/bin/docker-entrypoint.sh \
    && chown -R veaf:veaf /app
# Two volumes, and they carry different kinds of loss. `state/` holds what cannot be rebuilt — the
# quota counters, the enrichment allowance, the filed-issue ledger, the thread-to-issue links, whose
# loss orphans every thread already opened. `checkout/` holds what can: losing it costs one clone on
# the next start. Both are declared so a `docker rm` cannot take the first with it.
VOLUME ["/app/state", "/app/checkout"]
USER veaf

EXPOSE 8081

# What turns "the container is running" into "the bot is working". `--healthcheck` probes /readyz
# and exits 0/1; Docker (and a compose or systemd unit reading the same signal) restarts on failure.
#
# Readiness means the Discord gateway is connected, so a container started with
# SUPPORT_BOT_DRY_RUN=true reports **unhealthy** — deliberately. A dry run answers nobody, and a
# health check that called it healthy would let one sit in production looking fine.
# **Do not raise `--start-period` without reading this.** The three numbers are tied to the CI step
# that asserts a dry run is called *unhealthy*: grace 15s + interval 30s + retries 3 puts the
# verdict at about 75 seconds, and that step waits 80. Raising the grace to 120s to cover the first
# clone made Docker answer `starting` for two minutes, `unhealthy` never, and the step timed out —
# measured on run 34114967333.
#
# What the short grace costs instead is cosmetic, and worth knowing: while the entry point clones
# the checkout (87 MiB, measured) the health endpoint is not up yet, so a first start can show
# `unhealthy` in `docker compose ps` for a minute. Docker does **not** restart an unhealthy
# container outside Swarm — `restart: unless-stopped` acts on exits, not on health — so nothing
# loops. It settles on its own once the clone finishes and the gateway connects.
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD ["python", "-m", "veaf_support_bot", "--healthcheck"]

# The entry point clones the checkout on first start, then hands over with `exec` — so SIGTERM
# still reaches Python and the graceful shutdown in service.py still runs on `docker stop`. The
# shell is a doorway, not a supervisor: it holds PID 1 for the length of one `git clone`.
#
# The module it ends on is the same one a direct launch runs, which is what keeps the documented
# direct run a rehearsal of the deployment rather than a second code path:
#   ENTRYPOINT ["python", "-m", "veaf_support_bot"]
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
