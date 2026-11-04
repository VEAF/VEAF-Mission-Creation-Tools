# 02 — `help_menus` negated

Status: ✅ done

security-audits#146. `help_menus` joins `_NEGATED_INIT_KEYS`, its default becomes `false` so a mission that does not mention it still gets `veafRadio.initialize(true)` (help entries hidden, as since v5). `veafRadio.md`, `MISSION_YAML_REFERENCE.md` (both languages) and the shipped `mission.yaml` say so.

Done when: `help_menus: true` generates `initialize(false)`, `false` and absent generate `initialize(true)`.
