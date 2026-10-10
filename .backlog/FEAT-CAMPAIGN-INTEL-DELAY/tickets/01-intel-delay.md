# 01 — The intelligence delay, in flight and in `campaign.yaml`

Status: ✅ done

- `veafCampaign.lua`: `INTEL_SECONDS`, `reportConvoy` from `sendConvoy` and from every beat; the axis line per coalition; `removeAxis` removes both.
- `campaign_manager`: `CampaignRules.intel_seconds`, validated (`>= 0`), written into the mission's campaign data.
- Tests: Lua (own side at once, the other after the delay and once, 0 for at once, a convoy destroyed before is never reported), Python (default, set, negative refused, passed to the mission).
- `CAMPAIGN.md` / `.en.md`.
