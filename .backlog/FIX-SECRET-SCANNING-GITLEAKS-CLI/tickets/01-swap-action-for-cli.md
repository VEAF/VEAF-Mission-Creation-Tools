# 01 — Swap gitleaks-action for the free CLI

Status: 🔄 in-progress

## Task

Rewrite `.github/workflows/secret-scanning.yml` to stop using the licensed
`gitleaks/gitleaks-action@v3` wrapper and run the free MIT-licensed `gitleaks` CLI instead.

## Steps

- Add a pinned `GITLEAKS_VERSION` env (`8.30.1`).
- Replace the `Scan for secrets` step:
  - Install: download `gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz` from the
    `gitleaks/gitleaks` release, extract, place on `PATH`.
  - Scan: `gitleaks git --config .gitleaks.toml --redact --verbose`.
- Remove the `GITHUB_TOKEN` / `GITLEAKS_LICENSE` env block (no longer needed).
- Keep `fetch-depth: 0`, the triggers, and the `.gitleaks.toml` config untouched.

## Done when

- The workflow no longer references `gitleaks-action` nor `GITLEAKS_LICENSE`.
- The `Secret Scanning` check goes green on the PR (or surfaces a genuine finding to triage).
