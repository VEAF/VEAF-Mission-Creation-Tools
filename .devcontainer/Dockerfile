FROM python:3.13-slim-bookworm

# System packages: Lua 5.1 (matches DCS runtime + CI), luarocks (for luacov), utilities
RUN apt-get update -q \
    && apt-get install -y --no-install-recommends \
        lua5.1 \
        luarocks \
        curl \
        unzip \
        git \
        sudo \
    && luarocks install luacov 0.15.0-1 \
    && rm -rf /var/lib/apt/lists/*

# StyLua 2.4.0 — exact version required by CI (.github/workflows/lua-ci.yml)
# SHA256 sourced from the official GitHub release API (immutable release assets).
RUN ARCH=$(dpkg --print-architecture) \
    && case "$ARCH" in \
        amd64) \
            ARCH_LABEL="x86_64" \
            EXPECTED_SHA256="f9c84c210712061cb03ab8354a34a5d4f5fcf1f369d2ce916bea3ab9f7addac8" \
            ;; \
        arm64) \
            ARCH_LABEL="aarch64" \
            EXPECTED_SHA256="67bbd6ad4d864ab375babdd125ed926183968f5b6e55d7e0a6f9f425511a5408" \
            ;; \
        *) echo "Unsupported arch: $ARCH" && exit 1 ;; \
    esac \
    && curl -fsSL "https://github.com/JohnnyMorganz/StyLua/releases/download/v2.4.0/stylua-linux-${ARCH_LABEL}.zip" \
        -o /tmp/stylua.zip \
    && echo "${EXPECTED_SHA256}  /tmp/stylua.zip" | sha256sum -c - \
    && unzip /tmp/stylua.zip -d /usr/local/bin \
    && rm /tmp/stylua.zip \
    && chmod +x /usr/local/bin/stylua

# Poetry — same install method as CI (pip install poetry, no version pin)
RUN pip install --no-cache-dir poetry

# Create the standard VS Code non-root user
RUN useradd -m -s /bin/bash -u 1000 vscode \
    && echo "vscode ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/vscode \
    && chmod 0440 /etc/sudoers.d/vscode

USER vscode
# /workspace matches the workspaceFolder defined in devcontainer.json
WORKDIR /workspace
