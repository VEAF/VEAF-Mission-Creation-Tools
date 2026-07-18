"""
VEAF Tools - Update Management System

This program provides a CLI for updating VEAF Tools from GitHub releases.

Features:
- Git tag-based versioning (published-latest, published-vX.Y.Z)
- SHA256 checksum verification for integrity
- Semantic version comparison
- Detailed logging and error handling

Usage:
- Run with 'veaf-tools-updater.exe' to update installed tools
- Run with 'veaf-tools-updater.exe --help' for command reference
"""

import hashlib
import json
import re
import shutil
import subprocess
import sys
import zipfile
from importlib.metadata import PackageNotFoundError
from importlib.metadata import version as _pkg_version
from io import BytesIO
from pathlib import Path
from typing import Any

import requests
import typer
import yaml
from veaf_libs import platform_assets
from veaf_libs.i18n import set_language, t
from veaf_libs.logger import Logger, console
from veaf_libs.paths import resolve_path
from veaf_libs.progress import spinner_context
from veaf_libs.safe_zip import safe_extract_all
from veaf_tools.helpers import should_auto_pause

# Parse --lang early from sys.argv so that --help is also rendered in the
# requested language (Typer's --help is eager and fires before main_callback).
for _i, _a in enumerate(sys.argv[1:]):
    if _a == "--lang" and _i + 1 < len(sys.argv) - 1:
        set_language(sys.argv[_i + 2])
        break
    if _a.startswith("--lang="):
        set_language(_a.split("=", 1)[1])
        break

# Create a logger specific to this updater script
logger: Logger = Logger(logger_name="veaf-tools-updater", console=console)

try:
    VERSION: str = _pkg_version("veaf-tools")
except PackageNotFoundError:
    try:
        from veaf_tools._version import __version__ as _fallback

        VERSION = _fallback
    except ImportError:
        VERSION = "unknown"
README_HELP: str = t("help.readme")
VERBOSE_HELP: str = t("help.verbose")
PAUSE_HELP: str = t("help.pause")
PAUSE_MESSAGE: str = t("help.pause_msg")
FORCE_HELP: str = t("updater.opt.force")
TAG_HELP: str = t("updater.opt.tag")
TOKEN_HELP: str = t("updater.opt.token")
MISSION_FOLDER_HELP: str = t("updater.opt.mission_folder")
NO_VERIFY_HELP: str = t("updater.opt.no_verify_checksum")
ZIP_FILE_HELP: str = t("updater.opt.zip_file")

# String constants
WORK_DONE_MESSAGE: str = t("msg.work_done")
GITHUB_REPO_OWNER = "VEAF"
GITHUB_REPO_NAME = "VEAF-Mission-Creation-Tools"
GITHUB_API_BASE = "https://api.github.com"
GITHUB_PUBLISHED_LATEST_TAG = "published-latest"
PUBLISHED_ZIP_ASSET_NAME = "published.zip"
PUBLISHED_METADATA_ASSET_NAME = "published-metadata.json"

# File paths and extensions
PUBLISHED_DIR = "published"
VEAF_TOOLS_EXE = "veaf-tools-updater.exe"
BUILD_SCRIPTS_DIR = "build-scripts"
PACKAGE_JSON_FILE = "package.json"
CONFIG_FILE = "veaf-tools-config.yaml"
UPDATE_PENDING_DIR = ".veaf-update-pending"


def load_config() -> dict[str, Any]:
    """Load configuration from veaf-tools-config.yaml if it exists."""
    config_path = Path.cwd() / CONFIG_FILE

    if not config_path.exists():
        return {}

    try:
        with open(config_path) as f:
            config = yaml.safe_load(f)
            if config is None:
                return {}
            logger.debug(f"Loaded configuration from {config_path}")
            return config
    except Exception as e:
        logger.warning(t("updater.config_load_failed", error=str(e)))
        return {}


def parse_version_parts(version: str) -> list[int]:
    """Parse a semantic version string into a list of integers."""
    return [int(x) for x in version.split(".")]


