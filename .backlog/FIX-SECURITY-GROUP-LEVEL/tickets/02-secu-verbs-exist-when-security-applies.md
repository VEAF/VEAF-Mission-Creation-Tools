# 02 — `/secu elevate` exists whenever the refusal tells a pilot to type it

Status: ⬜ ready

The per-group check in `veafRadio._proxyMethod` applies whenever `veaf.SecurityDisabled` is false, whether or not `SECURITY` is listed in `mission.yaml`; the `/secu` verbs exist only when it is.
`mission_template.py` writes `# SECURITY: true` commented out ("uncomment + add password_hashes … to require a password"), the shipped default `src/defaults/mission-folder/mission.yaml` has it on — so a mission scaffolded from the template refuses with a message pointing to a command it does not have.

Recommended (Claude, 2026-10-10): register the `secu` remote module and the marker handler regardless of the `SECURITY` entry — the check they belong to is not optional, so their verbs should not be — and reword the template's comment, which describes passwords rather than the module.
The alternative, wording the refusal differently when `SECURITY` is off, keeps two behaviours for one check; it is the fallback if making the module mandatory breaks a mission that relies on turning it off.

- Lua test: with `SECURITY` absent from the config, `/secu elevate` from the remote path reaches `veafSecurity.executeCommandFromRemote`.
- Defaults lockstep (`CLAUDE.md` §9.7): `mission_template.py` and `src/defaults/mission-folder/mission.yaml` say the same thing.
