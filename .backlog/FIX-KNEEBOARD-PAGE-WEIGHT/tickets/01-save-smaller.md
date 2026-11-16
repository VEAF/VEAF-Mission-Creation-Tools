# 01 — Save the pages at 1024 px, quality 80

Status: ✅ done

The pages keep being drawn at `KNEEBOARD_PAGE_SIZE` (1536 × 2304), so the layout, the fonts and the map fitting do not change; `briefing_kneeboard._jpeg` brings each page down to `KNEEBOARD_SAVED_PAGE` (1024 × 1536, Lanczos) and saves it at `KNEEBOARD_JPEG_QUALITY` (80).

Done when the pages written into the mission are 1024 × 1536 JPEG, and the tests that read a page's size say so.
