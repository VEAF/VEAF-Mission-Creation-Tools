# 01 — Rendre le hook configurable (BufferingSocket / autorestart / pilotsDir)

Status: 🔄 in-progress

## Change (`src/scripts/Hooks/VEAF-Server-hook.lua`)

- New flags OFF by default: `enableBufferingSocket`, `enableAutoRestart`; new `pilotsDir` (nil).
- BufferingSocket: remove the top-level `require` (+ `package.path`/`cpath`, `config` require);
  load it defensively (`pcall`) in a new `setupBufferingSocket()` called from `onSimulationStart`,
  only when `enableBufferingSocket`; auto-disable + log if the module cannot be loaded.
- Autorestart: gate `stopMissionIfNeeded` (on `onPlayerDisconnect` + `onSimulationFrame`) and the
  `restart`/`restartnow`/`halt` chat commands on `enableAutoRestart`. Keep `haltnow`/`pause`/`send`/
  `code`/generic branch unconditional.
- Pilots path: `loadPilots` uses `(veafServerHook.pilotsDir or VEAF_SERVER_DIR)`.
- Bump `Version` → 2.7.0; header updated (opt-in features, specific-hook, `veaf-pilots.txt`).

## Validation

- `luac -p src/scripts/Hooks/VEAF-Server-hook.lua` → OK.
- Smoke test (mocks, hors harnais) : chargement sans BufferingSocket, flags OFF, `setupBufferingSocket`
  no-op quand OFF / dégradation propre si module absent. All green.
- Non-régression : `poetry run test-lua` (le hook n'est pas dans le harnais ; confirme l'absence
  d'effet de bord).

## Done when

- Flags en place, comportements gated, syntaxe + smoke test verts.
- Le hook charge sans BufferingSocket présent (bug du repo public corrigé).
