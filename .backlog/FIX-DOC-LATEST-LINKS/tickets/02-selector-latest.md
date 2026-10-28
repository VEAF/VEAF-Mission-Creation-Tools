# 02 — Version selector opens /latest/

Status: 🔄 in-progress

`extra.version.alias: true` shows "latest" next to the newest release in the selector; `doc/assets/version-latest.js` catches the click on that entry (capture phase, before Material's handler) and opens the same page under `/latest/`, or `/latest/` itself when the page does not exist there.

Checked on a local mike-like layout: 6.33.0 → `/latest/pilot/GUIDE/#top`; dev → `/latest/pilot/GUIDE/#top`; a page missing from latest → `/latest/`; latest → dev still handled by Material (`/dev/pilot/GUIDE/#top`).
