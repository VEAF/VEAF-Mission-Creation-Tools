# 05 — Remove the plugin and the Gemini extension

Status: ⬜ ready

Delete `plugin/` and `.claude-plugin/marketplace.json`, `test_plugin_version.py`, and every reference: CI paths, release command, CLAUDE.md §9 item 5, locales, the build's bundle list.

Done: `git grep` finds no live reference to the plugin.