def version_matches_constraint(release_version: str, constraint: str) -> bool:
    """
    Return True if release_version satisfies the constraint.

    Supported formats:
      "6"       — accept any 6.x.x  (prefix match on major)
      "6.1"     — accept any 6.1.x  (prefix match on major.minor)
      "6.1.3"   — accept exactly 6.1.3
      "^6.1.3"  — compatible range: >=6.1.3, <7.0.0 (same major)
      "~6.1.3"  — approximate range: >=6.1.3, <6.2.0 (same major.minor)
    """
    try:
        rel = parse_version_parts(release_version)

        if constraint.startswith("^"):
            # Compatible: same major, >= constraint version
            pin = parse_version_parts(constraint[1:])
            pin_padded = pin + [0] * (3 - len(pin))
            rel_padded = rel + [0] * (3 - len(rel))
            return rel_padded[0] == pin_padded[0] and rel_padded >= pin_padded

        if constraint.startswith("~"):
            # Approximate: same major.minor, >= constraint version
            pin = parse_version_parts(constraint[1:])
            pin_padded = pin + [0] * (3 - len(pin))
            rel_padded = rel + [0] * (3 - len(rel))
            return rel_padded[0] == pin_padded[0] and rel_padded[1] == pin_padded[1] and rel_padded >= pin_padded

        # Prefix match: constraint is a partial version
        pin = parse_version_parts(constraint)
        return rel[: len(pin)] == pin

    except ValueError:
        return False


