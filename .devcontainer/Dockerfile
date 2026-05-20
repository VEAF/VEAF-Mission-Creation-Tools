FROM python:3.13-slim-bookworm

# System packages: Lua 5.1 (matches DCS runtime + CI), utilities
RUN apt-get update -q \
    && apt-get install -y --no-install-recommends \
        lua5.1 \
        curl \
        unzip \
        git \
        sudo \
    && rm -rf /var/lib/apt/lists/*

# StyLua 2.4.0 — exact version required by CI (.github/workflows/lua-ci.yml)
RUN ARCH=$(dpkg --print-architecture) \
    && case "$ARCH" in \
        amd64) ARCH_LABEL="x86_64" ;; \
        arm64) ARCH_LABEL="aarch64" ;; \
        *) echo "Unsupported arch: $ARCH" && exit 1 ;; \
    esac \
    && curl -fsSL "https://github.com/JohnnyMorganz/StyLua/releases/download/v2.4.0/stylua-linux-${ARCH_LABEL}.zip" \
        -o /tmp/stylua.zip \
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
WORKDIR /workspace
