"""GitHub release publishing logic."""

import os
import subprocess
from pathlib import Path

from veaf_libs.logger import logger  # type: ignore[import-not-found]


def version_is_prerelease(version: str | None) -> bool:
    """Return whether *version* is a semver pre-release (a ``-`` suffix, e.g. ``6.9.21-rc1``).

    The single source of truth for pre-release detection on the Python side (``_is_prerelease``
    and the CLI publish guard). VEAF versions are strict semver ``X.Y.Z``, so a ``-`` never
    appears in a stable version — it always marks a pre-release. The ``release.yml`` workflow
    applies the same rule in bash (``*-*``); keep the two in sync if this ever changes.
    """
    return "-" in (version or "")


class GitHubPublisher:
    """Handles creating git tags and GitHub releases."""

    def __init__(
        self,
        owner: str,
        repo: str,
        token: str | None,
        version: str,
        script_root: Path,
        dist_dir: Path,
        output_path: Path,
        prerelease: bool = False,
        verbose: bool = False,
        skip_git_tags: bool = False,
    ) -> None:
        self.owner = owner
        self.repo = repo
        self.token = token
        self.version = version
        self.script_root = script_root
        self.dist_dir = dist_dir
        self.output_path = output_path
        self.prerelease = prerelease
        self.verbose = verbose
        self.skip_git_tags = skip_git_tags

    @property
    def _is_prerelease(self) -> bool:
        # A pre-release is either explicitly flagged, or signalled by a semver pre-release
        # suffix in the version (e.g. 6.9.21-rc1) — see version_is_prerelease. Keying off the
        # version keeps the CLI and the release workflow from ever disagreeing on whether to
        # move the floating `published-latest` tag.
        return self.prerelease or version_is_prerelease(self.version)

    def publish(self, package_path: Path, package_hash: str, force: bool = False) -> None:
        """Publish release to GitHub using git tags and gh CLI."""
        if not self.token and self.skip_git_tags:
            logger.warning(
                "GitHub token not provided and skip_git_tags=True: nothing to publish. "
                "Set GITHUB_TOKEN or pass --token.",
                no_console=True,
            )
            return
        if not self.token:
            logger.warning(
                "GitHub token not provided. Use --token parameter or set GITHUB_TOKEN environment variable",
                no_console=True,
            )
            logger.info("Proceeding with git tags only (release assets must be uploaded manually)", no_console=True)

        # VMR-104: the order matters. The tags used to be pushed first, so an unusable `gh` — or a
        # release creation that failed — left `published-v<x>` on the remote with no release behind
        # it, and `published-latest` force-moved onto that same commit. Anything resolving the
        # floating tag then pointed at a release GitHub cannot serve. So: refuse before touching the
        # remote, and move the floating tag only once the release exists.
        if self.token and not self._gh_cli_available():
            logger.warning(
                "GitHub CLI (gh) not found, so no release can be created: nothing was pushed. "
                "Install it from https://cli.github.com/ or re-run with --skip-git-tags to push tags only."
            )
            return

        try:
            if not self.skip_git_tags:
                self._publish_with_git_tags(package_path)
            if self.token:
                self._publish_with_gh_cli(package_path, package_hash, force=force)
            # Only now is there a release for the floating tag to point at. Without a token there is
            # no release to wait for, so the tags-only path moves it as it always did.
            if not self.skip_git_tags:
                self._move_latest_tag()
        except subprocess.CalledProcessError as e:
            logger.error(f"GitHub publishing failed: {e}")

    def _gh_cli_available(self) -> bool:
        """Whether the `gh` CLI can be run at all.

        Returns:
            True when ``gh --version`` succeeds.
        """
        try:
            subprocess.run(["gh", "--version"], capture_output=True, check=True)
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False
        return True

    def _force_tag(self, tag_name: str) -> None:
        """Recreate *tag_name* locally and force-push it to origin.

        Args:
            tag_name: The tag to (re)create.
        """
        # Deleting first is how a re-publish of the same version is allowed; a tag that does not
        # exist yet makes this fail harmlessly, hence no `check`.
        subprocess.run(["git", "tag", "-d", tag_name], cwd=str(self.script_root), capture_output=True)
        subprocess.run(["git", "tag", tag_name], cwd=str(self.script_root), capture_output=True, check=True)
        subprocess.run(
            ["git", "push", "origin", "-f", tag_name],
            cwd=str(self.script_root),
            capture_output=True,
            check=True,
        )

    def _publish_with_git_tags(self, package_path: Path) -> None:
        """Create and push the versioned git tag.

        VMR-104: the floating ``published-latest`` tag is **not** moved here any more —
        :meth:`_move_latest_tag` does it once the release exists.
        """
        try:
            tag_name = f"published-v{self.version}"
            self._force_tag(tag_name)
            logger.debug(f"Git tag created and pushed: {tag_name}", no_console=True)
        except subprocess.CalledProcessError as e:
            logger.error(f"Git operation failed: {e}")

    def _move_latest_tag(self) -> None:
        """Move the floating ``published-latest`` tag onto this release, for a full release only."""
        latest_tag_name = "published-latest"
        if self._is_prerelease:
            logger.debug(f"Pre-release: skipping {latest_tag_name} tag update", no_console=True)
            return
        try:
            self._force_tag(latest_tag_name)
            logger.debug(f"Git tag moved: {latest_tag_name}", no_console=True)
        except subprocess.CalledProcessError as e:
            logger.error(f"Git operation failed: {e}")

    def _publish_with_gh_cli(  # sourcery skip: extract-duplicate-method
        self, package_path: Path, package_hash: str, force: bool = False
    ) -> None:
        """Publish release to GitHub using gh CLI."""
        try:
            # Check if gh CLI is available
            subprocess.run(
                ["gh", "--version"],
                capture_output=True,
                check=True,
            )
        except (subprocess.CalledProcessError, FileNotFoundError):
            logger.warning("GitHub CLI (gh) not found. Install from: https://cli.github.com/")
            return

        try:
            tag_name = f"published-v{self.version}"
            latest_tag_name = "published-latest"

            # Prepare environment with GitHub token
            env = os.environ.copy()
            if self.token:
                env["GH_TOKEN"] = self.token

            # Delete existing release if force is enabled
            if force:
                subprocess.run(
                    ["gh", "release", "delete", tag_name, "--yes"],
                    cwd=str(self.script_root),
                    env=env,
                    capture_output=True,
                    text=True,
                )
                # Ignore errors if release doesn't exist

            # Create release notes
            release_notes_path = self.script_root / "RELEASE_NOTES.md"
            notes_arg = []
            if release_notes_path.exists():
                notes_arg = ["--notes-file", str(release_notes_path)]

            # Create GitHub release for versioned tag
            release_type_flag = "--prerelease" if self._is_prerelease else "--latest"
            release_cmd = [
                "gh",
                "release",
                "create",
                tag_name,
                release_type_flag,
                "-t",
                f"VEAF Tools v{self.version}",
                *notes_arg,
            ]

            result = subprocess.run(
                release_cmd,
                cwd=str(self.script_root),
                env=env,
                capture_output=True,
                text=True,
            )
            if result.returncode != 0:
                logger.error(f"GitHub release creation failed: {result.stderr}")
                return

            # Upload release assets: both executables as direct downloads, then main zip.
            # veaf-tools.exe is also bundled inside published.zip, but is exposed as a
            # direct asset too so every platform's binary is downloadable in one click
            # (symmetric with the Linux/macOS standalone binaries).
            updater_exe = self.dist_dir / "veaf-tools-updater.exe"
            veaf_tools_exe = self.dist_dir / "veaf-tools.exe"
            if updater_exe.exists():
                result = subprocess.run(
                    ["gh", "release", "upload", tag_name, str(updater_exe)],
                    cwd=str(self.script_root),
                    env=env,
                    capture_output=True,
                    text=True,
                )
                if result.returncode != 0:
                    logger.warning(f"Failed to upload updater executable: {result.stderr}")
                else:
                    logger.debug("Uploaded veaf-tools-updater.exe to release")

            if veaf_tools_exe.exists():
                result = subprocess.run(
                    ["gh", "release", "upload", tag_name, str(veaf_tools_exe)],
                    cwd=str(self.script_root),
                    env=env,
                    capture_output=True,
                    text=True,
                )
                if result.returncode != 0:
                    logger.warning(f"Failed to upload veaf-tools executable: {result.stderr}")
                else:
                    logger.debug("Uploaded veaf-tools.exe to release")

            result = subprocess.run(
                ["gh", "release", "upload", tag_name, str(package_path)],
                cwd=str(self.script_root),
                env=env,
                capture_output=True,
                text=True,
            )
            if result.returncode != 0:
                logger.error(f"GitHub asset upload failed: {result.stderr}")
                return

            # Upload metadata file for checksum verification.
            # SECREV-2 ticket 04: the updater refuses to install a release with no checksum
            # metadata, so neither a missing file nor a failed upload may pass quietly here —
            # either one publishes a release nobody can install, discovered by a user rather
            # than by us. Both are now errors, like the main asset upload above.
            metadata_file = self.output_path / "published-metadata.json"
            if not metadata_file.exists():
                logger.error(f"Checksum metadata is missing, the release would be uninstallable: {metadata_file}")
                return
            metadata_result = subprocess.run(
                ["gh", "release", "upload", tag_name, str(metadata_file)],
                cwd=str(self.script_root),
                env=env,
                capture_output=True,
                text=True,
            )
            if metadata_result.returncode != 0:
                logger.error(
                    f"Checksum metadata upload failed, the release would be uninstallable: {metadata_result.stderr}"
                )
                return
            logger.debug("Uploaded published-metadata.json to release")

            # Delete auto-generated source archives
            for source_asset in ["Source code (zip)", "Source code (tar.gz)"]:
                subprocess.run(
                    ["gh", "release", "delete-asset", tag_name, source_asset, "--yes"],
                    cwd=str(self.script_root),
                    env=env,
                    capture_output=True,
                    text=True,
                )
                # Ignore errors if asset doesn't exist

            logger.debug(f"GitHub release created and assets uploaded for {tag_name}", no_console=True)

            if self._is_prerelease:
                logger.debug(f"Pre-release: skipping {latest_tag_name} release update", no_console=True)
                return

            # Create or update the "latest" release pointing to the same assets
            subprocess.run(
                ["gh", "release", "delete", latest_tag_name, "--yes"],
                cwd=str(self.script_root),
                env=env,
                capture_output=True,
                text=True,
            )
            # Ignore errors if release doesn't exist

            latest_release_cmd = [
                "gh",
                "release",
                "create",
                latest_tag_name,
                "--latest",
                "-t",
                f"VEAF Tools Latest (v{self.version})",
                *notes_arg,
            ]

            result = subprocess.run(
                latest_release_cmd,
                cwd=str(self.script_root),
                env=env,
                capture_output=True,
                text=True,
            )
            if result.returncode != 0:
                logger.warning(f"GitHub latest release creation failed: {result.stderr}")
                return

            if updater_exe.exists():
                subprocess.run(
                    ["gh", "release", "upload", latest_tag_name, str(updater_exe)],
                    cwd=str(self.script_root),
                    env=env,
                    capture_output=True,
                    text=True,
                )

            if veaf_tools_exe.exists():
                subprocess.run(
                    ["gh", "release", "upload", latest_tag_name, str(veaf_tools_exe)],
                    cwd=str(self.script_root),
                    env=env,
                    capture_output=True,
                    text=True,
                )

            subprocess.run(
                ["gh", "release", "upload", latest_tag_name, str(package_path)],
                cwd=str(self.script_root),
                env=env,
                capture_output=True,
                text=True,
            )

            if metadata_file.exists():
                subprocess.run(
                    ["gh", "release", "upload", latest_tag_name, str(metadata_file)],
                    cwd=str(self.script_root),
                    env=env,
                    capture_output=True,
                    text=True,
                )
                logger.debug("Uploaded published-metadata.json to latest release")

            logger.debug(f"GitHub latest release created and assets uploaded for {latest_tag_name}", no_console=True)

        except Exception as e:
            logger.error(f"GitHub CLI operation failed: {e}")
