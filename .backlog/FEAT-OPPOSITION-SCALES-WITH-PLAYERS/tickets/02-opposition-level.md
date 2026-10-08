# 02 — An opposition level, set at generation, changed in flight, or followed automatically

Status: ⬜ ready

David's three ways, all of them, one mechanism:

- **A level**, a small integer the mission carries (`opposition: { level: … }` in `mission.yaml`, set at generation — `campaign next --players 6`, or Claude through the MCP).
- **Changed in flight** by the game master or a mission master, from the radio menu or a command (`_opposition 3`), behind the usual security tier.
- **Followed automatically** when the mission says so: the level tracks the blue players connected (`coalition.getPlayers`), or the blue aircraft airborne, re-read on a beat, with a hysteresis so that one player leaving does not flip it back and forth.

What the level drives, in this lot: the QRA tiers (the tier a QRA scrambles is chosen from the level when the QRA says so, from the enemies in its zone otherwise) and the on-demand CAP missions (how many groups they send). Message the change to everybody when it happens.

## Done when

Lua tests: the level from players connected and from aircraft airborne, the hysteresis, the command and its security, a QRA following the level; Python: the `mission.yaml` block and the `--players` option. The doc page of the QRA module and the mission-maker guide say how to choose.
