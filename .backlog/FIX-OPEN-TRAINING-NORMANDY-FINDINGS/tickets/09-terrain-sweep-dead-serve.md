# 09 — `terrain-sweep` waits forever on a `dcs-serve` that died, and re-keys a mission the maker already opened

Status: ✅ done — first and third bullets; the second rests on something that is not in the code
Type: fix
Files: `veaf_tools/commands/clear_ground.py` (l. 362 and the wait loop), `veaf_libs/locales/fr.json` (`cmd.clear_ground_sweep.serve_running`), `veaf_libs/dcs_serve_launcher.py`, tests

## What happens

On 2026-10-13, `veaf-tools dcs terrain-sweep Normandy` found a `dcs-serve` on :8080 (« dcs-serve tourne déjà sur http://127.0.0.1:8080 : il est utilisé tel quel »), wrote the survey mission and waited for the bridge. That `dcs-serve` — started by another session — exited a few minutes later. The sweep process stayed alive, silent, for about twenty minutes while DCS's bridge logged « no connection for 30s — retrying » against a closed port. Nothing in the sweep's output said the server was gone.

When the maker (and I) relaunched the sweep with `--dcs-serve <exe> --config <yaml>`, it started a fresh `dcs-serve`, **generated a new API key** and **rewrote `veaf-survey-Normandy.miz`** with it: the copy the maker already had open in DCS carried the old key and could not connect; the maker had to reload the mission. The message did say « sa clé d'accès a été générée », not that an open mission is now stale.

## What ships

- The wait loop checks the server every few seconds; if it stops answering, say so once (« dcs-serve ne répond plus sur … ») and either restart it (when the command launched it) or exit with the command to relaunch.
- Reuse the key already in the configuration file when the file exists, so a rewritten survey mission keeps the key the open one has; when the key must change, write « rechargez la mission d'arpentage dans DCS » in the instructions.
- A timeout on the wait (`--wait` exists for `clear-ground-check`; `terrain-sweep` has none) with a message at half time.

## Done when

Killing `dcs-serve` during a sweep gives a one-line message within 15 s; relaunching does not invalidate an open survey mission.

## Done

The wait loop asks `is_serving` when a call fails: a `dcs-serve` that no longer answers stops the sweep at once with `cmd.clear_ground_sweep.serve_gone` (the wait polls every 3 s), and the wait says once, at half time, that the survey mission has not answered. It serves every command that opens a survey session, not `terrain-sweep` alone.

Corrections: `terrain-sweep` **has** a `--wait` (900 s by default) and a deadline, which is what ended the twenty minutes; and the survey mission does not carry the API key — `build_survey_mission` takes none, the key is the client's credential for `dcs-serve`, and `ensure_config` already keeps the key of an existing `dcs-serve.yaml` in the working folder. A relaunch that started a *new* server in another folder got a new key, but nothing was written into the open mission. So there is no « rewritten mission with a stale key » to fix, and no « reload the survey mission » to say. Not done either: restarting the server when the command launched it — it exits with the command to relaunch.
