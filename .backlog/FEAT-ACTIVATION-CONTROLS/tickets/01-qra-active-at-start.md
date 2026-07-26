# 01 — QRA `active_at_start`

Status: ✅ done
Type: feat

## Behaviour

New optional key on a `modules.QRA.definitions[]` entry:

```yaml
- name: QRA_SYRIA_SOUTH
  active_at_start: false   # default true — the QRA waits for qra.start
```

- `true` / absent → unchanged (`:start()` emitted, current behaviour for every mission).
- `false` → the builder chain stops before `:start()`. The QRA is still registered (via
  `:setName()`), so a `qra.start` radio command or a scripted call arms it later.

## Tasks

- [x] Generator: skip the `:start()` line when `active_at_start` is `false`.
- [x] Tests: emitted by default / omitted when false / the rest of the chain unchanged;
      and the QRA is still named (so `qra.start` can find it).
- [x] Docs: `doc/mission-maker/scripts/veafQraManager.{md,en.md}` key table + example.
- [x] Default `src/defaults/mission-folder/mission.yaml`: document the key in the QRA block.
