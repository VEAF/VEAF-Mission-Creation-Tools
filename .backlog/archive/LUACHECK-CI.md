# Lot LUACHECK-CI — add luacheck to the CI Lua quality gate

Status: ✅ done

**Goal**: ensure real static analysis on the Lua side (a blind spot in the quality ratchet — only `stylua --check` formatting was assumed to run). **Investigation revealed the work was already done**: `.github/workflows/lua-ci.yml` has a dedicated `Luacheck` job (installs Lua 5.1 + luacheck via LuaRocks, runs `luacheck src/scripts/veaf/ --config .luacheckrc`), a committed `.luacheckrc` exists, and the job passes green (0 warnings, e.g. PR #473). The Lua quality gate already enforces luacheck.

**Done**: the only real gap was a **stale, self-contradictory `CLAUDE.md`** — its Lua section (§7) tells you to run luacheck, but the workflow step (§8.6) said "`luacheck` is not installed, skip it". Fixed §8.6 to list `luacheck --config .luacheckrc src/scripts/veaf/` alongside `stylua`, note both are CI-enforced (`lua-ci.yml`), and that a missing local install (Windows) means relying on the CI check — never treating the gate as skippable. `copilot-instructions.md` was already correct. No CI/`.luacheckrc`/script changes needed; luacheck stays not-installed locally on Windows (CI is the source of truth).

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| LUACHECK-CI-001 | Investigate the existing CI Luacheck job; fix the stale `CLAUDE.md` §8.6 "not installed, skip it" note to reflect that luacheck is a CI-enforced Lua gate | `CLAUDE.md` | chore | ✅ |
