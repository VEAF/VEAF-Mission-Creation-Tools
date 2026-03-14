# VEAF Tools - User and Administrator Guide

## Overview

**VEAF Tools** (`veaf-tools-updater.exe`) is an all-in-one command-line tool for managing releases and updates of the VEAF Mission Creation Tools. It provides two main functions:

- **`update`** - For end users to download and install the latest tools
- **`publish`** - For administrators to create and publish new releases

---

## Table of Contents

1. [For End Users - Updating](#for-end-users---updating)
2. [For Administrators - Publishing](#for-administrators---publishing)
3. [System Architecture](#system-architecture)
4. [Troubleshooting](#troubleshooting)

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
   - The token is your password - keep it secret!

### Benefits

✅ No need to type `--token` every time  
✅ Cleaner command lines  
✅ Centralized settings management  
✅ Less risk of token exposure in shell history  

Once configured, all tools will automatically use these settings.

---

## For End Users - Updating

### Basic Update (Recommended)

To update your VEAF Tools to the latest version:

```bash
veaf-tools-updater.exe update
```

This will:
1. ✅ Check what version is currently installed
2. ✅ Fetch the latest version from GitHub (`published-latest` tag)
3. ✅ Compare versions (only updates if newer)
4. ✅ Download `published.zip` from GitHub Release
5. ✅ **Verify SHA256 checksum** (ensures file integrity)
6. ✅ Extract and install to your mission folder
7. ✅ Copy key files (`veaf-tools-updater.exe`, build scripts) to current directory

**Result:** Your tools are updated with integrity verification

### Update to Specific Version

If you need a previous version or want to be explicit:

```bash
veaf-tools-updater.exe update --tag published-v6.0.0
```

Available version tags appear on GitHub:
- `published-v6.0.1` - Version 6.0.1
- `published-v6.0.0` - Version 6.0.0
- `published-latest` - Always the current version (default)

### Force Update (Skip Version Check)

To reinstall the same version or force update:

```bash
veaf-tools-updater.exe update --force
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
```bash
veaf-tools-updater.exe update
```

**Option 2: Command line (if no config file)**
```bash
veaf-tools-updater.exe update --token ghp_xxxxxxxxxxxx
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

```bash
veaf-tools-updater.exe update --no-verify-checksum
```

⚠️ **Not recommended** - Checksums protect against:
- Network corruption
- File tampering
- Incomplete downloads

Only use if absolutely necessary.

### Verbose Output (Debugging)

For detailed troubleshooting:

```bash
veaf-tools-updater.exe update --verbose
```

Shows:
- Detailed operation steps
- API responses
- Debug information
- Full error context

### All Options Combined

```bash
veaf-tools-updater.exe update \
  --tag published-v6.0.1 \
  --token ghp_xxxxxxxxxxxx \
  --verbose \
  --force
```

### Getting Help

```bash
veaf-tools-updater.exe update --help
```

Shows all available options and their descriptions.

---

## For Administrators - Publishing

### Prerequisites

Before publishing, you need:

1. **Configuration file with GitHub token:**
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

2. **Compiled tools** in a `published/` directory:
   ```
   published/
   ├── veaf-tools-updater.exe      (compiled executable)
   ├── package.json                (with "version" field)
   ├── build-scripts/
   │   ├── buildDemoMission.cmd
   │   ├── buildHelicopterTrainingMission.cmd
   │   ├── buildTRADMission.cmd
   │   ├── buildOTMission.cmd
   │   └── ... other scripts ...
   └── ... other files ...
   ```

3. **Create a ZIP archive:**
   ```bash
   # Create published.zip from the published/ directory
   # Tools: 7-Zip, WinRAR, or any zip utility
   # Result: published.zip containing the structure above
   ```

### Basic Publish

To publish a new release:

**With configuration file (recommended):**
```bash
veaf-tools-updater.exe publish 6.0.1 ./published.zip
```

**Without configuration file:**
```bash
veaf-tools-updater.exe publish 6.0.1 ./published.zip --token ghp_xxxxxxxxxxxx
```

**Arguments:**
- `6.0.1` - Version number
- `./published.zip` - Path to your zip file
- Token is read from `veaf-tools-config.yaml` (if it exists) or `--token` parameter

**What happens:**
1. ✅ Creates Git tag: `published-v6.0.1`
2. ✅ Generates SHA256 checksum of the zip
3. ✅ Creates GitHub Release for this tag
4. ✅ Uploads `published.zip` as asset
5. ✅ Uploads checksum metadata (`published-metadata.json`)
6. ✅ Moves `published-latest` tag to point here
7. ✅ Pushes everything to GitHub

**Result:** Users can now update with `veaf-tools-updater update`

### Add Release Notes

```bash
veaf-tools-updater.exe publish 6.0.1 ./published.zip \
  --release-notes "Bug fixes: #123, #124. New features: Mission Editor improvements"
```

Release notes appear on GitHub and help users understand what changed.

### Create as Draft (Unpublished)

```bash
veaf-tools-updater.exe publish 6.0.1 ./published.zip --draft
```

Draft releases:
- Not visible to regular users
- Can only be updated by you
- Useful for testing before official release
- Visible in GitHub release list with "Draft" label

### Mark as Pre-Release

```bash
veaf-tools-updater.exe publish 6.0.1 ./published.zip --prerelease
```

Pre-releases:
- Visible to users but marked as pre-release
- Good for beta/testing versions
- Users won't automatically update to it
- Useful for `6.0.1-beta`, `6.1.0-rc1`, etc.

### Skip Tag Creation

```bash
veaf-tools-updater.exe publish 6.0.1 ./published.zip --skip-tag
```

Use when:
- You've already created the Git tag manually
- Publishing to an existing tag
- Debugging release process

### Verbose Output

```bash
veaf-tools-updater.exe publish 6.0.1 ./published.zip --verbose
```

Shows detailed debug information for troubleshooting.

### All Options Combined

```bash
veaf-tools-updater.exe publish 6.0.1 ./published.zip \
  --release-notes "Version 6.0.1 - Bug fixes and improvements" \
  --verbose
```

### Getting Help

```bash
veaf-tools-updater.exe publish --help
```

Shows all available options.

---

## Step-by-Step: Publishing a Release

### 1. Compile Your Code

```powershell
./compile.cmd
```

Creates:
- `./build/` - Lua scripts
- `./published/` - Compiled tools

### 2. Verify Directory Structure

```
published/
├── veaf-tools-updater.exe
├── package.json              # Check: has "version" field
├── build-scripts/
│   ├── buildDemoMission.cmd
│   ├── buildHelicopterTrainingMission.cmd
│   ├── buildTRADMission.cmd
│   ├── buildOTMission.cmd
│   └── ... more scripts ...
└── ... other files ...
```

### 3. Update Version in package.json

```json
{
  "version": "6.0.1",
  "name": "veaf-tools",
  ...
}
```

Make sure version field is present and correct.

### 4. Create published.zip

Use any zip tool (7-Zip, WinRAR, Windows Explorer):
```bash
# Result: published.zip containing the entire published/ directory
```

### 5. Setup Configuration (First Time Only)

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

### 6. Publish to GitHub

```bash
veaf-tools-updater.exe publish 6.0.1 ./published.zip \
  --release-notes "Version 6.0.1 - [your release notes]"
```

### 6. Verify on GitHub

Visit: https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases

Check:
- ✅ Release appears for version 6.0.1
- ✅ Assets uploaded: `published.zip`, `published-metadata.json`
- ✅ Git tag created: `published-v6.0.1`
- ✅ Latest tag moved: `published-latest`

### 7. Announce to Users

Tell users they can update:
```bash
veaf-tools-updater.exe update
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
Current Directory:
├── veaf-tools-updater.exe            (executable)
├── buildDemoMission.cmd              (script)
├── buildHelicopterTrainingMission.cmd (script)
├── buildTRADMission.cmd              (script)
├── buildOTMission.cmd                (script)
└── ... other build scripts ...

Mission Folder (specified in update):
└── published/
    ├── veaf-tools-updater.exe
    ├── package.json                  (version info)
    ├── build-scripts/
    │   ├── buildDemoMission.cmd
    │   └── ... scripts ...
    └── ... other files ...
```

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
```bash
# Try again (usually fixes it)
veaf-tools-updater.exe update

# If persists, check GitHub release:
# https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases
```

### Problem: "GitHub rate limit exceeded"

**Cause:** Too many API calls in short time

**Solution:**
```bash
# Option 1: Wait 1 hour (rate limit resets)

# Option 2: Use Personal Access Token (better limits)
veaf-tools-updater.exe update --token ghp_xxxxxxxxxxxx

# Get token from: https://github.com/settings/tokens
# Scope: repo (full control)
```

### Problem: "Permission denied" When Installing

**Cause:** Can't write to mission folder or current directory

**Solution:**
```bash
# Run as Administrator (Windows)
# Or specify different directory:
veaf-tools-updater.exe update --mission-folder "C:\alternative\path"
```

### Problem: File Not Found When Publishing

**Cause:** published.zip doesn't exist or path is wrong

**Solution:**
```bash
# Verify file exists
dir published.zip

# Use correct absolute path
veaf-tools-updater.exe publish 6.0.1 "C:\full\path\to\published.zip" --token ghp_xxx

# Create zip if missing
# (select published/ folder, right-click → Send to → Compressed (zipped))
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
veaf-tools-updater.exe publish 6.0.1 ./published.zip --verbose
```

### Problem: "Not a git repository"

**Cause:** Running from wrong directory or .git folder missing

**Solution:**
```bash
# Publish command runs from repo root (has .git/)
cd D:\dev\_VEAF\VEAF-Mission-Creation-Tools

# Then run publish
veaf-tools-updater.exe publish 6.0.1 ./published.zip --token ghp_xxx

# Or specify repo path
veaf-tools-updater.exe publish 6.0.1 ./published.zip \
  --token ghp_xxx \
  --repo-path "D:\dev\_VEAF\VEAF-Mission-Creation-Tools"
```

### Problem: "No release found for tag"

**Cause:** Version tag exists but GitHub Release hasn't been created for it

**Solution:**
```bash
# The publish command should create the release automatically

# If it didn't:
# 1. Visit https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases
# 2. Find the tag in "Releases" list
# 3. Click "Edit" and re-publish

# Or use publish again (it will detect existing tag)
veaf-tools-updater.exe publish 6.0.1 ./published.zip --token ghp_xxx
```

### Getting More Help

For detailed debug info:

```bash
# Show verbose output
veaf-tools-updater.exe update --verbose

# Or for publish
veaf-tools-updater.exe publish 6.0.1 ./published.zip --token ghp_xxx --verbose
```

Check the `veaf-tools.log` file in current directory for detailed logs.

---

## Command Reference

### Update Command

```bash
veaf-tools-updater.exe update [OPTIONS]

Options:
  --tag TEXT                     Version tag to fetch (default: published-latest)
  --token TEXT                   GitHub token (optional, overrides config file)
  --mission-folder TEXT          Mission folder path (optional, overrides config file)
  --no-confirm                   Skip confirmation prompts
  --force                        Ignore version check, install anyway
  --no-verify-checksum           Skip checksum verification (not recommended)
  --verbose                      Show detailed debug output
  --pause                        Wait for user input before exiting
  --help                         Show help message
```

**Note:** Settings from `veaf-tools-config.yaml` are used automatically. Command-line options override config file values.

**Examples:**
```bash
veaf-tools-updater.exe update
veaf-tools-updater.exe update --tag published-v6.0.0
veaf-tools-updater.exe update --token ghp_xxx --verbose
veaf-tools-updater.exe update --force --no-confirm
```

### Publish Command

```bash
veaf-tools-updater.exe publish VERSION ZIP_FILE [OPTIONS]

Required:
  VERSION                        Version number (6.0.1 or v6.0.1)
  ZIP_FILE                       Path to published.zip

Options:
  --token TEXT                   GitHub token (optional, overrides config file)
  --repo-path TEXT               Repository path (default: current directory)
  --release-notes TEXT           Release notes/changelog
  --draft                        Create as draft (not visible to users)
  --prerelease                   Mark as pre-release
  --skip-tag                     Skip Git tag creation
  --verbose                      Show detailed debug output
  --pause                        Wait for user input before exiting
  --help                         Show help message
```

**Note:** Token and other settings from `veaf-tools-config.yaml` are used automatically. Command-line options override config file values.

**Examples:**
```bash
# With config file (recommended)
veaf-tools-updater.exe publish 6.0.1 ./published.zip
veaf-tools-updater.exe publish 6.0.1 ./published.zip --release-notes "Version 6.0.1 - Bug fixes"
veaf-tools-updater.exe publish 6.0.1 ./published.zip --draft

# Without config file (token required)
veaf-tools-updater.exe publish 6.0.1 ./published.zip --token ghp_xxx
veaf-tools-updater.exe publish 6.0.1 ./published.zip --token ghp_xxx --release-notes "..."
```

---

## Best Practices

### For End Users

✅ **Do:**
- Run `veaf-tools update` regularly to stay current
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
- Always use the `publish` command for consistency
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
A: Yes! `veaf-tools update --tag published-v6.0.0`

**Q: What if publish fails?**
A: Check troubleshooting section above. Most issues are network or token related.

**Q: Do I need the token for updating?**
A: No, token is only for publishing. Update works without it (with rate limits).

**Q: How often should I publish new versions?**
A: As often as you have changes. Users won't see it unless you tell them.

**Q: Can I delete or revert a published version?**
A: On GitHub, yes. But users might have already downloaded it.

**Q: What's the difference between --draft and --prerelease?**
A: Draft = hidden, Prerelease = visible but marked as "not final"

**Q: Can I publish without creating a git tag?**
A: Yes, use `--skip-tag` but it's not recommended.

**Q: How long do tokens last?**
A: As long as you don't revoke them. They don't expire automatically.

**Q: Is the checksum required?**
A: No (can skip with `--no-verify-checksum`), but it's strongly recommended.

---

## Getting Help

If you encounter issues:

1. **Check troubleshooting section** above
2. **Run with `--verbose`** to see detailed output
3. **Check `veaf-tools.log`** in current directory
4. **Visit GitHub release page** to verify release exists
5. **Check your internet connection** (most issues are network)
6. **Verify token permissions** at https://github.com/settings/tokens

---

## Version History

### Current (6.0.1+)
- ✅ Unified update/publish tool
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
