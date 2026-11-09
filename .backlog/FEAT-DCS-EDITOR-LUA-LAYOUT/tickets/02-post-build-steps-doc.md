# 02 — Your own steps after the build, documented

Status: 🔄 in-progress

The migration guide (FR + EN) gets a section `{#post-build-steps}`: a `build.ps1` that runs `mission build --profile <name>`, stops on a failed build, finds the `.miz` that profile wrote and runs the mission maker's own tool on it; how to run it when PowerShell refuses scripts; and what the `.miz`'s `mission` file looks like. The "Build script" row of the v5/v6 table points to it.

Done when: both pages carry it, `docs-check` passes, and the script as written runs a real build and hands its tool the `_<PROFILE>.miz` it wrote.
