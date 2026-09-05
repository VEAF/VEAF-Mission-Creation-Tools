# DCS is misbehaving — read its log

A mission will not load. The game freezes after ten minutes. A module refuses to start, a VEAF menu
does not appear, a command does nothing. DCS wrote it all down somewhere — but the file is 10 MB and
nobody can read it.

`veaf-logs` exists for that. It opens the file, shows only what matters, and **explains** what it
recognises.

!!! info "What it does, and what it does not"
    It **explains**. It repairs nothing, changes neither your install nor your missions, and it does
    not know everything: outside its catalogue it says *pattern not catalogued* rather than inventing
    a cause. A wrong but plausible cause would cost you your evening.

## In three minutes {#quickstart}

You have never typed a command line: that is fine, there is only one.

1. **Download** the VEAF tools archive from the
   [releases page](https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases) and unpack it
   wherever you like.
2. **Open that folder** in Windows Explorer, type `powershell` in the address bar and press Enter: a
   blue window opens, already sitting in that folder.
3. **Type**:

    ```powershell
    .\veaf-logs.exe
    ```

    A window opens on your current `dcs.log`. You can also drag a log file onto `veaf-logs.exe`
    directly, without the command line at all.

!!! note "Why the `.\` in front of the name"
    PowerShell — the default Windows command prompt — does **not** look for programs in the current
    folder. Without the `.\` it answers that the command does not exist, while the file is plainly
    right there. It is the single most confusing error a newcomer can meet. In `cmd.exe` the `.\` is
    optional but accepted, so it is the form to write everywhere.

## Keep only what matters {#filter}

In the drop-down at the top, pick the **Diagnostic** profile. It keeps only errors and warnings, with
a few lines around them for context. On an ordinary session log that commonly turns 400 severe lines
into about thirty.

If you are after something specific — your aircraft's name, a script's name, a word you saw in an
error message — type it in the search field.

## Ask for an explanation {#explain}

Menu **Analyse → Expliquer ce qui est affiché**, or `Ctrl+E`.

The window that opens answers in two layers, and the distinction is deliberate:

- **Verified catalogue** — explanations someone wrote and reviewed, reproduced as they stand. They
  cost nothing, need no Internet, and are reliable.
- **Model commentary** — optional, behind the **Analyser en ligne** button. It chains the clues: what
  happened first, what is only a consequence, which line to act on. It is **generated** text, to be
  checked.

With no Internet the first half stands on its own and no error is shown. That is a normal mode of
operation, not a failure.

!!! warning "What leaves your machine"
    Nothing, until you press **Analyser en ligne**. At that point what leaves is the excerpt you have
    in front of you, bounded and **redacted**: your Windows account name is replaced by `<user>`, IP
    addresses by `<ip>`, tokens by `<redacted>`. The names of your missions, aircraft and payloads
    are kept — they are what says *what* it crashed on.

## Prepare a report {#report}

The **Préparer un rapport** button, in the same window, puts a block on the clipboard holding, all at
once: a description of your machine and your install, the log excerpt, and what the analysis
concluded — including what it could not explain.

Paste it on the [VEAF Discord](https://www.veaf.org/discord), `#support` channel. Nothing is sent on
its own: you decide where to paste it, and the block is text, so you can read it first.

It is sized to fit one Discord message. When it does not all fit, it says so and names what was
removed, rather than being cut in silence in the middle of a line.

## Next {#next}

- [Getting help](../SUPPORT.en.md) — where to report, and what to provide
- [`veaf-logs` in detail](../mission-maker/LOGS.en.md) — filters, search, profiles, large logs
- [Pilot guide](GUIDE.en.md) — everything that happens in game
