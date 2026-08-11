# 02 — Untrusted text into executed code, at five layers

Status: ✅ done — delivered 2026-08-06; the server hook was deployed on 2026-08-11, so nothing is outstanding
Type: fix
Findings: VMR-001 🔴, VMR-002 🔴, VMR-004 🟠, VMR-010 🟡, VMR-012 🟡, VMR-013 🟡

## The pattern

Text somebody else controls is concatenated into a string that is then **executed** — as Lua, or as a
shell command. The review found it at five layers and argues, rightly, that fixing five instances
without a shared helper leaves a sixth to be written next month.

| Layer | Finding | Outcome 2026-08-06 |
|---|---|---|
| Server hook builds Lua from a player name | **VMR-001, VMR-002** 🔴 | ✅ fixed and **deployed 2026-08-11** |
| `veafRadio` builds a shell command from marker text | **VMR-004** 🟠 | ✅ fixed |
| `lua_config_generator` interpolates `mission.yaml` into generated Lua | VMR-012 🟡 | ✅ fixed |
| `spawn_data_emitter` escapes only `\` and `"` | VMR-010 🟡 | ✅ fixed |
| `dcs-fiddle-server` runs arbitrary Lua from unauthenticated HTTP | VMR-013 🟡 | 📄 decided, deferred — [ADR 0019](../../../docs/adr/0019-dcs-fiddle-server-stays-unauthenticated-for-now.md) |

## The two criticals

`REGISTER_PLAYER` is a Lua chunk with three `%s`, filled by `string.format(REGISTER_PLAYER,
playerName, pilot.level, ucid)` at three call sites and handed to `injectCode()`, which runs
`net.dostring_in('mission', 'return a_do_script([===[' .. payload .. ']===])')`. Nothing escapes the
name. A name carrying the right characters closes the literal and runs as code, in the mission
environment. VMR-002 is the same on the **connect** path, so no authentication is involved.

The review's fix is the obvious one and the right one: `string.format('%q', …)` on every value the
hook injects. `%q` is Lua's own quoting, which escapes quotes, backslashes and newlines.

- [ ] Escape every injected value in `VEAF-Server-hook.lua`, not just the three player-name sites —
      audit the whole file for `string.format` feeding `injectCode`.
- [ ] Guard the long-bracket level too: `[===[` is only safe until a payload contains `]===]`. `%q`
      handles the inner quoting; consider whether the outer bracket needs a computed level.
- [ ] Test with names holding quotes, backslashes, newlines and `]===]`.

## The shell one

`veafRadio` builds `start /min "%s" "%s\\%s" … -n "%s" …` and calls `l_os.execute`. A double quote in
an interpolated value escapes its argument. Quoting is not enough on Windows `cmd`; prefer a
whitelist on the values that reach it (the review's §4 suggests validating rather than escaping when
the value has a small legal shape, which callsign/frequency do).

## The caveat on VMR-013, which is new since the review

`dcs-fiddle-server.lua` running unauthenticated Lua over HTTP is exactly what
`FEAT-DCS-SMOKE-HARNESS` was built on this week: the harness POSTs base64 Lua to `127.0.0.1:12081`.
Hardening it — a token, a loopback-only bind, an allowlist — **will break the harness** unless the two
are designed together.

It binds to `127.0.0.1` already, so the exposure is local rather than remote; the review's concern is
that anything on the machine can drive DCS. Decide deliberately: leave it and document the assumption,
or add a token the harness also carries. Do not silently harden it and discover the harness is dead.

## Do the Python side with the helper that already exists

`_emit_lua_string` / `_lua_long_string` were added by FIX-ASSETS-NEWLINE and are simply not used
everywhere. Route `lua_config_generator` (VMR-012) and `spawn_data_emitter` (VMR-010) through them
rather than writing a third escaping scheme.

