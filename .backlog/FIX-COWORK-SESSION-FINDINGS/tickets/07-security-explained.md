# 07 — Security explained, and a hash command

Status: ✅ done

The assistant asked "Security for the server build?" with "Security on, no hashes (Recommended)", "I'll provide password hashes (JTF / Mission-Master)" and "Security off", and nothing else.
What the user needed to know (`doc/mission-maker/scripts/veafSecurity.md`):

- what is locked: the sensitive F10 and marker commands (spawn, teleport, destroy);
- who passes without a password: on the VEAF servers, pilots listed in the server's `veaf-pilots.txt`; **anywhere else, nobody**;
- the password shipped by default is public, so "on, no hashes" protects nothing outside VEAF;
- how to get a SHA-1 hash: no command does it, and a mission maker cannot.

To do:

1. The objective prompt (EN and FR), its question and options, and the matching lines of the authoring guide and the open-training prompt: say the above in plain words, and make "off" the recommended answer for a mission not played on the VEAF servers. Never a clear-text password, still.
2. `.\veaf-tools.exe security hash`: asks for the password with the input hidden, asks it twice, prints the SHA-1 hash. Run by the user in PowerShell, never an MCP action: the password must not go through the conversation. The prompt gives the command and asks for the hash.
3. The `mission.yaml` comment `password_hashes: # SHA-1 hashes to restrict JTF/admin access`: read in `lua_config_generator` which tier those hashes open (ADMIN, SENIOR_PILOT, KNOWN_PILOT), and write that tier's name, in `src/defaults/mission-folder/mission.yaml` and the generator together (defaults lockstep).

Done when: the command exists with its tests and its `CLI_REFERENCE` entry (FR and EN); the prompts and the guide carry the explanation; the comment names the right tier.

## Result

The command is `veaf-tools mission password-hash` (flat alias `password-hash`), filed with the mission commands rather than in a group of its own; it is in the wizard too.
The objective and open-training prompts (EN and FR) explain what security locks, who passes, that the shipped password is public, and give the command; "off" is recommended for a mission played outside the VEAF servers.
Read in `lua_config_generator`: `password_hashes` opens SENIOR_PILOT and KNOWN_PILOT (L1 and L9); the comments of the shipped `mission.yaml` and of the generator say so.
Tests: `test_password_hash.py`, `test_the_objective_prompt_plans_the_route_and_asks_the_level` (the command in the served prompt).
