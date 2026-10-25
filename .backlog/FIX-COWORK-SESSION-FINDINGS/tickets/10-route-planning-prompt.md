# 10 — Route planning in the objective prompt

Status: ⬜ ready

Two Viggens on a low-level strike flew out over the sea at wave-top height, 260 nm, where the aircraft's doctrine would use the valleys and the hills.
The prompt (section 4.5) has the assistant measure, with `terrain_elevation` and the batteries as `observers`, what each battery sees of **the chosen route**; nothing in phase 1 asks it to design the route after how the aircraft is flown, or to compare candidates.
The basemap rule is "in a desert, `basemap: topo`".
Trakdah's assistant, afterwards: "The domain knowledge (Viggen doctrine, using the hills) is what I'm expected to bring. The tool gave me the means to check it, and I didn't use them."

To do, in the objective prompt (EN and FR):

1. Phase 1, a scenario with a low-level or terrain-dependent profile: propose a route that matches how that aircraft and era fly the sortie (terrain masking, a pop-up from the sea, a valley run), say which and why; measure the exposure of **two** candidate routes against the known batteries with `terrain_elevation` (`route` + `observers`, on an assumed altitude profile said as such) and give the comparison in the scenario.
2. `basemap: topo` by default for any low-level or terrain-dependent mission, not only in a desert.
3. The user is asked how they want the sortie flown when the scenario is chosen, and their answer overrides the assistant's doctrine.

Done when: the prompt carries the three rules in both languages; the prompt tests (the ones that check what the served prompt says) cover them.
