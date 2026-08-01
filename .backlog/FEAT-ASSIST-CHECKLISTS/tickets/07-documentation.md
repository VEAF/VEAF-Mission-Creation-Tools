# 07 — document the prototype and its verdict

**Status:** 🧑 waiting-human — the pages are written; **the verdict is not**, and cannot be, until the
prototype has been flown. See the end of this ticket.

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

## The verdict is still missing, deliberately

The four questions this ticket asks are the point of the whole lot, and **not one of them can be
answered from a green test suite**:

- *Does it work in game, for someone who did not write it?* — unflown.
- *Was hand-writing the steps the bottleneck?* — the honest partial answer is **no, not the writing**.
  Six steps took minutes once `Macro_sequencies.lua` was found; what actually cost time was deciding
  *which* slice, noticing the JFS switch is spring-loaded, and the windows — which are still derived
  rather than measured. That points at the generator lot being worth **less** than expected and the
  measuring being worth more, but it is a hypothesis until someone has written a second checklist.
- *Did the image display hold up?* — the pictures were reviewed at their rendered size and read well;
  nobody has yet seen one **through `a_out_picture` over a cockpit**, which is the only view that
  settles legibility, screen space and the alignment/size values.
- *What is the multiplayer answer?* — unknown; the per-session highlight id exists for it.

These belong in the PRD status line once flown. Writing them now would be inventing them.
