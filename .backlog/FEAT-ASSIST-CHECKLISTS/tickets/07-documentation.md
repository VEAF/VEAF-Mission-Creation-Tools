# 07 — document the prototype and its verdict

**Status:** ✅ done — pages written, and the verdict written after the flight of 2026-08-01 (in the PRD).

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

## What was written

- [`doc/mission-maker/scripts/veafAssist.md`](../../../doc/mission-maker/scripts/veafAssist.md) and its
  `.en.md`, in the `mkdocs.yml` nav, with explicit English anchors. Two audiences in one page: what a
  pilot sees (including the two good surprises — already-done steps ticked on start, and skipping), and
  how a mission maker writes a checklist, with a fully commented example and where the element name and
  the animation argument are read from.
- The `ASSIST` row in both `MISSION_YAML_REFERENCE` tables.
- A sibling exploration note,
  [DCS cockpit + picture API](../../../docs/exploration/DCS-COCKPIT-ASSISTANCE-API.md), holding the six
  facts this lot cost us to learn: the cockpit trigger actions are plain functions in the mission
  environment; `a_out_picture_u` with `seconds = 0` stays up (ED's own comment, with the full
  signature); a spring-loaded switch cannot be detected by its animation argument; a command's `value`
  is not necessarily that argument; `Macro_sequencies.lua` is the real source for a start-up order and
  writing one from switch labels produces something plausible and wrong; and not every name in a
  cockpit is an element you can box.
- `CHANGELOG.md` `[Unreleased]`, and the patch bump 6.13.1 → 6.13.2 in `pyproject.toml` +
  `plugin/.claude-plugin/plugin.json`.

`poetry run docs-check` is clean.

## The verdict

Written into the [PRD](../PRD.md) after David flew it on 2026-08-01. In short: it works; hand-writing
the steps was **not** the bottleneck, which deprioritises the step-data generator lot; the image
display holds up once `size` and the resource cache are understood; multiplayer is still untested.

The exploration note grew a section 3 for the finding that shaped the whole lot — a cockpit control's
position cannot be read — and the flight added two more facts to it: the primitives live in the
**trigger** environment, reachable only through `net.dostring_in("mission", …)`, and DCS **caches
embedded resources by name**, so a rebuilt mission can show a stale picture.
