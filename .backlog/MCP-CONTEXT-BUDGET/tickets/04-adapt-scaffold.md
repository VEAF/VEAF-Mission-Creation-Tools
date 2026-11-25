# 04 — `adapt_scaffold`: steps 1 to 5 of the guide in one action

Status: 🔄 in-progress

After `scaffold_mission` the guide asks the model to rewrite `src/presets.yaml` (48 777 bytes), `src/versions.yaml`, `src/waypoints.yaml`, `src/dynamic-slot-templates.yaml` and `mission.yaml`; reading them was 68 759 characters.

A separate action, beside `scaffold_mission` (the scaffold downloads for minutes; a refused adaptation must not repeat it, and a scaffold made by hand can be adapted too). It takes the mission's name, era, date and time, position, the airfields, the waypoints, the coalitions with dynamic slots and SKYNET, writes the five files and the blank mission's date, and answers one line per file. The guide and the mission prompts point at it.
