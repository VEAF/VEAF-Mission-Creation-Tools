# 01 — Rename the hook's global table

Status: ✅ done 2026-08-16 — renamed to `veafFiddle`, guard added, **confirmed in game**
Type: fix
Files: `src/scripts/other/dcs-fiddle-server.lua`, `test/python/veaf_libs/test_dcs_fiddle_token.py`

## The change

`veaf = {}` becomes `veafFiddle = {}`, and its five functions follow: `sanitizedModule`,
`tokenFilePath`, `generateToken`, `writeToken`, `readToken`. A comment at the declaration says why
the name matters, because the next person to re-sync this file from upstream will re-apply the VEAF
patch and needs to not re-introduce it.

No other caller: `sanitizedModule` was grepped across `*.lua`, `*.py` and `*.md` and appears only in
the hook itself, its own ADR/backlog prose, and the CHANGELOG. `FIDDLE.USERNAME = 'veaf'` is a
string and stays.

## The guard

Two greps in `test_dcs_fiddle_token.py`: no line assigning the global `veaf`, no line defining
`function veaf.…`. Plus a third asserting the hook file is where the guard looks — a moved file
would make both of them pass by finding nothing.

## Deploying it to a workstation

Nothing copies this file automatically (the hook is hand-deployed, and it is deliberately not
something a build installs). To pick the fix up:

```bash
cp src/scripts/other/dcs-fiddle-server.lua "$USERPROFILE/Saved Games/DCS/Scripts/Hooks/dcs-fiddle-server.lua"
```

Then reload the mission. The confirmation is negative-shaped: **no** `attempt to index field
'loggers'` in `dcs.log`, and a CTLD entry in the F10 menu.

The other way to confirm the diagnosis without deploying anything is to remove the hook entirely and
reload — the errors and the missing menu should both disappear.
