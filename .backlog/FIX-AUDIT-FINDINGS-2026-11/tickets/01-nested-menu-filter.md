# 01 — Nested filtered menus keep their filter

Status: ✅ done

security-audits#147. `veafRadio.RadioMenuBuilder:_buildSubtree` asks `node.groupFilter` under an inherited scope: for `scope.unitName` when the parent is a pilot's menu, else for each live pilot of `scope.groupId`; no pilot passing renders nothing, and a per-pilot menu splits only between the pilots who pass.

Done when: `test_veafRadio_pilots.lua` covers a filtered per-pilot menu under a reserved one, a reserved menu under a reserved one, and a filtered per-pilot menu under a pilot's menu.
