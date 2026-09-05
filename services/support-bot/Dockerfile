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
    SUPPORT_BOT_HEALTH_PORT=8081

WORKDIR /app

# No `pip install`: the service has no runtime dependency, so copying the package is the whole
# install. When ticket 02 adds the Discord library this becomes a two-stage build.
COPY veaf_support_bot ./veaf_support_bot

# Unprivileged, and no home directory to write into: the service keeps no local state.
RUN useradd --system --uid 10001 --user-group --no-create-home veaf \
    && chown -R veaf:veaf /app
USER veaf

EXPOSE 8081

# What turns "the container is running" into "the bot is working". `--healthcheck` probes /readyz
# and exits 0/1; Docker (and a compose or systemd unit reading the same signal) restarts on failure.
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD ["python", "-m", "veaf_support_bot", "--healthcheck"]

# SIGTERM must reach the process, not a shell: exec form, no wrapper. That is what makes the
# graceful shutdown in service.py run at all on `docker stop`.
ENTRYPOINT ["python", "-m", "veaf_support_bot"]
