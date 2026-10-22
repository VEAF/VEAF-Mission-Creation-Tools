# 01 — "Texaco" refused for a tanker

Status: ⬜ ready

The AI: "the tools reject `Texaco` as a Tanker callsign family"; the KC-135 was named `Enfield` instead.
Texaco is DCS's first tanker callsign (Texaco = 1, Arco = 2, Shell = 3), and the authoring guide itself names it as the example.

Measure on GermanyCW: `add_air_group` (or the support composite the AI used) with a KC-135 named Texaco — what is refused, by which check, with which message.
Suspects: the callsign-family reading of `aircraft_identity.py` (a bare family word, or the family taken from the name), or a family list that differs for a tanker or for this map's country.

Done when: a KC-135 tanker named Texaco gets the Texaco family, with a test; or the refusal is shown to be right and the guide says what to do instead.
