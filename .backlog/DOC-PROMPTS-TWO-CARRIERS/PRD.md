# DOC-PROMPTS-TWO-CARRIERS — every generated mission with a carrier group gets the Stennis and the Roosevelt

Status: 🧑 waiting-human

Asked by David on 2026-10-02, while building the Syria Open Training v6 from the Open Training prompt:
"note dans les prompts — celui qui génère une OT et celui qui génère une mission one-shot — de toujours
ajouter 2 CVN : le Stennis et le Roosevelt, à toutes les missions générées qui utilisent un groupe
aéronaval".

The two prompts (`.prompts/new-open-training-mission.*.md`, `.prompts/new-objective-mission.*.md`)
described one `add_carrier_group`. They now say two, the Stennis and the Roosevelt, each with its own
TACAN, ICLS, Link 4 and frequencies. No code change: `add_carrier_group` already places either type
(`Stennis`, `CVN_71`).

One ticket.
