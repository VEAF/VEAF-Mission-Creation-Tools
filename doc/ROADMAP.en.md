# Roadmap

**The roadmap lives in the repository, not here**:
[`ROADMAP.md`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/ROADMAP.md) holds the
execution order of the open lots, and
[`.backlog/`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/tree/develop/.backlog) the scope
and status of each. Both are kept current alongside the code; this page was not, and still claimed
that the `master` branch carried a v5 release when it moved to v6 on 18 July 2026.

What follows is deliberately short: the three long-term axes, with no dates and no statuses, to place
the project. No delivery date is committed.

## The three axes

**Persistent campaign.** A persistence module saving a mission's state between runs — the DCS units
as well as the VEAF state machines (CAS missions, combat zones, QRA) — and on top of it, dynamic
persistent campaign generation built entirely on VEAF tooling. The dependency path: drop MiST, then
persistence, then the campaign — the first step is done, the VEAF scripts no longer call MiST and it
is no longer injected by default.

**AI-assisted tooling.** Describe a mission in French or English and get its `mission.yaml` with its
spawns and zones — at *design time*, using the mission maker's own AI tooling rather than VEAF
infrastructure. An MCP server already delivers editing a `.miz` and mutating what it contains.
Further along the same axis, a game master improvising a campaign live while the player flies.

**The DCS bridge.** Finish integrating `veaf-dcs-bridge`, the link between a running DCS and an
outside program. It is the shared building block of persistence, of the game master, and of a
real-time dashboard in the browser.

## What already happened

The v6 cycle is complete and published; `master` carries v6. Each version's notable changes are in
the
[changelog](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/CHANGELOG.md).
