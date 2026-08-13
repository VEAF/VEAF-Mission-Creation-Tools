# veafCommands — The marker-command dispatcher

**Module ID:** `COMMANDS` | **File:** `veafCommands.lua`

---

## Purpose

The **single entry point** for every command players type into an F10 marker. One DCS event handler
is registered; it then tries each module in a fixed order until one consumes the command.

This page is for **developers** and module authors: a mission maker configures nothing here.

---

## What the module guarantees

**Every command declares its security tier, and forgetting is refused at load time.** Four handlers
out of nine had drifted to "no check at all" with nothing noticing (`SECREV-2`): the tier is now an
argument with no default, and a module that does not declare one does not register.

| Declared value | Meaning |
|----------------|---------|
| `ADMIN` · `SENIOR_PILOT` · `KNOWN_PILOT` | The dispatcher applies the check **before** the handler, on the identity of the marker's author |
| `OPEN` | Open to everyone — said explicitly, rather than achieved by leaving the tier out |
| `veafCommands.SECURITY_HANDLED` | The handler checks for itself, because it reads a password out of the marker text; the dispatcher does not double-check |

The old `L0` / `L1` / `L9` names are accepted for one release and log their deprecation once per
name. An unknown name raises an assertion at registration.

**An unknown tier at dispatch time denies the command** rather than letting it through: registration
already forbids one, so reaching that state means the table was edited at run time.

---

## The order of attempts {#priorities}

Handlers are tried in ascending priority. The first to return `true` consumes the event and the
marker is removed.

| Priority | Module |
|----------|--------|
| 10 | `veafShortcuts` — aliases, which rewrite themselves into raw commands |
| 20 | `veafSpawn` |
| 30 | `veafNamedPoints` |
| 40 | `veafCasMission` |
| 50 | `veafSecurity` |
| 60 | `veafMove` |
| 62 | `veafGroundAI` |
| 70 | `veafRadio` |
| 80 | `veafRemote` |

Aliases come first **by construction**: they translate `-sa6` into `_spawn group, name ...` before
any module sees the text.

---

## The bypass path {#bypass}

`veafInterpreter` runs, at mission start, the commands the mission maker wrote into **unit names**.
That path **bypasses the security check** deliberately: those commands come from the mission's
author, not from a player. It is pinned by a test, so that changing it has to be deliberate.

---

## `mission.yaml` configuration

None. The module is infrastructure: it always loads.

---

## See also

- [veafSecurity](veafSecurity.en.md) — the tiers, and what an unlisted pilot has to do
- [veafShortcuts](veafShortcuts.en.md) — aliases, served first
- [veafInterpreter](veafInterpreter.en.md) — commands inside unit names
