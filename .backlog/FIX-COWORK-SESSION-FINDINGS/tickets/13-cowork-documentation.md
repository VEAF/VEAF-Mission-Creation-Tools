# 13 — Cowork in the AI assistant documentation

Status: ⬜ ready

`doc/mission-maker/AI_ASSISTANT_INSTALL.md` / `.en.md` never mention Claude Cowork, which Trakdah used.
In Cowork the assistant runs in the cloud and reaches the PC through the Claude desktop app: the VEAF server runs on the PC, under the user's Windows account; the assistant sees only the folders connected with "Add folder", and copies files to and from its cloud sandbox to read them.

What the session showed (see [trakdah-session-review.md](../trakdah-session-review.md), "Advice for using Cowork"):

1. connect the mission folder before asking for a mission;
2. give the assistant the full path where to create it — it guessed another Windows profile and got "Access denied";
3. a folder must be both connected (for the assistant) and writable by the user's account (for the VEAF tools);
4. say how the sortie should be flown;
5. it cannot launch DCS: the list it gives at the end is the list to check in game;
6. no `/export`: asking it to export the session as JSON works, and that is what to send when reporting a problem.

To do: a row in "Which AI to choose?" (free or not, to be checked on Anthropic's pricing page and dated, not guessed) and a `### Claude Cowork {#cowork}` section with the advice above, in both languages; whether `ai-setup` declares the server for Cowork, or the desktop app's declaration covers it, read from the code and said.
Advice 4 and 5 that hold for every assistant go in "Using the assistant", not under Cowork.

Done when: both pages carry it, `poetry run docs-check` passes, and the support bot's page index is refreshed if a title changed.
