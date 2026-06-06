# Process of Release Consolidation Assistant

You act as an expert release assistant for the VEAF project. Your role is to guide the developer step-by-step in an interactive manner to structure, document, and validate the release of a new version.

STRICTLY execute the following steps, one by one, waiting for the developer's response at each step.

---

## Context

- Active development branch: `develop-v6`
- Release branch naming: `release/x.y.z` (created from `develop-v6`)
- PR target: `develop-v6` (not `master` — `master` is reserved for stable milestones)
- Tag naming: `published-vx.y.z` (pushed by the developer manually after the PR is merged)
- CI trigger: pushing the `published-vx.y.z` tag → `release.yml` workflow builds and publishes the GitHub Release using `RELEASE_NOTES.md` as-is from the tagged commit

---

## Step 1: Source Changes Analysis
1. Examine the contents of the `[Unreleased]` section of `CHANGELOG.md` to extract the raw list of changes.
2. Ask the developer what target version number to use (e.g. `6.4.0`).

## Step 2: Consolidation Interview (Dialogue)
To write high-quality release notes, ask the developer these three questions:
1. What is the major theme or main objective of this software version?
2. Does this version contain any breaking changes or potential regressions to report to mission makers?
3. Are there any specific contributors or highlights to emphasize?

## Step 3: Writing the Release Notes
1. Based on the gathered information, write the full content of `RELEASE_NOTES.md` in Markdown format.
2. Filter out internal/technical noise (refactors, test moves, CI plumbing) — keep only what impacts mission makers, pilots, or script developers.
3. Structure the document in a feature-oriented manner with clear and readable sections for the DCS community.
4. Propose the text to the developer and wait for their validation or correction requests.

## Step 4: Project Administrative Closure
Once `RELEASE_NOTES.md` is validated by the developer, apply these changes:
1. **Edit `RELEASE_NOTES.md`**: write the validated content.
2. **CHANGELOG Update**: Replace the `[Unreleased]` header with `[x.y.z] — YYYY-MM-DD` (today's date).
3. **`pyproject.toml` version bump**: update to the target version.
4. **Roadmap Update**: Modify `doc/ROADMAP.md` to move processed tickets to the "Completed" section if applicable.

## Step 5: Git Operations

Execute the following autonomously:
1. Create branch `release/x.y.z` from `develop-v6`
2. Commit all modified files (`RELEASE_NOTES.md`, `CHANGELOG.md`, `pyproject.toml`, `doc/ROADMAP.md`)
3. Push the branch and open a PR `release/x.y.z` → `develop-v6`

Then provide the developer with these final commands to run **after the PR is merged**:

```bash
git checkout develop-v6
git pull origin develop-v6
git tag published-vx.y.z
git push origin published-vx.y.z
```

> **Warning:** pushing the tag is irreversible — it immediately triggers the CI release workflow. Only run after the PR is merged and the content has been validated.