class UpdateWorker:
    """Worker class for managing updates."""

    def __init__(
        self,
        mission_folder: str | None = ".",
        tag: str | None = None,
        token: str | None = None,
        force: bool = False,
        verify_checksum: bool = True,
        verbose: bool = False,
        zip_file_path: str | None = None,
    ):
        """Initialize the update worker."""
        self.mission_folder = mission_folder
        self.tag = tag or GITHUB_PUBLISHED_LATEST_TAG
        self.token = token
        self.force = force
        self.verify_checksum = verify_checksum
        self.verbose = verbose
        self.zip_file_path = zip_file_path

        logger.set_verbose(verbose)

        # Setup GitHub API headers
        self.headers = {}
        if token:
            self.headers["Authorization"] = f"token {token}"
        self.headers["Accept"] = "application/vnd.github.v3+json"

    def check_github_response(self, response: requests.Response, action: str) -> bool:
        """Check GitHub API response and log errors appropriately."""
        if response.status_code == 403 and "rate limit" in response.reason.lower():
            logger.warning(t("updater.warn.rate_limit"))
            logger.error(
                t("updater.err.request_failed", action=action, reason=response.reason, code=response.status_code)
            )
            return False
        elif response.status_code != 200:
            logger.error(
                t("updater.err.request_failed", action=action, reason=response.reason, code=response.status_code)
            )
            return False
        return True

    def get_release_by_tag(self, tag_name: str) -> dict | None:
        """Retrieve Release information associated with a Git tag."""
        url = f"{GITHUB_API_BASE}/repos/{GITHUB_REPO_OWNER}/{GITHUB_REPO_NAME}/releases/tags/{tag_name}"
        response = requests.get(url, headers=self.headers)

        if response.status_code == 404:
            logger.warning(t("updater.err.no_release", tag=tag_name))
            return None

        if not self.check_github_response(response, t("updater.action.get_release", tag=tag_name)):
            return None

        return response.json()

    @staticmethod
    def calculate_sha256(file_path: Path) -> str:
        """Calculate SHA256 checksum of a file."""
        sha256_hash = hashlib.sha256()
        with open(file_path, "rb") as f:
            for byte_block in iter(lambda: f.read(4096), b""):
                sha256_hash.update(byte_block)
        return sha256_hash.hexdigest()

    def verify_file_integrity(self, file_path: Path, expected_checksum: str) -> bool:
        """Verify file integrity by comparing checksums."""
        actual_checksum = self.calculate_sha256(file_path)
        if actual_checksum.lower() != expected_checksum.lower():
            logger.error(t("updater.err.checksum_mismatch", name=file_path.name))
            logger.error(t("updater.err.checksum_expected", checksum=expected_checksum))
            logger.error(t("updater.err.checksum_actual", checksum=actual_checksum))
            return False
        logger.info(t("updater.checksum_ok", name=file_path.name))
        return True

    def get_installed_version(self, mission_folder: Path) -> str | None:
        """Retrieve the currently installed version from package.json."""
        package_json_path = mission_folder / PUBLISHED_DIR / PACKAGE_JSON_FILE
        if not package_json_path.exists():
            return None

        try:
            with open(package_json_path) as f:
                package_data = json.load(f)
                return package_data.get("version")
        except (OSError, json.JSONDecodeError) as e:
            logger.warning(t("updater.err.version_read", error=str(e)))
            return None

    def get_version_constraint(self, mission_folder: Path) -> str | None:
        """Read the optional version constraint from mission.yaml (veaf_tools: version:)."""
        mission_yaml_path = mission_folder / "mission.yaml"
        if not mission_yaml_path.exists():
            return None
        try:
            with open(mission_yaml_path) as f:
                config = yaml.safe_load(f)
            if not config:
                return None
            veaf_tools = config.get("veaf_tools")
            if isinstance(veaf_tools, dict):
                return veaf_tools.get("version")
        except Exception:
            pass
        return None

    def should_update(self, release_version: str, mission_folder: Path) -> bool:
        """Determine if an update is needed by comparing versions."""
        if self.force:
            return True

        # Check version constraint from mission.yaml
        constraint = self.get_version_constraint(mission_folder)
        if constraint:
            logger.info(t("updater.version_constraint", constraint=constraint))
            if not version_matches_constraint(release_version, constraint):
                logger.info(t("updater.version_pinned", version=release_version, constraint=constraint))
                return False

        installed_version = self.get_installed_version(mission_folder)
        if not installed_version:
            logger.info(t("updater.no_installed"))
            return True

        # Simple version comparison (assumes semantic versioning)
        try:
            installed_parts = [int(x) for x in installed_version.split(".")]
            release_parts = [int(x) for x in release_version.split(".")]

            # Pad with zeros for comparison
            max_len = max(len(installed_parts), len(release_parts))
            installed_parts.extend([0] * (max_len - len(installed_parts)))
            release_parts.extend([0] * (max_len - len(release_parts)))

            if release_parts > installed_parts:
                logger.info(t("updater.newer_available", installed=installed_version, release=release_version))
                return True
            else:
                logger.tech(t("updater.up_to_date", version=installed_version))
                return False
        except ValueError:
            logger.warning(t("updater.warn.compare_versions", v1=installed_version, v2=release_version))
            return True

    def download_asset(self, asset_url: str, asset_name: str) -> bytes | None:
        """Download an asset from a GitHub release."""
        with spinner_context(t("updater.downloading", name=asset_name)):
            response = requests.get(asset_url, headers=self.headers)

        if not self.check_github_response(response, t("updater.action.download", name=asset_name)):
            return None

        return response.content

    def _launch_deferred_update(self, pending_dir: Path, pending_exe: Path) -> None:
        """
        Launch a deferred update script that will replace the updater executable.

        This avoids file locking issues by:
        1. Copying the new exe to a pending directory
        2. Creating a batch script that will execute after this process exits
        3. The batch script waits, then replaces the old exe with the new one
        """
        try:
            # Create the update script
            update_script = pending_dir / "apply-update.cmd"

            # Get absolute paths for the script
            current_dir = Path.cwd()
            new_exe_path = pending_exe.resolve()
            backup_exe_path = current_dir / f"{VEAF_TOOLS_EXE}.old"

            script_content = f"""@echo off
REM Auto-generated update script for veaf-tools-updater.exe
REM This script is run after the updater process exits to avoid file locking issues

setlocal enabledelayedexpansion
cd /d "{current_dir}"

REM Wait for the updater process to finish
timeout /t 2 /nobreak >nul 2>&1

REM Remove old backup if it exists
if exist "{backup_exe_path.name}" (
    del /f /q "{backup_exe_path.name}" 2>nul
)

REM Replace the executable
if exist "{new_exe_path.name}" (
    REM Rename current executable to .old
    ren "{VEAF_TOOLS_EXE}" "{backup_exe_path.name}" 2>nul

    if !errorlevel! equ 0 (
        REM Rename pending exe to active name
        ren "{new_exe_path.name}" "{VEAF_TOOLS_EXE}" 2>nul

        if !errorlevel! equ 0 (
            echo Update successful: veaf-tools-updater.exe has been updated
            REM Clean up backup
            del /f /q "{backup_exe_path.name}" 2>nul
        ) else (
            echo ERROR: Failed to rename new exe
            REM Restore old exe if rename failed
            ren "{backup_exe_path.name}" "{VEAF_TOOLS_EXE}" 2>nul
        )
    ) else (
        echo ERROR: Failed to backup current exe
    )
)

REM Clean up pending directory
if exist ".\\{UPDATE_PENDING_DIR}" (
    rmdir /s /q ".\\{UPDATE_PENDING_DIR}" 2>nul
)

exit /b 0
"""

            update_script.write_text(script_content)
            logger.debug(f"Created update script: {update_script}")

            # Launch the script in background
            import os

            subprocess.Popen(
                str(update_script),
                shell=True,
                creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                cwd=str(current_dir),
            )
            logger.info(t("updater.deferred_launched"))
            logger.info(t("updater.deferred_pending"))

        except Exception as e:
            logger.warning(t("updater.err.deferred_failed", error=str(e)))
            logger.warning(t("updater.err.deferred_next_run"))

    def extract_and_install(
        self,
        zip_content: bytes,
        release_version: str,
        mission_folder: Path,
        release_assets: list[dict] | None = None,
    ) -> bool:
        """Extract the published.zip file and install it to the mission folder.

        Args:
            zip_content: Raw bytes of the downloaded ``published.zip``.
            release_version: Version label of the release being installed.
            mission_folder: Target VEAF mission folder.
            release_assets: The release's asset list (from the GitHub payload). Used on
                Unix to download the standalone binaries, which are not in the zip.
                ``None`` for an offline ``--zip-file`` install (Unix then skips the
                binary with a warning).
        """
        try:
            # Check if the updater exe is currently running (in current directory)
            current_exe = Path.cwd() / VEAF_TOOLS_EXE
            has_locked_exe = current_exe.exists()

            # Step 1: Extract ALL content of published.zip to the "published" folder
            is_first_install = not (mission_folder / PUBLISHED_DIR).exists()
            published_dir = mission_folder / PUBLISHED_DIR
            published_dir.mkdir(exist_ok=True)

            if has_locked_exe:
                # Extract to a temporary location first to avoid file locking issues
                with spinner_context(t("updater.extracting", version=release_version)):
                    temp_extract_dir = mission_folder / ".extract-temp"
                    temp_extract_dir.mkdir(exist_ok=True)

                    zip_file = zipfile.ZipFile(BytesIO(zip_content))
                    safe_extract_all(zip_file, temp_extract_dir)

                    # Move ALL extracted files to the published directory
                    # The zip content structure is: published/* which becomes the root after extraction
                    for item in temp_extract_dir.iterdir():
                        dest = published_dir / item.name

                        # Remove destination if it exists
                        if dest.exists():
                            if dest.is_dir():
                                shutil.rmtree(dest)
                            else:
                                dest.unlink()

                        shutil.move(str(item), str(dest))

                    # Clean up temporary extraction directory
                    shutil.rmtree(temp_extract_dir, ignore_errors=True)
            else:
                # No locked exe, extract directly to published directory
                with spinner_context(t("updater.extracting", version=release_version)):
                    zip_file = zipfile.ZipFile(BytesIO(zip_content))
                    safe_extract_all(zip_file, published_dir)

            logger.info(t("updater.extracted", version=release_version, dir=PUBLISHED_DIR))

            # Step 2: Install the platform binaries. On Windows they ship inside
            # published.zip (moved out here, with the deferred self-update dance to
            # dodge the running-exe lock). On Unix they ship as separate release
            # assets, downloaded and made executable by _install_unix_binaries.
            if platform_assets.is_windows():
                self._install_windows_binaries(published_dir, has_locked_exe)
            else:
                self._install_unix_binaries(release_assets)

            # Step 3: Display first-install guidance
            self._install_defaults(mission_folder, is_first_install)

            return True
        except zipfile.BadZipFile as e:
            logger.error(t("updater.err.extract_zip", error=str(e)))
            return False
        except OSError as e:
            logger.error(t("updater.err.install", error=str(e)))
            return False

    def _install_windows_binaries(self, published_dir: Path, has_locked_exe: bool) -> None:
        """Move the Windows binaries out of published/ into the mission folder.

        README.md is intentionally NOT moved (IMC2-002): its relative links are dead in
        the mission folder and it would overwrite the user's own README — it stays under
        /published/; the online docs are the source. The updater replaces itself through
        a deferred .cmd script to dodge the Windows lock on the running exe.
        """
        with spinner_context(t("updater.installing")):
            for filename in ["veaf-tools.exe"]:
                source_file = published_dir / filename
                if source_file.exists():
                    shutil.move(str(source_file), str(Path.cwd() / filename))
                    logger.info(t("updater.moved", name=filename))
                else:
                    logger.warning(t("updater.err.file_not_found", name=filename))

            # Handle veaf-tools-updater.exe with deferred update mechanism
            updater_exe = published_dir / "veaf-tools-updater.exe"
            if updater_exe.exists():
                if has_locked_exe:
                    # Use deferred update mechanism to avoid file locking
                    pending_dir = Path.cwd() / UPDATE_PENDING_DIR
                    pending_dir.mkdir(exist_ok=True)

                    pending_exe = pending_dir / f"{VEAF_TOOLS_EXE}.new"
                    shutil.move(str(updater_exe), str(pending_exe))
                    logger.info(t("updater.deferred_prepared", name=VEAF_TOOLS_EXE))

                    # Launch the deferred update script
                    self._launch_deferred_update(pending_dir, pending_exe)
                else:
                    # No file locking issue, move directly
                    shutil.move(str(updater_exe), str(Path.cwd() / VEAF_TOOLS_EXE))
                    logger.info(t("updater.moved", name=VEAF_TOOLS_EXE))

    def _install_unix_binaries(self, release_assets: list[dict] | None) -> None:
        """Install the Linux/macOS binaries from the release's standalone assets.

        On Unix the binaries are not bundled in published.zip; they are downloaded from
        the per-OS release assets (``veaf-tools-<os>-<arch>``), placed in the mission
        folder, and made executable. Replacing the running updater's own file is safe on
        Unix — the live process keeps the old inode — so no deferred dance is needed.

        Args:
            release_assets: The release asset list, or ``None`` for an offline
                ``--zip-file`` install (the binary is then not available; warn and skip).
        """
        if not release_assets:
            logger.warning(t("updater.warn.unix_no_binary_in_zip"))
            return

        tools_asset = platform_assets.veaf_tools_asset_name()
        updater_asset = platform_assets.updater_asset_name()
        if not tools_asset or not updater_asset:  # unsupported platform/arch — no asset applies
            logger.warning(t("updater.warn.unix_unsupported"))
            return

        # Attempt both binaries independently: a missing/failed one must not skip the other.
        with spinner_context(t("updater.installing")):
            self._download_binary_asset(
                release_assets, tools_asset, Path.cwd() / platform_assets.veaf_tools_binary_name()
            )
            self._download_binary_asset(
                release_assets, updater_asset, Path.cwd() / platform_assets.updater_binary_name()
            )

    def _download_binary_asset(self, release_assets: list[dict], asset_name: str, dest: Path) -> bool:
        """Download a named release asset to ``dest`` and mark it executable.

        Writes to a temporary sibling then atomically replaces ``dest`` (so a partial
        download never leaves a half-written binary), and sets the executable bit.

        Returns:
            ``True`` on success; ``False`` if the asset is absent from the release or the
            download failed (both are logged as errors so the failure is surfaced).
        """
        import os

        # exception_type=None: log at error level but do NOT raise — a failure on one
        # binary must surface yet still let the other be attempted (and not roll back
        # the common content already installed from the zip).
        asset = next((a for a in release_assets if a.get("name") == asset_name), None)
        if not asset:
            logger.error(t("updater.err.no_asset", name=asset_name), exception_type=None)
            return False

        content = self.download_asset(asset.get("browser_download_url"), asset_name)
        if not content:
            logger.error(t("updater.err.binary_download_failed", name=asset_name), exception_type=None)
            return False

        tmp = dest.with_name(f"{dest.name}.new")
        tmp.write_bytes(content)
        tmp.chmod(0o755)
        os.replace(str(tmp), str(dest))
        logger.info(t("updater.moved", name=dest.name))
        return True

    def _install_defaults(self, mission_folder: Path, is_first_install: bool) -> None:
        """Display first-install guidance after a fresh install."""
        if not is_first_install:
            return

        console.print(t("updater.first_install"))
        console.print(
            t(
                "updater.lang_tip",
                url="https://veaf.github.io/documentation/dev/mission-maker/GUIDE/#global-user-configuration",
            )
        )

    def run(self) -> bool:
        """Execute the update process."""
        console.print(t("updater.header", version=VERSION))
        console.print(t("updater.repository", owner=GITHUB_REPO_OWNER, name=GITHUB_REPO_NAME))

        # Resolve mission folder
        p_mission_folder = resolve_path(path=self.mission_folder, default_path=str(Path.cwd()), should_exist=True)

        # If zip file path is provided, load from local file instead of GitHub
        if self.zip_file_path:
            console.print(t("updater.local_zip", path=self.zip_file_path))
            zip_path = Path(self.zip_file_path)

            if not zip_path.exists():
                logger.error(t("updater.err.zip_not_found", path=zip_path))
                return False

            try:
                zip_content = zip_path.read_bytes()
            except OSError as e:
                logger.error(t("updater.err.zip_read", error=str(e)))
                return False

            # Extract version from zip file path or use a default
            # e.g., "published.zip" → "local"
            import os

            release_version = os.path.splitext(os.path.basename(self.zip_file_path))[0]
            if release_version == "published":
                release_version = "local"

            logger.info(t("updater.local_zip_loaded", version=release_version))

            # Extract and install directly
            if self.extract_and_install(zip_content, release_version, p_mission_folder):
                logger.info(t("updater.local_zip_installed"))
                console.print(WORK_DONE_MESSAGE)
                return True
            else:
                logger.error(t("updater.err.install_failed"))
                return False

        # Fetch release information from GitHub
        console.print(t("updater.requested_tag", tag=self.tag))
        with spinner_context(t("updater.fetching_release", tag=self.tag)):
            release_payload = self.get_release_by_tag(self.tag)

        if not release_payload:
            logger.error(t("updater.err.fetch_failed", tag=self.tag))
            return False

        # Extract version from release
        release_tag = release_payload.get("tag_name", self.tag)
        release_version = re.sub(r"^v", "", release_tag)

        # For "published-latest" tag, extract actual version from release name or body
        if release_version == "published-latest":
            release_name = release_payload.get("name", "")
            # Try to extract version from title like "VEAF Tools Latest (v6.0.3)"
            version_match = re.search(r"\(v?([\d.]+)\)", release_name)
            if version_match:
                release_version = version_match.group(1)
            else:
                # Try to extract from body if available
                release_body = release_payload.get("body", "")
                version_match = re.search(r"v?([\d.]+)", release_body)
                if version_match:
                    release_version = version_match.group(1)

        logger.info(t("updater.found_version", version=release_version))

        # Check if update is needed
        if not self.should_update(release_version, p_mission_folder):
            if self.force:
                logger.info(t("updater.force_update"))
            else:
                console.print(WORK_DONE_MESSAGE)
                return True

        # Find published.zip asset
        published_asset = None
        for asset in release_payload.get("assets", []):
            if asset.get("name") == PUBLISHED_ZIP_ASSET_NAME:
                published_asset = asset
                break

        if not published_asset:
            logger.error(t("updater.err.no_asset", name=PUBLISHED_ZIP_ASSET_NAME))
            return False

        # Download the zip file
        zip_content = self.download_asset(published_asset.get("browser_download_url"), PUBLISHED_ZIP_ASSET_NAME)
        if not zip_content:
            logger.error(t("updater.err.download_failed"))
            return False

        # Verify checksum if enabled
        if self.verify_checksum:
            with spinner_context(t("updater.verifying")):
                metadata_asset = None
                for asset in release_payload.get("assets", []):
                    if asset.get("name") == PUBLISHED_METADATA_ASSET_NAME:
                        metadata_asset = asset
                        break

                if metadata_asset:
                    metadata_content = self.download_asset(
                        metadata_asset.get("browser_download_url"), PUBLISHED_METADATA_ASSET_NAME
                    )
                    if metadata_content:
                        try:
                            metadata = json.loads(metadata_content)
                            published_checksum = metadata.get("published_zip_sha256")
                            if published_checksum:
                                # Save to temp file for verification
                                temp_zip = Path.cwd() / f"published_{release_version}.zip.tmp"
                                temp_zip.write_bytes(zip_content)
                                if not self.verify_file_integrity(temp_zip, published_checksum):
                                    temp_zip.unlink()
                                    logger.error(t("updater.err.checksum_failed"))
                                    return False
                                temp_zip.unlink()
                        except json.JSONDecodeError:
                            logger.warning(t("updater.warn.metadata_parse"))
                else:
                    logger.warning(t("updater.warn.no_metadata"))

        # Extract and install (pass the asset list so Unix can fetch its binaries)
        if self.extract_and_install(
            zip_content, release_version, p_mission_folder, release_assets=release_payload.get("assets", [])
        ):
            logger.tech(t("updater.success", version=release_version))
            console.print(WORK_DONE_MESSAGE)
            return True
        else:
            logger.error(t("updater.err.install_failed"))
            return False


