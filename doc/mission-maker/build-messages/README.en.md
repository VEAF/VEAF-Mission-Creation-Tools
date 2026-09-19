# Build messages

## What this is {#what-it-is}

You built a mission, the console printed something, and you want to know what to do about it. This
section covers the messages that cost the most to interpret: what they mean **in Mission Editor
terms**, how to find the situation that triggers them, the ways out — and above all what they do
**not** mean, because that is where the time goes.

## First: did the build fail? {#did-the-build-fail}

Almost always **no**. Three kinds of output, which do not read the same way:

| What you see | What happened | The `.miz` |
|---|---|---|
| A lone yellow line during the build | A warning in passing | written |
| A framed block at the end, "… mission.yaml reference(s) to a Mission-Editor object are missing" | Missing references, deliberately grouped at the end | written |
| "Cannot build: …" | The build stops | **not** written |

In other words, a yellow message does not stop you from flying the mission. It tells you that part
of what you configured will do nothing in the air — which you normally find out an hour later, in
DCS, with no message at all.

> **A message can go by without your seeing it.** Information lines are shown on a status line that
> keeps rewriting itself: in a terminal they scroll past too fast. Warnings and errors, on the
> other hand, stay on screen. To read everything back, add `--verbose` or redirect the output to a
> file.

The same checks run without rebuilding:

```powershell
.\veaf-tools.exe validate
```

> **The `.\` is required.** The default Windows terminal is PowerShell, which does not search the
> current folder — deliberately. `cmd.exe` accepts both forms, so `.\` works everywhere. See
> [PowerShell or command prompt?](../GUIDE.en.md#powershell-vs-cmd).

`validate` prints the **same** checks, with an exit code: non-zero on an error, and with `--strict`
non-zero on a mere warning too. That is the command for a script; the build prefers to hand you the
`.miz` so you can go and fix things in the editor.

## Find your message {#find-your-message}

| The message is about… | Page |
|---|---|
| countries, sides, `coalitions.red`, the coalition assignment screen | [Coalitions and countries](coalitions.en.md) |
| a missing group, trigger zone, unit or airfield | [Missing references](missing-references.en.md) |
| a `.lua` file in `src/scripts/` | [The Lua files in your folder](lua-files.en.md) |
| waypoints, a route the editor refuses, an oddly numbered table | [Routes and tables](routes-and-tables.en.md) |
| CTLD, TUM, a module turned on or off, a sound file | [Modules and community scripts](modules.en.md) |

## If your message is not here {#not-listed}

These pages do not cover everything, and there is no point pretending otherwise: the tools can print
about **a hundred** different messages, many of which are plain progress reports ("Injecting VEAF
scripts…") or say everything they have to say in their own sentence.

What these pages cover are the messages that actually cost somebody something: the ones that block,
the ones that leave a feature silent in the air, and the ones that have already sent a mission maker
down the wrong path.

For anything else: [Getting help](../../SUPPORT.en.md), and in particular the Discord assistant's
`/ask` command, which searches these very pages.

## Going further {#more}

- [The build](../concepts/build.en.md) — what the command does, step by step
- [CLI Reference — `validate`](../../CLI_REFERENCE.en.md#validate)
- [Read the DCS logs](../LOGS.en.md) — for what happens **after** the build, in game
