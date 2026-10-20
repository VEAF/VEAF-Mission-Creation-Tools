# 02 — `f10_view_by_role`: the F10 map per role

Status: ✅ done

## Done when

- `mission.forced_options.f10_view_by_role` writes `optionsView = "optview_extended"` and `optionsViewExtended` for the six roles (pilot, jtac, tactical_commander, observer, spectator, airboss).
- A role is a view (`fog_of_war`), or `{view: …, hide: [enemies_weapons, …]}`; a role not named gets the editor's default (everything shown).
- `f10_view` and `f10_view_by_role` together are refused.
- Tests pin the layer bits against the editor's dialog layout (bit = row × 3 + column).
