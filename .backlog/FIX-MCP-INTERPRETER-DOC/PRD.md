# Lot FIX-MCP-INTERPRETER-DOC — teach the skill the `#veafInterpreter` idiom

Status: ✅ done (PR pending → `feature/mcp-mission-editor`)

Branch: `docs/mcp-interpreter-guidance` → PR → `feature/mcp-mission-editor`

## Context

Real-usage feedback (David watching the plugin author a Syria mission): to place a **permanent**
SAM, the assistant left the MCP and invoked the external `dcs-mission-tools@bfr` plugin's
`vmct-expert` agent to look up the exact `#veafInterpreter` format.

Verified at the source: the format our MCP already exposes is **correct** — `veafInterpreter.lua`
defines `Starter = #veafInterpreter["` and `Trailer = "]`, i.e. `#veafInterpreter["<cmd>"]`, exactly
what the skill (l.48) and the oracle's `describe_naming_conventions` (`interpreter_command`) state.
The assistant could compose `#veafInterpreter["-samLR"]` from our MCP alone (format + alias via
`list_shortcuts`).

Root cause of the detour: our doc mentions `#veafInterpreter` **minimally** — one line, no concrete
example, and no guidance on *permanent* (`#veafInterpreter`) vs *combat-zone dynamic* (`#command`).
So the assistant sought a richer source. Recurring pattern: thin MCP doc → the LLM looks elsewhere
(here an external, trustworthy plugin, but the MCP should be self-sufficient — a maker without it
wouldn't have it, and it costs a round-trip).

## Change

- `plugin/skills/veaf-mission-authoring/SKILL.md`:
  - combat-zone section gains a "permanent asset vs combat-zone asset" note:
    `#veafInterpreter["<alias>"]` on a unit name = spawned **at start, permanent** (carrier
    destroyed), with a worked example (blue unit named `#veafInterpreter["-samLR"]` → permanent blue
    LR SAM); `#command="-<alias>"` on a combat-zone fake-unit = spawned on **zone activation**. Both
    use `list_shortcuts` aliases and spawn in the carrier's coalition.
  - **autonomy directive** in the oracle section: the oracle + skill are the authoritative source
    for VEAF facts; do not invoke other tools/agents nor read the framework's Lua source (a maker's
    machine has neither) — re-query the oracle or state the gap. Discourages the detour that
    surfaced this (the assistant used an external plugin's VMCT KB and the local framework repo).

Docs only — the format was already correct; no code/behaviour change.

## Note on testing

The assistant reaching into the **local framework repo** (`D:/dev/_VEAF/VEAF-Mission-Creation-Tools`)
via the BFR `dcs-mission-tools` `vmct-expert` agent means a dev machine's test is **not
representative** — a maker has neither the repo nor necessarily that plugin. The directive above is
the in-band mitigation; a truly representative test needs an env without the local repo / BFR plugin.

## Out of Scope

- Changing `#veafInterpreter` behaviour or the oracle's `interpreter_command` rule (already correct).
