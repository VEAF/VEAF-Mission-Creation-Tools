# 02 — `edit_mission_file` matches across CRLF

Status: ⬜ ready

`read_mission_file` returns a CRLF file's lines with `\r\n`; an AI copies the passage back with `\n` (or its client normalises it), and a multi-line `search` is "passage not found".

`edit_mission_file` compares `search` and the file with line ends normalised, and writes `replace` with the file's own line end.
`read_mission_file` returns `\n` line ends, whatever the file uses, and says so in its description.

Also find why the scaffold written by the frozen exe is CRLF (the `published` defaults, checked out on the Windows CI runner?) and decide whether it should be LF like the repository.

Done when: tests edit a CRLF and an LF file with a multi-line passage and keep each file's line ends; the scaffold question is answered in the PR.
