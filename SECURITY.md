# Security Policy

## Supported Versions

Only the latest release on the `main` branch receives security fixes.

| Version | Supported |
|---------|-----------|
| 6.x (latest) | ✅ |
| < 6.0 | ❌ |

## Reporting a Vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Use one of the following channels instead:

1. **GitHub Security Advisories** (preferred) — [Report a vulnerability privately](https://github.com/VEAF/VEAF-Mission-Creation-Tools/security/advisories/new).
   GitHub keeps the report confidential until a patch is released.

2. **Email** — Send a message to the VEAF development team at [contact@veaf.org](mailto:contact@veaf.org) with the subject line `[SECURITY] VEAF-Mission-Creation-Tools`.

### What to include

- A description of the vulnerability and its potential impact
- Steps to reproduce (proof of concept if possible)
- Affected versions
- Any suggested mitigations you are aware of

### Response timeline

| Milestone | Target |
|-----------|--------|
| Acknowledgement | Within 5 business days |
| Status update | Within 14 days |
| Patch release | Within 30 days (critical), 90 days (others) |

We will credit you in the release notes unless you prefer to remain anonymous.

## Scope

This project distributes:
- **Lua scripts** loaded inside DCS World missions — run in the DCS Lua sandbox
- **Windows executables** (`veaf-tools.exe`, `veaf-tools-updater.exe`) — run on mission makers' machines

Both are in scope. Network-facing components (the updater downloads files from GitHub Releases) are of particular interest.
