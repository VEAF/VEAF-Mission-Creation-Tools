# DOC-DEMO-VIDEO — the demo video on the documentation

Status: ✅ done

Origin: David's demo video, published on the VEAF YouTube channel on 2026-10-22 (https://www.youtube.com/watch?v=X3tJr130jSU): a free AI (OpenCode, DeepSeek V4.1 Flash) installs the VEAF tools on an empty Windows PC, then builds an objective mission on GermanyCW with its briefing — the five steps of the "Create with an AI" page, in six minutes, English with French subtitles.

## Decision (David, 2026-10-22)

- Embedded once, on `AI_ASSISTANT_INSTALL` (both languages), right under the five-step box it illustrates: section `#demo-video`.
- Linked, not embedded, from the "Create with an AI" card of the home page: one player to update the day the video is remade.
- The player forces the subtitles in the page's language (`cc_load_policy=1`, `cc_lang_pref=fr|en`, `hl=fr` on the French page), from `youtube-nocookie.com`.

Checked in a local build: the section sits under the box, the home link lands on the heading with the player under it (735×551 at a 1280-wide window).
