# VEAF Tools — User and Administrator Guide

## Overview

The release lifecycle of the VEAF Mission Creation Tools relies on two distinct command-line programs:

- **`veaf-tools-updater.exe`** - For end users: an update-only tool that downloads and installs the latest tools from GitHub. It has **no subcommands** — you run it directly.
- **`veaf-build`** - For administrators: the build-and-release tooling (shipped as `veaf-build.exe` / `poetry run veaf-build`) that compiles the tools and publishes new releases to GitHub via its `publish` subcommand.

---

## Configuration File (Optional but Recommended)

You can store your GitHub token and other settings in a configuration file instead of passing them as command-line arguments.

### Setup

1. **Copy the example configuration:**
   ```bash
   copy veaf-tools-config.example.yaml veaf-tools-config.yaml
   ```

2. **Edit `veaf-tools-config.yaml`:**
   ```yaml
   github:
     token: "ghp_your_actual_token_here"
     owner: "VEAF"
     repo: "VEAF-Mission-Creation-Tools"
   ```

3. **Keep it secure:**
   - ⚠️ Never commit `veaf-tools-config.yaml` to git
   - It's already in `.gitignore` (default)
   - The token is your password — keep it secret!

### Benefits

✅ No need to type `--token` every time  
✅ Cleaner command lines  
✅ Centralized settings management  
✅ Less risk of token exposure in shell history  

Once configured, all tools will automatically use these settings.

---

## Ask the Documentation (AI Assistant)

`veaf-tools ask` answers questions about the VEAF documentation with an AI assistant, grounded in the docs themselves (RAG). It is the same assistant as the chatbot on the documentation website.

**No setup, no API key.** The command sends your question to the VEAF documentation service, which generates the answer — you don't need a Google/Gemini key. (Fair-use rate limits apply per user.) An internet connection is required.

### Usage

```bash
# One-shot question
veaf-tools ask "How do I enable CTLD in my mission?"

# Interactive session (type 'quit' or Ctrl-D to exit)
veaf-tools ask

# Answer in English (default follows --lang)
veaf-tools --lang en ask "How are radio presets injected?"
```

It is also available from the interactive TUI as **"Ask the documentation"**.

---

## For End Users: Updating

### Basic Update (Recommended)

To update your VEAF Tools to the latest version:

```powershell
.\veaf-tools-updater.exe
```

This will:
1. ✅ Check what version is currently installed
2. ✅ Fetch the latest version from GitHub (`published-latest` tag)
3. ✅ Compare versions (only updates if newer)
4. ✅ Download `published.zip` from GitHub Release
5. ✅ **Verify SHA256 checksum** (ensures file integrity)
6. ✅ Extract and install to your mission folder
7. ✅ Move the two executables (`veaf-tools.exe`, `veaf-tools-updater.exe`) to the current directory

**Result:** Your tools are updated with integrity verification

### Update to Specific Version

If you need a previous version or want to be explicit:

```powershell
.\veaf-tools-updater.exe --tag published-v6.0.0
```

Available version tags appear on GitHub:
- `published-v6.0.1` - Version 6.0.1
- `published-v6.0.0` - Version 6.0.0
- `published-latest` - Always the current version (default)

### Force Update (Skip Version Check)

To reinstall the same version or force update:

```powershell
.\veaf-tools-updater.exe --force
```

This skips the "is it newer?" check and installs anyway. Useful for:
- Repairing a corrupted installation
- Reinstalling after manual modifications
- Testing specific versions

### Update with GitHub Token (Better Rate Limits)

If you hit GitHub API rate limits (unlikely), you can provide a Personal Access Token:

**Option 1: Using configuration file (recommended)**
```yaml
# In veaf-tools-config.yaml
github:
  token: "ghp_xxxxxxxxxxxx"
```

Then run:
```powershell
.\veaf-tools-updater.exe
```

**Option 2: Command line (if no config file)**
```powershell
.\veaf-tools-updater.exe --token ghp_xxxxxxxxxxxx
```

Benefits:
- Increases API rate limit: 60 → 5000 requests/hour
- Recommended for automated scripts
- Optional but helpful in some scenarios

