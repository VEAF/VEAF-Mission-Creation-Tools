# 02 — Ship the authoring guide and the mission prompts

Status: ⬜ ready

Move `plugin/skills/veaf-mission-authoring/SKILL.md` and the four `.prompts/new-*-mission.{fr,en}.md` into `veaf_mission_mcp/data/`, bundled by the build. New action `describe_mission_prompt(kind, lang)`. The guide tells the AI: a user who asks for a mission gets asked which of the two kinds, then the prompt is loaded and followed.

Done: the action returns each of the four texts, from the package data; the guide names the action.