- [ ] One shared helper, used by every Python site that emits Lua.
- [ ] A test that feeds each emitter a value containing `"`, `\`, a newline and `]]`, and asserts the
      output parses back to the same string.

## Acceptance criteria

- [x] A player name carrying quotes/backslashes/newlines cannot execute code — proven by test, and the
      hook change **deployed on 2026-08-11** by David, since the repo copy is only the source of what
      runs. Version 2.7.1 carries both halves of the fix: `%q` in the `REGISTER_PLAYER` format, and
      `%q` around the whole payload in `injectCode` — the first alone was not enough, because `%q`
      does not escape `]` and the payload used to be wrapped in a long bracket.
- [ ] Every Python Lua-emission site routes through one helper; adding a sixth site without it should
      be visibly wrong.
- [ ] The VMR-013 decision is written down, whichever way it goes, with its effect on the harness.

---

## Delivered 2026-08-06

**The two criticals needed two fixes, not one, and that was measured rather than reasoned.**
Switching the templates to `%q` closes the obvious hole — a quote in a player name no longer ends
the argument. It does not close the second one: `%q` escapes quotes, backslashes, newlines and
carriage returns, and **not `]`**, so a name containing `]===]` still terminated the long bracket
`injectCode` wrapped the payload in.

The first breakout written to prove that failed to compile, which looked like good news and was not:
the transport chunk is `return a_do_script(…)`, and Lua forbids a statement after a `return`, so a
*statement*-shaped attack is only a crash. An *expression*-shaped one needs no statement — a name of
`x]===]..tostring(BEACON())..[===[y` is concatenated into the argument and evaluated as the call is
made. That executed. `injectCode` now quotes the payload with `%q` as well, which removes the
bracket problem rather than computing a safe bracket level around it.

The hook had never had a test. `test/lua/test_veafServerHook.lua` loads the real file with a stubbed
`lfs` and drives the real DCS callbacks; the payload is detonated in a sandbox where the only way to
set the beacon is attacker code. 7 of its 9 tests fail without the fix. Writing it caught one of my
own errors worth recording: the first version used `-code` where the parser wants `/code`, so
`_module` came back nil, and `test_command_argument_executes_nothing` **passed without the attack
ever reaching the payload** — a tautological green of exactly the kind this lot keeps finding.

**VMR-004 turned out to need no authentication at all.** `markTextAnalysis` reads the F10 marker
text, and the transmit path has no `veafSecurity` check anywhere on it, so any player reached
`os.execute` on the server's host. Free text is stripped, small-shape values are validated — the
review's own advice, and the right split: you cannot whitelist a spoken sentence, and you should not
merely clean a frequency list.

**The Python half wanted two forms, not one.** Forcing both emitters onto the single "readable"
helper broke two `spawn_data_emitter` tests, and the reason was worth having: that output is read
back by the bundled `luadata` parser, which **implements no long strings at all** — probed directly,
along with the fact that it does not decode `\n` either. So `veaf_libs/lua_literals.py` offers both
primitives and documents which reader each is for. One module, two correct forms, no hand-rolling —
which is what "one shared helper" has to mean when the outputs have different readers.

**VMR-013 is decided, not done** — [ADR 0019](../../../docs/adr/0019-dcs-fiddle-server-stays-unauthenticated-for-now.md).
Its severity is understated in the review: `cors = "*"` plus a `GET` channel means a web page, not
just a local process. The docs now warn where the hook is installed; the token lands with the
harness slice that can test it.

## What is left on this ticket

- [x] **Deploy the hook to the VEAF servers** — done 2026-08-11. Checked before asking, because the
      concern raised was that a v6 hook would break v5 missions: it does not. The three functions the
      hook calls mission-side (`registerUser`, `registerUserSlot`, `executeCommandFromRemote`) have
      carried the same signatures since v5, and every payload is wrapped in an existence test, so an
      older mission is a no-op rather than a crash. The real deployment risk was elsewhere and worth
      recording: the pilots list moved to the shared `Saved Games/` root (one level above the server
      folder), and without it the hook denies every command — which its own error message states.
- [ ] `src/scripts/Hooks/` is under **no** `luacheck` or `stylua` gate — both CI jobs are scoped to
      `src/scripts/veaf/`. The one file in the repository carrying two critical findings is the one
      file nothing lints. Out of scope here; worth its own change.
