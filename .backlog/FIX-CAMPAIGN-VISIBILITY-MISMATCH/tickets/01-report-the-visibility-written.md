# 01 — Report the visibility written

Status: ✅ done

- `set_conditions` keeps what `set_weather` returns and reports `visibility.distance` from it, so the report, the MCP action and anything built on them say what the mission flies.
- Test in `test_campaign_mission_conditions.py`: the announced visibility, cloud base, temperature and ground wind equal the mission table's, over enough missions to draw a 10 km sky at least once.
- Document "9 000 m or more is written as 80 km" where a visibility in metres is accepted.
