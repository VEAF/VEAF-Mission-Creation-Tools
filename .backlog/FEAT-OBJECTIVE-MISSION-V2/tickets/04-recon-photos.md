# 04 — Recon photos per objective

Status: ✅ done

A new optional `recon_folder` parameter: JPEG photos, each with a JSON sidecar (zone, title, heading, pitch, coordinates). One or two per slide after the objective's zoom in the deck and the PDF, and in the kneeboard. The interface is documented; the `vmct-recon-ingame` lot produces the files.

Done when: covered by a test, and the documentation says it.

## Result

`mission_briefing/briefing_recon.py`; `recon_folder` (default `docs/recon/`); two photos per slide and per kneeboard page after the zoom, captioned; strays warned; the result's `recon`. Interface documented in `doc/developer/mission-editing-mcp.md` and sent to the in-game session. Tests: `TestTheReconPhotos`, `test_code_words_and_recon_photos_reach_the_briefing`.
