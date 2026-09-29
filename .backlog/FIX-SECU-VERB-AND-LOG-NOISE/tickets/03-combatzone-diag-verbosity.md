# 03 — the combat-zone watchdog logs its whole inventory at INFO

Status: ⬜ ready

private1, 2026-09-29, 90 minutes of log: **2 506 `VEAF-COMBATZONE` lines**, 2 500 of them from the
watchdog re-listing what it sees, per zone, roughly every 70 seconds:

```
VEAF-COMBATZONE|I|46312: DIAG|zone …: watchdog sees [r]-India Platoon#10525 #152: static
VEAF-COMBATZONE|I|46312: DIAG|zone …: watchdog sees [r]-Hydra Knights#10530: 7 alive (SA-18 Igla-S…
```

Ten such lines per pass, per active zone, at **INFO**. On a server with several zones running, this
is most of the log, and it buried the security lines this session was actually reading.

These `DIAG|` lines look like the instrumentation added for
`FIX-COMBATZONE-DEAD-UNIT-HAS-NO-GROUP` ticket 03 ("diagnostics for a watched session"). That
diagnosis is done — the panel now counts statics.

## Done when

- The per-unit watchdog inventory logs at `debug`, so a watched session still gets it by raising
  the module's level, and a normal server does not.
- What stays at INFO is decided explicitly and is about events, not inventory: a zone activating,
  completing, being requested. An activation line was genuinely useful this session.
- A test on whichever function decides the level, so the choice does not drift back.
