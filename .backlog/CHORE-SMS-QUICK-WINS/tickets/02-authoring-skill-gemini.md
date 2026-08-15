# 02 — Ship the authoring skill to Gemini too

Status: 🧑 waiting-human — everything is delivered; one command validates it
Type: feat
Files: `plugin/skills/veaf-mission-authoring/`, the installer path, install doc

## Situation

`plugin/skills/veaf-mission-authoring/SKILL.md` exists and is **Claude-only**. Verified 2026-08-05:
`plugin/skills/` holds that one skill and nothing targets Gemini, while Gemini is configured on
David's machine.

dcs-sms ships `install-ai-skill --agent=all`, writing into `~/.claude/skills/`, `~/.agents/skills/`
and `~/.gemini/{commands,skills}/`. The mission maker with Gemini gets nothing from us today.

## Behaviour

- Install the existing skill into Gemini's locations as well, without forking its content — **one
  source, several destinations.** Two copies of the same guidance drift, and the drift is silent
  because nobody reads both.
- If the formats genuinely differ (Gemini's command/skill layout is not Claude's), the difference
  belongs in a thin adapter at install time, not in a second maintained document. Establish which it is
  before writing anything: if adaptation turns out deep, say so and scope accordingly rather than
  half-porting.
- Respect the existing distribution: the plugin is self-hosted in this repo and keeps `veaf-tools`
  current on its own (`FEAT-MCP-PLUGIN`). Whatever installs the skill should fit that, not invent a
  parallel channel.

## Tasks

- [x] Determine what Gemini actually needs — directory layout and file format — before designing.
- [x] Install to Gemini's locations from the same source file.
- [x] Install doc updated: which agents are supported, where files land, how to remove them.
- [x] Do not write into a user's home directory without saying so in the doc — an installer that
      quietly seeds `~` is unpleasant to discover.

## Acceptance criteria

- [ ] The skill is usable from Gemini on a clean machine, tested rather than assumed.
- [x] Exactly one authoring-guidance source in the repo.
- [x] `docs-check` clean.

## Delivered — 2026-08-11

**The finding that shaped everything: the adaptation is not deep at all.** Gemini CLI extensions expose
agent skills at `<root>/skills/<name>/SKILL.md`, with a `SKILL.md` carrying `name`/`description`
frontmatter — the same layout and the same format as a Claude Code plugin. Read from the Gemini
extension reference, not assumed.

So there is no adapter and no second document. `plugin/` now carries **two manifests side by side**:

| File | Read by |
|---|---|
| `plugin/.claude-plugin/plugin.json` + `plugin/.mcp.json` | Claude Code |
| `plugin/gemini-extension.json` | Gemini CLI |
| `plugin/skills/veaf-mission-authoring/SKILL.md` | **both, unchanged** |

Nothing about the Claude plugin was touched, which was deliberate: it is installed in production on
David's machine and a "one source" refactor that breaks the working side is not an improvement.

### The compromise, stated rather than buried

`gemini extensions install` accepts a GitHub URL or a local path and expects `gemini-extension.json` at
the root of what it is given. Ours is in `plugin/`, so the install is `git clone` then
`gemini extensions install <clone>/plugin` — two commands, not one.

The alternative was a manifest at the repository root, which Gemini has **no field to reconcile with a
skill folder elsewhere** (`name`, `version`, `description`, `mcpServers`, `contextFileName`,
`excludeTools`, `migratedTo`, `plan`, `settings`, `themes` — none redirects the `skills/` scan). That
would mean either a second copy of the skill or moving `skills/` out from under the Claude plugin. Both
cost more than one `git clone`, so the clone won.

### What was deliberately not ported

The `veaf-tools` binary auto-install is a Claude Code `SessionStart` hook. Gemini has hooks, in its own
format, and nobody here has ever exercised them — writing that blind is precisely how
`FEAT-DCS-SMOKE-HARNESS` earned three defects against calls it had never made. The Gemini manifest calls
plain `veaf-tools`, so it must be on `PATH`, and the install page says so in both languages.

### Guards

`test_plugin_version.py` was one test and is now four: the version lockstep runs over **both** manifests
(parametrised, so a third agent is one dict entry), the two manifests must declare the **same MCP server
name** — the shared `SKILL.md` refers to the server's actions, so a mismatch would make the same text
wrong on one side, silently — and the skill must sit where both agents look, which fails if someone
"tidies" it into a second copy.

## Why this is 🧑 and not ✅

The acceptance criterion says *usable from Gemini on a clean machine, **tested rather than assumed***,
and it is the one thing not done: **Gemini CLI is not installed here.** Measured, not guessed —
`~/.gemini/` holds only OAuth state, history and `settings.json`, with no `commands/`, `skills/` or
`extensions/` directory, and `gemini` is not on `PATH`. Installing it would change David's environment
without asking.

So the format is verified against the vendor's reference, the layout is verified against our own tree,
and **the round trip is not**. Three commands close it:

```powershell
git clone https://github.com/VEAF/VEAF-Mission-Creation-Tools.git
gemini extensions install VEAF-Mission-Creation-Tools/plugin
gemini extensions list
```

Then, in a new session, confirm the assistant knows the VEAF conventions (ask it for a combat zone and
watch whether it consults the oracle actions). If Gemini rejects the manifest or ignores the skill, the
fix is a manifest field, not a redesign.
