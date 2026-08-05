# Lot FIX-SECRET-SCANNING-GITLEAKS-CLI

Status: ✅ done
Branch: `fix/secret-scanning-gitleaks-cli` → `develop` (merged, PR #615)

## Problem Statement

The `Secret Scanning` workflow (`.github/workflows/secret-scanning.yml`, added
2026-05-20) uses `gitleaks/gitleaks-action@v3`. That **Action wrapper** requires a
**paid licence for GitHub organisations**: without a `GITLEAKS_LICENSE` secret it aborts
with `[VEAF] is an organization. License key is required.`. The secret is not configured,
so the job has **failed on every run since it was added** — secret scanning has never
actually run on this repo. Surfaced during the v6.10.0 release (two failing runs on the
release pushes).

## Solution

Replace the licensed `gitleaks-action` wrapper with the **gitleaks CLI binary**, which is
MIT-licensed and free — no licence required, organisations included. The workflow installs
a pinned gitleaks release and runs `gitleaks git` against the existing `.gitleaks.toml`
config (allowlist preserved).

## Implementation Decisions

- Install the CLI from the official `gitleaks/gitleaks` GitHub release, **version pinned**
  (`GITLEAKS_VERSION`) for reproducibility and easy bumps — pinned to **8.30.1** (current
  latest at time of writing).
- Command: `gitleaks git --config .gitleaks.toml --redact --verbose`. `git` scans the full
  history (matches the previous behaviour with `fetch-depth: 0`); `--redact` keeps any
  finding out of the public logs.
- Drop the now-useless `GITHUB_TOKEN` / `GITLEAKS_LICENSE` env vars.
- **No product version bump**: this is CI-only infrastructure; the shipped `veaf-tools`
  binary and the Claude plugin are unchanged.

## Testing Decisions

- CI-only YAML change; verification is the workflow itself passing on the PR.
- **Risk**: a full-history scan may surface a real historical secret that was never caught
  (the job never ran). If that happens on the PR, triage it — allowlist a confirmed
  non-secret in `.gitleaks.toml`, or rotate a real leaked credential. Expected outcome on
  a clean repo: green.

## Out of Scope

- The `main` vs `master` branch mismatch in the trigger (`branches: [develop, main]` —
  the repo uses `master`, so the workflow never runs on `master`). Noted, not fixed here to
  keep the change surgical; candidate for a follow-up.
- Migrating to GitHub-native secret scanning.

---

## 01 — Swap gitleaks-action for the free CLI

Status: ✅ done

### Task

Rewrite `.github/workflows/secret-scanning.yml` to stop using the licensed
`gitleaks/gitleaks-action@v3` wrapper and run the free MIT-licensed `gitleaks` CLI instead.

### Steps

- Add a pinned `GITLEAKS_VERSION` env (`8.30.1`).
- Replace the `Scan for secrets` step:
  - Install: download `gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz` from the
    `gitleaks/gitleaks` release, extract, place on `PATH`.
  - Scan: `gitleaks git --config .gitleaks.toml --redact --verbose`.
- Remove the `GITHUB_TOKEN` / `GITLEAKS_LICENSE` env block (no longer needed).
- Keep `fetch-depth: 0`, the triggers, and the `.gitleaks.toml` config untouched.

### Done when

- The workflow no longer references `gitleaks-action` nor `GITLEAKS_LICENSE`.
- The `Secret Scanning` check goes green on the PR (or surfaces a genuine finding to triage).
