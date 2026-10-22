# DOC-AI-MODEL-CHOICE — the install page says how to choose the model

Status: ✅ done

Origin: David's demo tests on OpenCode, 2026-10-22.
With the default model, **Big Pickle**, "install the VEAF AI tools: <page>" opened the page in OpenCode's built-in browser and worked for seven minutes without result, until David stopped it.
With **DeepSeek v4.1 Flash**, free too, the install succeeded in two to three minutes, and a whole mission followed.
The page recommended OpenCode, in its five-step box and its table, without a word on the model: a newcomer keeps the default.

## What the difference is

Not agentic against non-agentic: in OpenCode every model gets the same tools (commands, files, the browser).
The difference is how well the model uses them, which no model description states; OpenCode's own Zen page says "only a few work well as coding agents".
OpenCode's Zen page also gives each free model's data policy: Big Pickle is a stealth model whose collected data "may be used to improve the model" during its free period; DeepSeek v4.1 Flash's provider keeps none and trains on none.

## Decision (David, 2026-10-22)

Explain how to choose, and name the model tested only as a dated example:

1. the install is the test — no updater run after five minutes, change the model;
2. prefer a model that keeps no data;
3. a model that managed the install usually manages the mission;
4. "in our tests of October 2026": DeepSeek v4.1 Flash succeeded, Big Pickle (the default) did not, one test each.

New section `#which-model` on `AI_ASSISTANT_INSTALL` (both languages), linked from step 2 of the box and from the OpenCode row of the table.
