# 07 — document the prototype and its verdict

**Status:** ⬜ ready — depends on 05 and 06.

## Reference pages

Both languages, per `CLAUDE.md` §7: `doc/…/assistance.md` **and** `assistance.en.md`, both in the
`mkdocs.yml` nav with their `nav_translations` entry, and any section linked from elsewhere carrying an
**explicit English anchor** identical across both files.

Two audiences, and they want different things:

**For a pilot** — what appears on screen (a screenshot of the checklist image with a highlighted switch),
the four menu entries, and the fact that **steps already done are ticked on start** and that a step can be
**skipped**. Those two behaviours are the good surprises and deserve to be stated rather than discovered.

**For a mission maker** — the `modules: assist:` block, and **how to write a checklist**: a full commented
YAML example, where to put the file (`checklists/` in the mission folder), that an `id` overrides the
shipped one, that a label can be a plain sentence instead of a catalog key, and that only activated
checklists are converted (so an unused catalogue costs nothing). Say plainly which aircraft ships with a
checklist — one.

Run `poetry run docs-check`; the CI `Docs Check` job runs the same command.

## Verdict, in the PRD

Write the outcome into the PRD status line, plainly:

- Does it work in game, for someone who did not write it?
- **Was hand-writing the steps the bottleneck?** This is the decision the whole prototype exists to
  inform: whether generating step data from `clickabledata.lua` + `Macro_sequencies.lua` is worth a lot,
  or whether the real cost sits elsewhere (measuring windows, validating the order with a pilot).
- Did the image display hold up — legibility, screen space, the linear-progress compromise?
- What the multiplayer answer turned out to be (ticket 01's open question).

## Changelog and version

One `[Unreleased]` entry in `CHANGELOG.md`, patch bump in `pyproject.toml` with
`plugin/.claude-plugin/plugin.json` kept in sync (`test_plugin_version.py` enforces the match).

## Also

If anything about the DCS cockpit or picture API bit us along the way — an argument that does not read as
expected, a highlight that misbehaves after a re-slot, a picture that ignores `duration = 0` — add it to
[DCS hook environment boundaries](../../../docs/exploration/DCS-HOOK-ENVIRONMENT-BOUNDARIES.md) or a
sibling note. That file-in-the-repo habit is what this whole investigation argued for; it is worth nothing
if we skip it the first time it applies.
