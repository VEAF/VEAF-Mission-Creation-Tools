# 02 — What the players know of the enemy

Status: ⬜ ready

David: "les forces rouges doivent rester mystérieuses. on a des renseignements qui peuvent être plus ou moins bons mais on ne connait pas le détail des forces — sauf pour les trucs fixes comme un SA10".

The intelligence picture of each enemy zone, built from what the campaign knows and never more:

- **Never a count**, neither of a garrison nor of the enemy reserve. The friendly side's positions and reserves are known and stated.
- **Qualitative, with the reliability of its source.** The prototype derives it from the zone's size class and kind: an airfield, "position principale, activité blindée et mécanisée signalée, défense aérienne longue portée probable, type non confirmé (imagerie, plutôt fiable)"; a logistics zone, "centre logistique actif (sources locales, non recoupées)"; an outpost, "présence signalée, volume et nature inconnus (renseignement fragmentaire)". A zone of `campaign.yaml` may override its text.
- **Fixed sites named once known.** A long-range SAM's type is drawn when the mission starts: unknown before mission 1. After it, the campaign state records each garrison unit by type; the long-range SAM of a zone is named ("SA-10 confirmé à Senaki"). Decide which types count as fixed — the long-range SAMs at least — from the air-defence data the garrison generator already uses, not from a list typed here.
- What the players saw in flight is not tracked; a destroyed fixed site is said destroyed, from the state.

## Done when

Tests: an enemy zone before mission 1 has no type and no figure; after a state with a recorded long-range SAM, the type is named; a destroyed one is said destroyed; the friendly side gets its figures; no enemy figure appears anywhere in the generated text.
