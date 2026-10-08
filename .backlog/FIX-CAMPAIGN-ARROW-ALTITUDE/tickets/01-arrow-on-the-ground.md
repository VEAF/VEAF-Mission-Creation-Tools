# 01 — The axis arrow on the terrain

Status: ✅ done

- `veafCampaign.sendConvoy`: both points of `arrowToAll` at `land.getHeight`, the order kept (source, target — right when zoomed in, per David).
- `test_veafCampaign.lua`: `test_the_axis_arrow_lies_on_the_ground_from_source_to_target`, failing at `y = 0` before the fix.
- `known-limitations.yaml`: the observation, `kind: dcs`.
