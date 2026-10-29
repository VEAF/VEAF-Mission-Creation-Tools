# 02 — Recon over the bridge

Status: ✅ done

- `recon-prepare` injects `dcs-bridge.lua` into the shooting copy (`--bridge-lua` for a local file, downloaded otherwise);
- `recon-plan` and `recon-shoot` read the units in the mission scripting state and move the camera through `net.dostring_in("export", …)`;
- `--url` / `--fiddle-token` give way to `--serve-url`, `--dcs-serve`, `--api-key`, `--config`.

Done when: the commands are unit-tested against a fake bridge.
