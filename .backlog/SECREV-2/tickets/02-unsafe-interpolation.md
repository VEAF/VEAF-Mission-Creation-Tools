# 02 — Untrusted text into executed code, at five layers

Status: ⬜ ready
Type: fix
Findings: VMR-001 🔴, VMR-002 🔴, VMR-004 🟠, VMR-010 🟡, VMR-012 🟡, VMR-013 🟡

## The pattern

Text somebody else controls is concatenated into a string that is then **executed** — as Lua, or as a
shell command. The review found it at five layers and argues, rightly, that fixing five instances
without a shared helper leaves a sixth to be written next month.

| Layer | Finding | State on 2026-08-05 |
|---|---|---|
| Server hook builds Lua from a player name | **VMR-001, VMR-002** 🔴 | **live**, verified by hand |
| `veafRadio` builds a shell command from marker text | **VMR-004** 🟠 | **live** — `l_os.execute(cmd)` |
| `lua_config_generator` interpolates `mission.yaml` into generated Lua | VMR-012 🟡 | file changed since; read the diff |
| `spawn_data_emitter` escapes only `\` and `"` | VMR-010 🟡 | untouched |
| `dcs-fiddle-server` runs arbitrary Lua from unauthenticated HTTP | VMR-013 🟡 | untouched — **see the caveat** |

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

- [ ] A player name carrying quotes/backslashes/newlines cannot execute code — proven by test, and the
      hook change **deployed**, since the repo copy is only the source of what runs.
- [ ] Every Python Lua-emission site routes through one helper; adding a sixth site without it should
      be visibly wrong.
- [ ] The VMR-013 decision is written down, whichever way it goes, with its effect on the harness.