**Get a token:**
1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Select scope: `repo` (full control)
4. Copy the token (you won't see it again!)

### Skip Checksum Verification (Not Recommended)

```powershell
.\veaf-tools-updater.exe --no-verify-checksum
```

⚠️ **Not recommended** - Checksums protect against:
- Network corruption
- File tampering
- Incomplete downloads

Only use if absolutely necessary.

### Interface Language

The tool output language is detected automatically — no configuration needed:

1. `--lang` CLI option (highest priority)
2. `VEAF_LANG` environment variable
3. `~/veafmct.yaml` → `lang:` key
4. OS locale (Windows registry / system locale on Linux and macOS)
5. `en` (built-in fallback)

To override for a single run:

```powershell
.\veaf-tools-updater.exe --lang fr
```

To set a persistent preference:

```powershell
.\veaf-tools.exe user-config --set lang=fr
```

Supported values: `en`, `fr`. See [Language configuration](mission-maker/GUIDE.en.md#global-user-configuration) for the full details.

### Verbose Output (Debugging)

For detailed troubleshooting:

```powershell
.\veaf-tools-updater.exe --verbose
```

Shows:
- Detailed operation steps
- API responses
- Debug information
- Full error context

### All Options Combined

```powershell
.\veaf-tools-updater.exe `
  --tag published-v6.0.1 `
  --token ghp_xxxxxxxxxxxx `
  --verbose `
  --force
```

### Getting Help

```powershell
.\veaf-tools-updater.exe --help
```

Shows all available options and their descriptions.

---

## For Administrators: Publishing

Publishing is done with **`veaf-build`** (the build-and-release CLI), not with the updater. The typical flow is `veaf-build build` (compile and package) then `veaf-build publish` (push the package to GitHub), or `veaf-build build-and-publish` to do both in one command.

### Prerequisites

Before publishing, you need:

1. **A GitHub token** so `veaf-build publish` can create the release. It is resolved in this order: the `--token` option, then `github.token` in `veaf-tools-config.yaml`, then the `GITHUB_TOKEN` environment variable.

   Using the configuration file (recommended):
   ```bash
   copy veaf-tools-config.example.yaml veaf-tools-config.yaml
   ```

   Edit `veaf-tools-config.yaml` and add your token:
   ```yaml
   github:
     token: "ghp_your_actual_token_here"
     owner: "VEAF"
     repo: "VEAF-Mission-Creation-Tools"
   ```

   **Get a token:**
   - Go to https://github.com/settings/tokens
   - Click "Generate new token (classic)"
   - Select scope: `repo` (full control of private/public repositories)
   - Copy token safely (never commit to git!)
   - ⚠️ Never commit `veaf-tools-config.yaml` to git!

2. **A built `published.zip`** in the current directory. This is produced by `veaf-build build` — you do not assemble it by hand.

### Build the Package

Compile the tools and produce `published.zip`:

```bash
veaf-build build --version 6.0.1
```

If you omit `--version`, the version is read from `package.json`. Useful options:

- `--skip-lua` / `--skip-python` - skip one half of the build
- `--dev` - development build
- `--output <dir>` - output directory for the package (default: current directory)
- `--verbose` - detailed output
- `--pause` - wait for a keypress when finished

### Basic Publish

After building (and editing `RELEASE_NOTES.md`), publish the already-compiled `published.zip`:

**With configuration file (recommended):**
```bash
veaf-build publish --version 6.0.1
```

**Without configuration file:**
```bash
veaf-build publish --version 6.0.1 --token ghp_xxxxxxxxxxxx
```

**Notes:**

- `--version` is an option, not a positional argument. If omitted, the version is read from `package.json`.
- The token is resolved in this order: the `--token` option, then `github.token` in `veaf-tools-config.yaml`, then the `GITHUB_TOKEN` environment variable.
- `published.zip` must already exist in the current directory (run `veaf-build build` first).

**What happens:**
1. ✅ Prepares the release notes (interactive pause to edit `RELEASE_NOTES.md`)
2. ✅ Generates the SHA256 checksum of `published.zip`
3. ✅ Creates the GitHub Release tagged `published-v6.0.1`
4. ✅ Uploads `published.zip` as an asset
5. ✅ Uploads the checksum metadata (`published-metadata.json`)
6. ✅ Moves the `published-latest` tag to point here

**Result:** Users can now update with `veaf-tools-updater.exe`

### Force Re-Publish

If the release already exists and you want to overwrite it:

```bash
veaf-build publish --version 6.0.1 --force
```

`--force` overwrites the existing release (publishes with `--clobber`).

### Pre-Release (testing without affecting users)

```bash
veaf-build publish --version 6.0.1-rc1 --prerelease
```

`--prerelease` requires a semver pre-release version (with a `-` suffix, e.g. `6.0.1-rc1`): the release workflow keys off that `-` to leave the `published-latest` tag in place. A `--prerelease` on a plain version (`6.0.1`) is **rejected** by the command. With a valid suffix, production users are not updated automatically; test explicitly with:

```powershell
.\veaf-tools-updater.exe --tag published-v6.0.1-rc1
```

### CI Mode

```bash
veaf-build publish --version 6.0.1 --ci
```

`--ci` runs non-interactively: it skips all prompts and uses `RELEASE_NOTES.md` as-is. Use it in automated pipelines.

### Build and Publish in One Step

```bash
veaf-build build-and-publish --version 6.0.1
```

This builds everything, pauses to let you edit `RELEASE_NOTES.md`, then publishes to GitHub. It accepts the build options (`--skip-lua`, `--skip-python`, `--dev`, `--output`), `--token`, `--ci`, and `--verbose`.

### Local Publish (testing, no GitHub)

To try a build in a real mission folder without going through GitHub + the updater,
deploy the build output locally. After `veaf-build build`:

```bash
veaf-build publish-local "D:/path/to/my-mission"
```

This reproduces the end state of publishing to GitHub and then running the updater in
that mission folder: it extracts `published.zip` into `<target>/published/` and moves
`veaf-tools.exe` / `veaf-tools-updater.exe` to the mission-folder root. Use
`--published-zip <path>` if your `published.zip` is elsewhere. No GitHub token needed.

### Getting Help

```bash
veaf-build --help
veaf-build publish --help
```

Shows all available subcommands and options.

---

## Step-by-Step: Publishing a Release

### 1. Setup Configuration (First Time Only)

Create and configure `veaf-tools-config.yaml`:
```bash
copy veaf-tools-config.example.yaml veaf-tools-config.yaml
```

Edit it with your GitHub token:
```yaml
github:
  token: "ghp_your_actual_token_here"
  owner: "VEAF"
  repo: "VEAF-Mission-Creation-Tools"
```

⚠️ **Important:** Never commit `veaf-tools-config.yaml` to git!

### 2. Build the Package

```bash
veaf-build build --version 6.0.1
```

This compiles the Lua scripts and Python executables and produces `published.zip` in the output directory (current directory by default). If you omit `--version`, it is read from `package.json`.

### 3. Edit the Release Notes

`veaf-build publish` opens an interactive pause so you can edit `RELEASE_NOTES.md` before the release goes out. Describe what changed for this version.

### 4. Publish to GitHub

```bash
veaf-build publish --version 6.0.1
```

Steps 2–4 can be combined with `veaf-build build-and-publish --version 6.0.1`.

### 5. Verify on GitHub

Visit: https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases

Check:
- ✅ Release appears for version 6.0.1
- ✅ Assets uploaded: `published.zip`, `published-metadata.json`
- ✅ Git tag created: `published-v6.0.1`
- ✅ Latest tag moved: `published-latest`

### 6. Announce to Users

Tell users they can update:
```powershell
.\veaf-tools-updater.exe
```

---

## System Architecture

### Versioning System

The system uses **Git tags** to manage versions:

```
Git Repository
├── published-v6.0.1   ──► GitHub Release with assets
├── published-v6.0.0   ──► GitHub Release with assets
├── published-v5.9.9   ──► GitHub Release with assets
└── published-latest   ──► Points to current version (movable)
```

**Benefits:**

- ✅ Clear version history in Git
- ✅ Easy to revert to any previous version
- ✅ `published-latest` always available for users
- ✅ Immutable version snapshots

### Integrity Verification

Each release includes checksum verification:

```
User downloads:
  published.zip              (compiled tools)
  published-metadata.json    (contains SHA256)

Update process:
  1. Calculate SHA256(published.zip)
  2. Compare with published-metadata.json
  3. If match ✓ → Install
  4. If mismatch ✗ → Error (abort, try again)
```

**Protected against:**

- Network corruption
- Incomplete downloads
- File tampering

### Version Comparison

The system correctly compares semantic versions:

```
Installed: 6.0.0
Available: 6.0.1
Result:    6.0.1 > 6.0.0 → Update available ✓

(Old systems would do string comparison and fail)
```

---

## File Structure

### What Users Have

After updating, users have:

```
Current Directory (mission folder):
├── veaf-tools.exe                    (main executable, moved out of published/)
└── veaf-tools-updater.exe            (the updater itself, replaced via deferred update when running)

└── published/                        (the rest of the extracted package)
    ├── README.md                     (deliberately kept here — the online docs are the source)
    ├── package.json                  (version info)
    └── ... other package files ...
```

Only the two executables are moved to the current directory; everything else stays under `published/`.

### What GitHub Shows

After publishing:

```
Release: published-v6.0.1
├── Asset: published.zip              (compiled tools)
├── Asset: published-metadata.json    (checksums)
└── Release notes

Git Tags:
├── published-v6.0.1 ──► commit abc123def...
├── published-latest ──► commit abc123def... (same)
└── published-v6.0.0 ──► commit xyz789uvw...
```

---

## Troubleshooting

### Problem: "Tag not found on GitHub"

**Cause:** Git tag was created locally but not pushed to GitHub

**Solution:**
```bash
# Check if tag exists locally
git tag -l published-v6.0.1

# If it exists, push it
git push origin refs/tags/published-v6.0.1

# If it doesn't exist, create it
git tag -a published-v6.0.1 -m "Release 6.0.1"
git push origin refs/tags/published-v6.0.1
```

### Problem: "Checksum mismatch" When Updating

**Cause:** File corruption during download (rare) or network issue

**Solution:**
```powershell
# Try again (usually fixes it)
.\veaf-tools-updater.exe

# If persists, check GitHub release:
# https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases
```

### Problem: "GitHub rate limit exceeded"

**Cause:** Too many API calls in short time

**Solution:**
```powershell
# Option 1: Wait 1 hour (rate limit resets)

# Option 2: Use Personal Access Token (better limits)
.\veaf-tools-updater.exe --token ghp_xxxxxxxxxxxx

# Get token from: https://github.com/settings/tokens
# Scope: repo (full control)
```

### Problem: "Permission denied" When Installing

**Cause:** Can't write to mission folder or current directory

**Solution:**
```powershell
# Run as Administrator (Windows)
# Or specify a different directory as a positional argument:
.\veaf-tools-updater.exe "C:\alternative\path"
```

### Problem: "Release package not found" When Publishing

**Cause:** `published.zip` doesn't exist in the current directory

**Solution:**
```bash
# Verify file exists
dir published.zip

# If missing, build it first
veaf-build build --version 6.0.1

# Then publish
veaf-build publish --version 6.0.1
```

### Problem: "Failed to create GitHub release"

**Cause:** Usually token issues or network problem

**Solution:**
```bash
# Check token:
# 1. Verify veaf-tools-config.yaml exists and has correct token
# 2. Go to https://github.com/settings/tokens
# 3. Verify scope includes "repo"
# 4. Create new token if old one expired
# 5. Token must have write permissions

# Update your config file and try again
veaf-build publish --version 6.0.1 --verbose
```

### Problem: Release Already Exists

**Cause:** A release with that tag was already published

**Solution:**
```bash
# Overwrite the existing release
veaf-build publish --version 6.0.1 --force
```

### Getting More Help

For detailed debug info:

```powershell
# Update tool: verbose output
.\veaf-tools-updater.exe --verbose

# Build/publish tool: verbose output
veaf-build publish --version 6.0.1 --verbose
```

Check the `veaf-tools.log` file for detailed logs. It is written to **`%USERPROFILE%\.veaf\veaf-tools.log`** (or to `$VEAF_HOME` if you set that variable), not to the current directory. `.\veaf-tools.exe doctor` prints its exact path and the last errors it recorded.

---

## Command Reference

### Update Command (`veaf-tools-updater.exe`)

The updater is a single update-only command with **no subcommands**.

```powershell
.\veaf-tools-updater.exe [MISSION_FOLDER] [OPTIONS]

Arguments:
  MISSION_FOLDER                 Mission folder path (overrides config file; default: current directory)

Options:
  --tag TEXT                     Tag name to fetch (default: published-latest)
  --token TEXT                   GitHub Personal Access Token (overrides config file)
  --force                        Ignore version check and install anyway
  --no-verify-checksum           Skip checksum verification (not recommended)
  --zip-file TEXT                Path to a local published.zip file (for testing, skips GitHub)
  --lang TEXT                    Force interface language (en, fr); overrides OS locale and ~/veafmct.yaml
  --verbose                      Show detailed debug output
  --pause                        Wait for user input before exiting
  --help                         Show help message
```

**Note:** Settings from `veaf-tools-config.yaml` are used automatically. Command-line options override config file values.

**Examples:**
```powershell
.\veaf-tools-updater.exe
.\veaf-tools-updater.exe --tag published-v6.0.0
.\veaf-tools-updater.exe --token ghp_xxx --verbose
.\veaf-tools-updater.exe --force
.\veaf-tools-updater.exe --zip-file ./published.zip
```

### Publish Command (`veaf-build publish`)

Publishing is a subcommand of **`veaf-build`** (not the updater).

```bash
veaf-build publish [OPTIONS]

Options:
  --version TEXT                 Semantic version for the release (e.g. 6.0.1). If omitted, read from package.json
  --token TEXT                   GitHub Personal Access Token with 'repo' scope (or GITHUB_TOKEN env var)
  --force                        Force publish even if the release already exists (overwrites with --clobber)
  --prerelease                   Mark as pre-release; does NOT update published-latest
  --ci                           Non-interactive CI mode: skip all prompts and use RELEASE_NOTES.md as-is
  --verbose                      Show detailed debug output
  --pause                        Wait for user input before exiting
  --help                         Show help message
```

**Note:** `published.zip` must already exist (run `veaf-build build` first). The token is resolved from `--token`, then `veaf-tools-config.yaml`, then the `GITHUB_TOKEN` environment variable.

**Other `veaf-build` subcommands:**

- `build [--version --skip-lua --skip-python --dev --output --verbose --pause]` - compile the tools and produce `published.zip`
- `build-and-publish [--version --token --skip-lua --skip-python --dev --output --ci --verbose]` - build then publish in one step
- `publish-local <target> [--published-zip --verbose --pause]` - deploy a build into a local mission folder (no GitHub)
- `update-dcs-data [--countries --units --radio --airdromes --airfield-freqs --cockpit-controls --aircraft --dcs-path --inject-bridge --capture --serve-url --api-key --bridge-lua --all]` - regenerate committed DCS reference data; the first six flags pick the table, `--dcs-path` targets a DCS install for the tables that need one, and `--inject-bridge` / `--capture` / `--serve-url` / `--api-key` / `--bridge-lua` drive capture from a running DCS (see [DCS data generators](developer/dcs-data.en.md))
- `build-standalone [--version --output --with-updater --verbose --pause]` - build the current platform's binaries without going through the release flow (used by the Linux/macOS runners)
- `build-kit [--version --exe --bridge-zip --bridge-lua --output --verbose]` - assemble the capture kit handed to a map's operator (executable + bridge mission)
- `about` - information about the build system

**Examples:**
```bash
# With config file (recommended)
veaf-build build --version 6.0.1
veaf-build publish --version 6.0.1

# Without config file (token required)
veaf-build publish --version 6.0.1 --token ghp_xxx

# Pre-release / force / CI
veaf-build publish --version 6.0.1-rc1 --prerelease
veaf-build publish --version 6.0.1 --force
veaf-build publish --version 6.0.1 --ci
```

---

## Best Practices

### For End Users

✅ **Do:**
- Run `.\veaf-tools-updater.exe` regularly to stay current
- Let checksums verify integrity (don't skip with `--no-verify-checksum`)
- Use `--help` if unsure about any option

❌ **Don't:**
- Skip checksum verification
- Manually modify `veaf-tools-updater.exe` or build scripts
- Use old versions without good reason
- Share Personal Access Tokens (token = password)

### For Administrators

✅ **Do:**
- Store your token in `veaf-tools-config.yaml` (never in git!)
- Always publish with `veaf-build publish` for consistency
- Keep release notes up to date
- Test before publishing to production
- Use different tokens for different machines
- Regenerate tokens periodically
- Keep `veaf-tools-config.yaml` in `.gitignore`

❌ **Don't:**
- Commit `veaf-tools-config.yaml` to git
- Commit Personal Access Tokens anywhere
- Share tokens with others
- Publish untested versions
- Reuse tokens across machines
- Skip the verification process

---

## Security

### Token Safety

Your GitHub Personal Access Token is like a password:
- ❌ Never commit to git (even in config files)
- ❌ Never share in emails or messages
- ❌ Never paste in public forums
- ❌ Never push `veaf-tools-config.yaml` to git
- ✅ Store in `veaf-tools-config.yaml` (local only)
- ✅ Ensure `veaf-tools-config.yaml` is in `.gitignore`
- ✅ Regenerate regularly (monthly)
- ✅ Use for one task, then revoke (when possible)

### Checksum Verification

Checksums protect downloads:
- ✅ Detect network corruption
- ✅ Verify files haven't been modified
- ✅ Prevent man-in-the-middle attacks
- ✅ Enabled by default (keep it that way!)

### HTTPS

All GitHub communications use TLS/SSL encryption:
- ✅ Data in transit is protected
- ✅ GitHub API requires HTTPS
- ✅ Your token is encrypted over the wire

---

## FAQ

**Q: Can I update to an old version?**
A: Yes! `.\veaf-tools-updater.exe --tag published-v6.0.0`

**Q: What if publish fails?**
A: Check troubleshooting section above. Most issues are network or token related.

**Q: Do I need the token for updating?**
A: No, token is only for publishing. Update works without it (with rate limits).

**Q: How often should I publish new versions?**
A: As often as you have changes. Users won't see it unless you tell them.

**Q: Can I delete or revert a published version?**
A: On GitHub, yes. But users might have already downloaded it.

**Q: How do I publish a beta without affecting users?**
A: Use `veaf-build publish --version <x.y.z>-rc1 --prerelease` — the version must carry a semver pre-release suffix (`-rc1`, `-beta`…), otherwise the command refuses. The `published-latest` tag then stays untouched, so production users are not updated; test it with `.\veaf-tools-updater.exe --tag published-v<x.y.z>-rc1`.

**Q: How do I re-publish over an existing release?**
A: Use `veaf-build publish --version <x.y.z> --force`.

**Q: How long do tokens last?**
A: As long as you don't revoke them. They don't expire automatically.

**Q: Is the checksum required?**
A: No (can skip with `--no-verify-checksum`), but it's strongly recommended.

---

## Getting Help

If you encounter issues:

1. **Check troubleshooting section** above
2. **Run with `--verbose`** to see detailed output
3. **Check `veaf-tools.log`** in `%USERPROFILE%\.veaf\` (or `$VEAF_HOME`) — see [Getting help](SUPPORT.en.md)
4. **Visit GitHub release page** to verify release exists
5. **Check your internet connection** (most issues are network)
6. **Verify token permissions** at https://github.com/settings/tokens

---

## Version History

### Current (6.0.1+)
- ✅ Dedicated tools: `veaf-tools-updater.exe` (update) and `veaf-build` (build/publish)
- ✅ Git tag-based versioning
- ✅ SHA256 checksum verification
- ✅ Semantic version comparison
- ✅ Fully automated publishing

### Previous
- Basic update script
- Release-based versioning
- Manual publishing
- Limited documentation

---

**Happy releasing!** 🚀

For more technical details, see the source code or GitHub repository.
