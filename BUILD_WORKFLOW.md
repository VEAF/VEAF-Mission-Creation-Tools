# Build and Release Workflow

Complete guide for building, testing, and publishing VEAF Tools releases.

## Features Overview

### Runtime Features (in DCS missions)
Loaded at mission start:
- Unit Spawning - Aircraft, ground units, portable TACANs
- Mission Types - Air-to-ground, air-to-air, transport, carrier operations
- Asset Management - Tankers, AWACS, aircraft carriers with state tracking
- Weather & ATC - Dynamic weather injection, ATC services
- Zones & Artillery - Shelling, illumination, zone management
- Named Points - Position management with ATC services
- Radio System - Dynamic radio menus, frequency management
- Remote Control - NIOD (RPC) and SLMOD socket integration
- Security - Role-based action permissions
- Templates - Reusable group definitions

### Design-Time Features (mission creation)
Automation for mission makers:
- Mission Normalization - Standardize mission files for easy diffing
- Radio Presets - Globally inject standard frequency plans for human groups
- Weather Injection - Insert real weather into missions
- Aircraft Groups Injection - Inject predefined aircraft groups; supports extraction
- Waypoints Injection - Inject predefined waypoints for human groups; supports extraction

## Table of Contents

- [Quick Start](#quick-start)
- [Step-by-Step Guide](#step-by-step-guide)
- [Configuration](#configuration)
- [Command Reference](#command-reference)
- [Common Workflows](#common-workflows)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

```bash
# Activate virtual environment
. .\.venv\Scripts\Activate.ps1

# 1. Build the release
python build-and-release.py build --version 6.0.4

# 2. Edit release notes
notepad RELEASE_NOTES.md

# 3. Publish to GitHub
python build-and-release.py publish --version 6.0.4
```

---

## Step-by-Step Guide

### Step 1: Build the Release

Compile Lua scripts and Python executables:

```bash
# Activate virtual environment
. .\.venv\Scripts\Activate.ps1

# Build the release
python build-and-release.py build --version 6.0.4
```

**What happens:**
- ✓ Validates prerequisites (Git, Python, PyInstaller)
- ✓ Compiles Lua scripts from `src/scripts/veaf/`
- ✓ Builds Python executables (veaf-tools.exe, veaf-tools-updater.exe)
- ✓ Creates `published.zip` with all artifacts
- ✓ Calculates SHA256 hash
- ✓ Generates `RELEASE_NOTES.md` template

**Output files:**
- `published.zip` - Release package
- `RELEASE_NOTES.md` - Template (you edit this)
- `published/` - Extracted scripts
- `dist/` - Compiled executables

### Step 2: Edit Release Notes

Edit the generated `RELEASE_NOTES.md` file:

```bash
notepad RELEASE_NOTES.md
```

Update these sections:
- **What's New** - Features added in this release
- **Bug Fixes** - Issues fixed
- **Breaking Changes** - Incompatible changes (if any)

The Installation section is automatically formatted with both English and French instructions.

### Step 3: Publish to GitHub

Once release notes are complete, publish to GitHub:

```bash
python build-and-release.py publish --version 6.0.4
```

**What happens:**
- ✓ Verifies `published.zip` exists
- ✓ Reads `RELEASE_NOTES.md`
- ✓ Creates git tags (`published-v6.0.4`, `published-latest`)
- ✓ Pushes tags to GitHub
- ✓ Creates GitHub release with notes
- ✓ Uploads `published.zip` to release
- ✓ Uploads `veaf-tools-updater.exe` to release

**Important:** No recompilation happens. It uses artifacts from Step 1.

---

## Configuration

### Setup Configuration File

The build system supports `veaf-tools-config.yaml` for default settings:

**Step 1: Create config file**
```bash
cp veaf-tools-config.example.yaml veaf-tools-config.yaml
```

**Step 2: Edit configuration**
```yaml
github:
  token: "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  owner: "VEAF"
  repo: "VEAF-Mission-Creation-Tools"

publish:
  draft: false
  prerelease: false
  skipTag: false
```

**Step 3: Get GitHub token**
1. Go to https://github.com/settings/tokens
2. Create new token with `repo` scope
3. Copy token to `veaf-tools-config.yaml`

**⚠️ IMPORTANT:** Never commit `veaf-tools-config.yaml`!
- It's already in `.gitignore`
- Contains your GitHub token
- Keep it secure!

### Token Precedence

GitHub token is used in this order:

1. **CLI argument** - Highest priority
   ```bash
   python build-and-release.py publish --version 6.0.4 --token ghp_xxx
   ```

2. **Config file** - `veaf-tools-config.yaml`
   ```bash
   python build-and-release.py publish --version 6.0.4
   ```

3. **Environment variable** - `GITHUB_TOKEN`
   ```bash
   $env:GITHUB_TOKEN = "ghp_xxx"
   python build-and-release.py publish --version 6.0.4
   ```

---

## Command Reference

### Build Command

```bash
python build-and-release.py build [OPTIONS]
```

**Options:**
| Option | Default | Description |
|--------|---------|-------------|
| `--version VERSION` | package.json | Semantic version (e.g., '6.0.4') |
| `--dev` | false | Build in development mode |
| `--skip-lua` | false | Skip Lua script compilation |
| `--skip-python` | false | Skip Python executable compilation |
| `--output PATH` | `.` | Output directory for release package |
| `--verbose` | false | Show debug information |
| `--pause` | false | Pause when finished |

**Examples:**
```bash
# Build with default version from package.json
python build-and-release.py build

# Build specific version
python build-and-release.py build --version 6.0.4

# Development build
python build-and-release.py build --version 6.0.4-dev --dev

# Skip Lua compilation (Python only)
python build-and-release.py build --skip-lua --version 6.0.4

# Skip Python compilation (Lua only)
python build-and-release.py build --skip-python --version 6.0.4

# Verbose output
python build-and-release.py build --verbose
```

### Publish Command

```bash
python build-and-release.py publish [OPTIONS]
```

**Options:**
| Option | Default | Description |
|--------|---------|-------------|
| `--version VERSION` | package.json | Semantic version (e.g., '6.0.4') |
| `--token TOKEN` | from config/env | GitHub Personal Access Token |
| `--force` | false | Force overwrite if release exists |
| `--verbose` | false | Show debug information |
| `--pause` | false | Pause when finished |

**Examples:**
```bash
# Publish with version from package.json
python build-and-release.py publish

# Publish specific version
python build-and-release.py publish --version 6.0.4

# Publish with CLI token (overrides config)
python build-and-release.py publish --version 6.0.4 --token ghp_xxx

# Force overwrite existing release
python build-and-release.py publish --version 6.0.4 --force

# Verbose output
python build-and-release.py publish --verbose
```

### About Command

```bash
python build-and-release.py about
```

Shows information about VEAF Tools and opens the website.

---

## Common Workflows

### Workflow 1: Full Release

Build, edit notes, then publish:

```bash
# 1. Build everything
python build-and-release.py build --version 6.0.4

# 2. Edit release notes manually
notepad RELEASE_NOTES.md

# 3. Publish to GitHub
python build-and-release.py publish --version 6.0.4
```

### Workflow 2: Republish (Force Overwrite)

Already have artifacts, just republishing:

```bash
# Just republish (no rebuild needed)
python build-and-release.py publish --version 6.0.4 --force
```

### Workflow 3: Build Only (No Publishing)

Test or prepare without going live:

```bash
# Build only
python build-and-release.py build --version 6.0.4

# Test the artifacts...
# Then publish later
python build-and-release.py publish --version 6.0.4
```

### Workflow 4: Development Build

Build with development flags:

```bash
# Build with dev flag
python build-and-release.py build --version 6.0.4-dev --dev

# Dev builds have trace/debug logging enabled
```

### Workflow 5: Skip Components

Only compile what changed:

```bash
# Only Lua (no Python recompilation)
python build-and-release.py build --skip-python --version 6.0.4

# Only Python (no Lua recompilation)
python build-and-release.py build --skip-lua --version 6.0.4
```

---

## Troubleshooting

### Issue: "PyInstaller is not installed"

**Solution:** Install in virtual environment
```bash
. .\.venv\Scripts\Activate.ps1
pip install pyinstaller
```

### Issue: "Release package not found"

**Solution:** Run build first
```bash
python build-and-release.py build --version 6.0.4
```

### Issue: "Release notes not found"

**Solution:** Create `RELEASE_NOTES.md` by running build
```bash
python build-and-release.py build --version 6.0.4
# This generates RELEASE_NOTES.md template
```

### Issue: "GitHub CLI operation failed"

**Solutions:**
1. Check that `gh` is installed: `gh --version`
2. Authenticate: `gh auth login`
3. Verify token has `repo` scope
4. Check internet connection

### Issue: "HTTP 422: Release.tag_name already exists"

**Solutions:**
- Use `--force` flag to overwrite:
  ```bash
  python build-and-release.py publish --version 6.0.4 --force
  ```
- Or manually delete the GitHub release and retry

### Issue: Missing dependencies

**Solution:** Activate virtual environment first
```bash
. .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

---

## Files Generated

| File | Purpose |
|------|---------|
| `published.zip` | Release package with all artifacts |
| `published/` | Extracted Lua scripts |
| `RELEASE_NOTES.md` | Release notes (edit before publish) |
| `build/` | Temporary PyInstaller build directory |
| `dist/` | Compiled executables |
| `.venv/` | Python virtual environment |

---

**Last Updated:** November 28, 2025
