# 01 — One briefing page per training version

Status: ✅ done

## Done when

- A mission with a `training:` block gets four more pages at the end of `briefing.pptx` and `briefing.pdf`, numbered like the others; a mission without one gets the same deck as before (test).
- Each page has a table — taken out, kept, drawn at every launch — and the file to load, `<mission>_TRAINING_<ROLE>.miz`.
- The rows come from `plan_variant`: a test checks a CAP page lists the A2G zones as taken out with their air defences kept, and a SEAD page lists no draw of armour.
- A `training:` block the build would refuse is a warning of the briefing, not a crash.
- FR/EN wording in the locales; the catalogue and the briefing doc mention the pages.
