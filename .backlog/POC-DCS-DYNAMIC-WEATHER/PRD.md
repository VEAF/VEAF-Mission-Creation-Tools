# POC-DCS-DYNAMIC-WEATHER — measure DCS's dynamic weather on our server before using it

Status: ⬜ ready

Origin: the persistent campaign's first server flight (Syria, Privé 1, 2026-11-16).
David wants weather that changes in a mission meant to run for weeks, and asked whether DCS's dynamic weather (cyclones and anticyclones placed in the Mission Editor) can give it.
Nobody at VEAF has tried it on a server, and what is published does not answer: no recent Eagle Dynamics documentation was found, only forum posts from 2014 to 2021 that contradict each other.

Decided (David, 2026-11-17): this lot measures and answers, it builds nothing into the tools; until it has answered, persistent campaigns take the real weather the server bot injects at each load (MizEdit / RealWeather), which means no `_NoMizedit` in their mission name.

## What is not known

Read on the ED forums, 2026-11-17 (sources in the ticket):

- **Evolution during a mission**: one 2018 reply says the weather does not change mid-mission; nothing newer was found either way.
- **Multiplayer**: posts disagree on whether the dynamic weather is synchronised between the server and the clients, or whether each client computes its own clouds and wind. The only official fix found (2.9.6.57650) is a rendering bug ("water follows client aircraft"), which says nothing of sync.
- **From one load to the next**: as far as is known, a load starts again from the weather written in the `.miz`; the campaign save does not hold the weather, and a script can set the fog only (to confirm against the scripting API).

## What to build

One ticket: [01 — a test mission flown on a server, two clients compared](tickets/01-measure-on-server.md).

Done when: the three questions above have a measured answer (with the DCS version, the date, the captures), written into `known-limitations.yaml` as `kind: dcs` entries and into the persistent campaign's doc page, and a recommendation is given to David: dynamic weather for persistent campaigns, or real weather from the bot, or both.
