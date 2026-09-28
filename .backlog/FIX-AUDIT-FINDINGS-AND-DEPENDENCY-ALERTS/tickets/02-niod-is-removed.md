# 02 — NIOD is removed

Status: ⬜ ready

Source: `davidp57/security-audits#90`, checked against the code and the production logs on
2026-09-28. Decided by David the same day: *"oui, retire NIOD"*.

## What the finding said

`veafRemote.addNiodCallback` (`src/scripts/veaf/veafRemote.lua:55-114`) loses its error message on
both failure paths: `veaf.p(status)` where `retval` holds the `pcall` message (108), and a format
with one `%s` for two values, so the list of bad parameters never reaches the log (96-99). Both
defects are in the code as described.

## Why that code is removed rather than fixed

It cannot run.

* **NIOD itself is gone.** It was a community script, `src/scripts/community/NIOD.lua`, added with
  v2.6.0 (2020-06-23): a LuaSocket TCP server on `127.0.0.1:15487` inside the mission, speaking
  JSON, built on MOOSE, and driven from Node by the `niod-core` npm package, which called the Lua
  functions stored in `niod.functions`. The script was deleted on 2025-09-25 (`74df68a3`, first
  version of the scripts injector). Nothing in the repository defines the `niod` global any more.
* **Nothing registers a callback anyway.** `veafRemote.buildDefaultList()` declares `test` and
  `login` under `local TEST = false` (128-155). The audit read past that guard when it wrote that
  `login` is registered.
* **Production agrees.** The six `dcs.log` of `dcs.veaf.org` carry neither
  `Adding NIOD function` nor `NIOD is not loaded` — the two lines this code logs on either branch.

Fixing two lines nothing calls, and testing them, maintains dead code the next audit will read
again. The dead `login` path also logs the password in clear (147, `TODO remove password from log`).

## What to remove

In `src/scripts/veaf/veafRemote.lua`:

* the *NIOD callbacks* section and `veafRemote.addNiodCallback`;
* the comment block about `addNiodCommand` (116-121), which only makes sense next to it;
* `veafRemote.buildDefaultList()` and its *default endpoints list* banner, since its whole body is
  the dead `if TEST` block, and the call to it in `veafRemote.initialize()`.

What stays untouched: `registerRemoteModule` / `executeCommandFromRemote` and the SLMOD side.

Also:

* `test/lua/test_veafRemote.lua` — `TestVeafRemoteBuildDefaultList` goes; the test around line 390
  that stubs `buildDefaultList` no longer needs to; add `addNiodCallback` and `buildDefaultList` to
  the assertions that pin removed entry points (next to `test_addNiodCommand_is_gone_too`).
* `doc/mission-maker/scripts/README.md` / `.en.md`, line 93: the `veafRemote.lua` row says
  *NIOD / SLMOD*; it becomes SLMOD only.
* `CHANGELOG.md`: one entry — NIOD support removed, it had not worked since the script left the
  repository.

## Check

`git grep -niE 'niod'` over `src/`, `test/lua/` and `doc/` returns nothing but the new absence
assertions; `poetry run test-lua` and the Lua gate pass; `docs-check` passes.
