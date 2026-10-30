# 02 — The Opposition menu by default

Status: ✅ done

The Opposition radio menu exists only when `mission.yaml` has a root `opposition:` block, and only `campaign next` wrote one. An objective mission and the shipped mission folder now carry `opposition: { level: 0 }` (behaviour at start unchanged: level 0 sizes nothing), and every QRA `create_qra` writes gets `scale_with_opposition: true`, so the Mission Maker can raise the opposition when more players show up.

Done when: the default `mission.yaml` has the block, `create_qra` writes the key (unless the caller set it) and adds the block when missing, the objective prompt says so, tests cover both.
