# 12 — Poster, calendar banner, Discord post

Status: ✅ done

A new action builds, from the built mission and the briefing's maps, a 16:9 poster and a calendar banner at 5.55:1 (the VEAF calendar crops it at the centre), and writes a Discord post under 2 000 characters; the calendar and briefing links and the local time are parameters, never invented.

Done when: covered by a test, and the documentation says it.

## Result

`mission_briefing/mission_promotion.py`, action `build_mission_promotion`: `docs/poster.jpg` 1920 x 1080, `docs/calendar-banner.jpg` 2400 x 432, `docs/discord-post.md` refused over 2 000 characters. Tests: `test_mission_promotion.py`.
