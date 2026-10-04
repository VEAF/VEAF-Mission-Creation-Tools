# Ready lots

[Back to the backlog](README.md)

Lots written up and ready to take.

### [ENRICH-DEFAULT-PRESETS](ENRICH-DEFAULT-PRESETS/PRD.md) · ⬜

Broaden the shipped default radio presets, after phase 1 of the radio preset projection.

### [FEAT-AIRFIELD-FREQS-IN-ATIS](FEAT-AIRFIELD-FREQS-IN-ATIS/PRD.md) · ⬜

The ATIS and the welcome brief give the airfield's own tower and TACAN frequencies (and the mission's `bases` channel when it differs), from a reference table loaded with the scripts. Three tickets.

### [FEAT-AIRWAVES-QRA-MERGE](FEAT-AIRWAVES-QRA-MERGE/PRD.md) · ⬜

Rebuild QRA on AirWaves instead of beside it (~120 KB of neighbouring Lua), closing six AirWaves issues in one design. A design lot before any refactor.

### [FEAT-AWACS-ESCORT-COMMANDS](FEAT-AWACS-ESCORT-COMMANDS/PRD.md) · ⬜

`-awacs` and `-escortme` (#188, #189). Unblocked: the escort mechanism they rely on was fixed (#107) or never broken (#101).

### [FEAT-CAP-WATCHDOG](FEAT-CAP-WATCHDOG/PRD.md) · ⬜

A handle to remove a spawned CAP (#178), and a watchdog that spreads targets, weighs aspect and has a priority cut-off (#187). Four tickets; the 2026-10-03 task fix it builds on is merged.

### [FEAT-DYNAMIC-CAMPAIGN](FEAT-DYNAMIC-CAMPAIGN/PRD.md) · ⬜

A Foothold-like persistent campaign built on VMCT alone, declared in a `campaign.yaml` sidecar from which the build generates zones, slots and data.

### [FEAT-MISSION-RECIPES](FEAT-MISSION-RECIPES/PRD.md) · ⬜

Scripted mission generation with no AI in the loop: a recipe file of MCP actions run by `veaf-tools`; the demo mission regenerated in CI would become the end-to-end test. Start with one recipe.

### [FEAT-PORTABLE-PREFABS](FEAT-PORTABLE-PREFABS/PRD.md) · ⬜

A design lot: bundle mission content (groups, statics, zones, media, mod dependencies) and re-instantiate it elsewhere. Rejecting the idea is an acceptable outcome.

### [FEAT-SPOTTER-DEMO-MISSION](FEAT-SPOTTER-DEMO-MISSION/PRD.md) · ⬜

A mission that proves a spotter report reaches a battery that never saw the aircraft. Tickets 01–04 done (durable history, rig, smoke-test suite); the demonstration layer is left.

### [FEAT-SUPPORT-ASK-ESCALATE](FEAT-SUPPORT-ASK-ESCALATE/PRD.md) · ⬜

Turn an answered `/ask` thread into a pre-filled `/bug` or `/suggest`, filed only on explicit confirmation.

### [FIX-CHATBOT-DAILY-QUOTA](FIX-CHATBOT-DAILY-QUOTA/PRD.md) · ⬜

The website chatbot runs on a free tier of 20 requests a day, and hit it on 2026-09-22. The limit is now visible (tickets 01–03 done); what remains is falling back to other models, each with its own free allowance.

### [INVESTIGATE-SKYNET-AWACS-BLIND](INVESTIGATE-SKYNET-AWACS-BLIND/PRD.md) · ⬜

Three red A-50s reported no contact in 286 cycles while ground radars saw up to 14 aircraft. Three hypotheses to test, cheapest first.
