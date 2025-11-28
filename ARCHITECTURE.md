# VEAF Tools - Architecture Overview

## Tool Separation

```
┌─────────────────────────────────────────────────────────────────┐
│                        VEAF Tools Ecosystem                      │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                    DEVELOPERS / ADMINISTRATORS                    │
│                                                                   │
│  build-and-release.py                                            │
│  ├── Compile Lua scripts                                         │
│  ├── Compile Python executables (veaf-tools, updater)           │
│  ├── Create release package (ZIP)                                │
│  ├── Calculate SHA256 checksum                                   │
│  └── Publish to GitHub (fully automated!)                        │
│      ├── Create git tags                                         │
│      ├── Create GitHub Release                                   │
│      ├── Upload package                                          │
│      └── Update release notes                                    │
│                          ↓                                        │
│                   GitHub Release                                  │
│                 (published.zip + SHA256)                          │
└──────────────────────────────────────────────────────────────────┘
                            ↓
                            │
                    (Available on GitHub)
                            │
                            ↓
┌──────────────────────────────────────────────────────────────────┐
│                   USERS / MISSION MAKERS                          │
│                                                                   │
│  veaf-tools-updater.exe update                                   │
│  ├── Check latest version on GitHub                              │
│  ├── Download published.zip                                      │
│  ├── Verify SHA256 checksum                                      │
│  ├── Extract files                                               │
│  └── Install to mission folder                                   │
│                          ↓                                        │
│                   Mission Tools Ready                             │
│            (veaf.lua, scripts, compile tools, etc)               │
└──────────────────────────────────────────────────────────────────┘
```

## Key Points

### For Developers
- **Tool:** `build-and-release.py`
- **When:** When releasing a new version
- **What:** Everything - compile, package, publish
- **How:** One command: `python build-and-release.py --version 6.0.2 --publish`
- **Result:** Release is live on GitHub immediately

### For Users
- **Tool:** `veaf-tools-updater.exe`
- **When:** Whenever you want the latest tools
- **What:** Download and install the latest release
- **How:** One command: `veaf-tools-updater.exe update`
- **Result:** Tools are updated automatically

## Workflow Comparison

### Developer Workflow
```
1. Make changes
   ↓
2. Update version in package.json
   ↓
3. Run: python build-and-release.py --version 6.0.2 --publish
   ↓
4. Done! Release is live
```

**Time:** ~5 minutes (including compilation)

### User Workflow
```
1. Run: veaf-tools-updater.exe update
   ↓
2. Done! Tools are updated
```

**Time:** ~1 minute

## Benefits of This Architecture

### Separation of Concerns ✅
- Developers: Build & release
- Users: Update & use
- Clear responsibilities

### Automation ✅
- No manual GitHub steps
- No manual file uploads
- Consistent releases

### Simplicity ✅
- Users don't see build complexity
- Developers have one clear tool
- Easy to understand

### Integrity ✅
- SHA256 checksums verified
- Files can't be corrupted
- Secure distribution

### Version Control ✅
- Git tags for every release
- Easy to track versions
- Easy to rollback if needed

## File Structure

```
VEAF-Mission-Creation-Tools/
├── build-and-release.py          ← For developers
├── src/python/veaf-tools/
│   ├── veaf-tools-updater.py     ← Compiled to .exe for users
│   └── ... (other tools)
├── published/                     ← Release artifacts
│   ├── veaf.lua
│   ├── veaf-tools.exe
│   ├── veaf-tools-updater.exe
│   └── ... (all release files)
├── published.zip                  ← What users download
├── RELEASE_NOTES.md              ← Release documentation
├── README.md                     ← Overview and quick start
├── BUILD_WORKFLOW.md             ← Build and release workflow
└── DETAILED_MANUAL.md            ← Technical reference
```

## GitHub Release Structure

After publishing with `build-and-release.py --publish`:

```
GitHub Release: published-v6.0.2
├── Tag: published-v6.0.2          ← Specific version
├── Tag: published-latest (movable) ← Always points to latest
├── Release Notes: From RELEASE_NOTES.md
└── Assets:
    ├── published.zip
    └── SHA256: abc123def456...
```

Users can:
- Download from any version: `published-v6.0.0`, `published-v6.0.1`, etc.
- Download latest: `veaf-tools-updater.exe update` (uses `published-latest` tag)
- Verify integrity: SHA256 checksum automatic

## Security Model

```
Developer creates release
    ↓
built-and-release.py calculates SHA256
    ↓
SHA256 stored with release on GitHub
    ↓
User downloads via veaf-tools-updater.exe
    ↓
veaf-tools-updater.exe verifies SHA256
    ↓
✅ File is authentic and uncorrupted
```

## Next Steps

### For Developers
- Read: `BUILD_WORKFLOW.md` (step-by-step guide)
- Technical details: `DETAILED_MANUAL.md` (complete reference)
- Command: `python build-and-release.py --help`

### For Users
- Read: `VEAF_TOOLS_GUIDE.md` (user documentation)
- Use: `veaf-tools-updater.exe update`
- Done!

---

**Created:** November 2025
**Architecture:** Developer Build + User Update
