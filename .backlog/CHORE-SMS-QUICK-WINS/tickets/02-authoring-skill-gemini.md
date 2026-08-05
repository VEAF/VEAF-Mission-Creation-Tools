# 02 — Ship the authoring skill to Gemini too

Status: ⬜ ready
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

- [ ] Determine what Gemini actually needs — directory layout and file format — before designing.
- [ ] Install to Gemini's locations from the same source file.
- [ ] Install doc updated: which agents are supported, where files land, how to remove them.
- [ ] Do not write into a user's home directory without saying so in the doc — an installer that
      quietly seeds `~` is unpleasant to discover.

## Acceptance criteria

- [ ] The skill is usable from Gemini on a clean machine, tested rather than assumed.
- [ ] Exactly one authoring-guidance source in the repo.
- [ ] `docs-check` clean.