# ============================================================================
# Main Entry Point
# ============================================================================


def main(
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    force: bool = typer.Option(False, help=FORCE_HELP),
    tag: str | None = typer.Option(None, help=TAG_HELP),
    token: str | None = typer.Option(None, help=TOKEN_HELP),
    mission_folder: str | None = typer.Argument(None, help=MISSION_FOLDER_HELP),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
    no_verify_checksum: bool = typer.Option(False, help=NO_VERIFY_HELP),
    zip_file: str | None = typer.Option(None, help=ZIP_FILE_HELP),
    lang: str | None = typer.Option(None, help=t("help.lang")),
) -> None:
    """placeholder"""
    logger.set_verbose(verbose)
    if lang:
        set_language(lang)

    # Load configuration from file
    config = load_config()

    # Apply config file settings, allow CLI arguments to override
    if token is None:
        token = config.get("github", {}).get("token")

    if mission_folder is None:
        mission_folder = config.get("update", {}).get("missionFolder", ".")

    verify_checksum = not no_verify_checksum

    worker = UpdateWorker(
        mission_folder=mission_folder,
        tag=tag,
        token=token,
        force=force,
        verify_checksum=verify_checksum,
        verbose=verbose,
        zip_file_path=zip_file,
    )

    success = worker.run()

    if pause:
        input(PAUSE_MESSAGE)

    if not success:
        raise typer.Exit(code=1)


main.__doc__ = t("updater.cmd_help")

if __name__ == "__main__":
    auto_pause = should_auto_pause()
    try:
        typer.run(main)
    finally:
        logger.stop_status()
        if auto_pause:
            input(PAUSE_MESSAGE)
