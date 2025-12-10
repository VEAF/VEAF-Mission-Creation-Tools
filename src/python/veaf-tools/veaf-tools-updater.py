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

from io import BytesIO
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import zipfile
from typing import Optional, Dict, Any

import typer
import requests
import yaml

from veaf_libs.logger import Logger, console
from veaf_libs.progress import spinner_context

# Create a logger specific to this updater script
logger: Logger = Logger(logger_name="veaf-tools-updater", console=console)

VERSION: str = "6.0.4"
README_HELP: str = "Provide access to the README file."
VERBOSE_HELP: str = "If set, the script will output a lot of debug information."
PAUSE_HELP: str = "If set, the script will pause when finished and wait for the user to press a key."
PAUSE_MESSAGE: str = "Press Enter to continue..."

# String constants
WORK_DONE_MESSAGE: str = "[bold blue]Work done![/bold blue]"
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

def load_config() -> Dict[str, Any]:
    """Load configuration from veaf-tools-config.yaml if it exists."""
    config_path = Path.cwd() / CONFIG_FILE

    if not config_path.exists():
        return {}

    try:
        with open(config_path, 'r') as f:
            config = yaml.safe_load(f)
            if config is None:
                return {}
            logger.debug(f"Loaded configuration from {config_path}")
            return config
    except Exception as e:
        logger.warning(f"Failed to load configuration file: {e}")
        return {}


def resolve_path(path: str, default_path: str = None, should_exist: bool = False, create_if_not_exist: bool = False) -> Path:
    """Resolve and validate a file path."""
    if not path and default_path:
        result = Path(default_path)
    elif path:
        result = Path(path)
    else:
        logger.error("Either path or default_path must be provided", exception_type=ValueError)

    result = result.resolve()

    if create_if_not_exist and not result.exists():
        result.parent.mkdir(parents=True, exist_ok=True)
        if not result.suffix:
            result.mkdir(exist_ok=True)

    if should_exist and not result.exists():
        logger.error(f"Path does not exist: {result}")
        exit(-1)

    return result


class UpdateWorker:
    """Worker class for managing updates."""

    def __init__(
        self,
        mission_folder: str = ".",
        tag: Optional[str] = None,
        token: Optional[str] = None,
        force: bool = False,
        verify_checksum: bool = True,
        verbose: bool = False,
        zip_file_path: Optional[str] = None,
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
            logger.warning("GitHub API rate limit exceeded. Please wait about an hour and try again.")
            logger.error(f"{action} failed: {response.reason} ({response.status_code})")
            return False
        elif response.status_code != 200:
            logger.error(f"{action} failed: {response.reason} ({response.status_code})")
            return False
        return True

    def get_release_by_tag(self, tag_name: str) -> Optional[dict]:
        """Retrieve Release information associated with a Git tag."""
        url = f"{GITHUB_API_BASE}/repos/{GITHUB_REPO_OWNER}/{GITHUB_REPO_NAME}/releases/tags/{tag_name}"
        response = requests.get(url, headers=self.headers)

        if response.status_code == 404:
            logger.warning(f"No release found for tag '{tag_name}'")
            return None

        if not self.check_github_response(response, f"Getting release for tag '{tag_name}' from GitHub"):
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
            logger.error(f"Checksum mismatch for {file_path.name}")
            logger.error(f"  Expected: {expected_checksum}")
            logger.error(f"  Actual:   {actual_checksum}")
            return False
        logger.info(f"Checksum verified for {file_path.name}")
        return True

    def get_installed_version(self, mission_folder: Path) -> Optional[str]:
        """Retrieve the currently installed version from package.json."""
        package_json_path = mission_folder / PUBLISHED_DIR / PACKAGE_JSON_FILE
        if not package_json_path.exists():
            return None

        try:
            with open(package_json_path, 'r') as f:
                package_data = json.load(f)
                return package_data.get("version")
        except (json.JSONDecodeError, IOError) as e:
            logger.warning(f"Failed to read installed version: {e}")
            return None

    def should_update(self, release_version: str, mission_folder: Path) -> bool:
        """Determine if an update is needed by comparing versions."""
        if self.force:
            return True

        installed_version = self.get_installed_version(mission_folder)
        if not installed_version:
            logger.info("No installed version found")
            return True

        # Simple version comparison (assumes semantic versioning)
        try:
            installed_parts = [int(x) for x in installed_version.split('.')]
            release_parts = [int(x) for x in release_version.split('.')]

            # Pad with zeros for comparison
            max_len = max(len(installed_parts), len(release_parts))
            installed_parts.extend([0] * (max_len - len(installed_parts)))
            release_parts.extend([0] * (max_len - len(release_parts)))

            if release_parts > installed_parts:
                logger.info(f"Newer version available: {installed_version} → {release_version}")
                return True
            else:
                logger.info(f"Installed version {installed_version} is already up-to-date")
                return False
        except ValueError:
            logger.warning(f"Could not compare versions: {installed_version} vs {release_version}")
            return True

    def download_asset(self, asset_url: str, asset_name: str) -> Optional[bytes]:
        """Download an asset from a GitHub release."""
        with spinner_context(f"Downloading {asset_name} from GitHub..."):
            response = requests.get(asset_url, headers=self.headers)

        if not self.check_github_response(response, f"Downloading {asset_name}"):
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
            old_exe_path = current_dir / VEAF_TOOLS_EXE
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
                creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == 'nt' else 0,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                cwd=str(current_dir),
            )
            logger.info("Deferred update script launched successfully")
            logger.info("The updater executable will be updated in a few seconds")
            
        except Exception as e:
            logger.warning(f"Failed to launch deferred update: {e}")
            logger.warning("Update of updater executable will be deferred to next run")

    def extract_and_install(self, zip_content: bytes, release_version: str, mission_folder: Path) -> bool:
        """Extract the published.zip file and install it to the mission folder."""
        try:
            # Check if the updater exe is currently running (in current directory)
            current_exe = Path.cwd() / VEAF_TOOLS_EXE
            has_locked_exe = current_exe.exists()
            
            # Step 1: Extract ALL content of published.zip to the "published" folder
            published_dir = mission_folder / PUBLISHED_DIR
            published_dir.mkdir(exist_ok=True)
            
            if has_locked_exe:
                # Extract to a temporary location first to avoid file locking issues
                with spinner_context(f"Extracting published.zip (version {release_version})..."):
                    temp_extract_dir = mission_folder / ".extract-temp"
                    temp_extract_dir.mkdir(exist_ok=True)
                    
                    zip_file = zipfile.ZipFile(BytesIO(zip_content))
                    zip_file.extractall(temp_extract_dir)
                    
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
                with spinner_context(f"Extracting published.zip (version {release_version})..."):
                    zip_file = zipfile.ZipFile(BytesIO(zip_content))
                    zip_file.extractall(published_dir)

            logger.info(f"Successfully extracted release version {release_version} to '{PUBLISHED_DIR}' folder")

            # Step 2: Move key files from published folder to current directory
            with spinner_context("Installing tools to current directory..."):
                files_to_move = ["veaf-tools.exe", "README.md"]
                
                for filename in files_to_move:
                    source_file = published_dir / filename
                    if source_file.exists():
                        dest_file = Path.cwd() / filename
                        shutil.move(str(source_file), str(dest_file))
                        logger.info(f"Moved {filename} to current directory")
                    else:
                        logger.warning(f"File not found in published folder: {filename}")
                
                # Handle veaf-tools-updater.exe with deferred update mechanism
                updater_exe = published_dir / "veaf-tools-updater.exe"
                if updater_exe.exists():
                    if has_locked_exe:
                        # Use deferred update mechanism to avoid file locking
                        pending_dir = Path.cwd() / UPDATE_PENDING_DIR
                        pending_dir.mkdir(exist_ok=True)
                        
                        pending_exe = pending_dir / f"{VEAF_TOOLS_EXE}.new"
                        shutil.move(str(updater_exe), str(pending_exe))
                        logger.info(f"Prepared {VEAF_TOOLS_EXE} for deferred update")
                        
                        # Launch the deferred update script
                        self._launch_deferred_update(pending_dir, pending_exe)
                    else:
                        # No file locking issue, move directly
                        dest_updater = Path.cwd() / VEAF_TOOLS_EXE
                        shutil.move(str(updater_exe), str(dest_updater))
                        logger.info(f"Moved {VEAF_TOOLS_EXE} to current directory")

            return True
        except zipfile.BadZipFile as e:
            logger.error(f"Failed to extract zip file: {e}")
            return False
        except IOError as e:
            logger.error(f"Failed to install files: {e}")
            return False

    def run(self) -> bool:
        """Execute the update process."""
        console.print(f"[bold green]VEAF Tools Updater v{VERSION}[/bold green]")
        console.print(f"Repository: {GITHUB_REPO_OWNER}/{GITHUB_REPO_NAME}")
        
        # Resolve mission folder
        p_mission_folder = resolve_path(path=self.mission_folder, default_path=str(Path.cwd()), should_exist=True)

        # If zip file path is provided, load from local file instead of GitHub
        if self.zip_file_path:
            console.print(f"[bold cyan]Using local ZIP file: {self.zip_file_path}[/bold cyan]\n")
            zip_path = Path(self.zip_file_path)
            
            if not zip_path.exists():
                logger.error(f"ZIP file not found: {zip_path}")
                return False
            
            try:
                zip_content = zip_path.read_bytes()
            except IOError as e:
                logger.error(f"Failed to read ZIP file: {e}")
                return False
            
            # Extract version from zip file path or use a default
            # e.g., "published.zip" → "local"
            import os
            release_version = os.path.splitext(os.path.basename(self.zip_file_path))[0]
            if release_version == "published":
                release_version = "local"
            
            logger.info(f"Loaded ZIP file with version label: {release_version}")
            
            # Extract and install directly
            if self.extract_and_install(zip_content, release_version, p_mission_folder):
                logger.info(f"Successfully installed from local ZIP")
                console.print(WORK_DONE_MESSAGE)
                return True
            else:
                logger.error("Installation failed")
                return False

        # Fetch release information from GitHub
        console.print(f"Requested tag: {self.tag}\n")
        with spinner_context(f"Fetching release information for '{self.tag}'..."):
            release_payload = self.get_release_by_tag(self.tag)

        if not release_payload:
            logger.error(f"Failed to fetch release for tag '{self.tag}'")
            return False

        # Extract version from release
        release_tag = release_payload.get("tag_name", self.tag)
        release_version = re.sub(r'^v', '', release_tag)
        
        # For "published-latest" tag, extract actual version from release name or body
        if release_version == "published-latest":
            release_name = release_payload.get("name", "")
            # Try to extract version from title like "VEAF Tools Latest (v6.0.3)"
            version_match = re.search(r'\(v?([\d.]+)\)', release_name)
            if version_match:
                release_version = version_match.group(1)
            else:
                # Try to extract from body if available
                release_body = release_payload.get("body", "")
                version_match = re.search(r'v?([\d.]+)', release_body)
                if version_match:
                    release_version = version_match.group(1)
        
        logger.info(f"Found release version: {release_version}")

        # Check if update is needed
        if not self.should_update(release_version, p_mission_folder):
            if self.force:
                logger.info("Force flag set, proceeding with update anyway")
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
            logger.error(f"No '{PUBLISHED_ZIP_ASSET_NAME}' asset found in release")
            return False

        # Download the zip file
        zip_content = self.download_asset(
            published_asset.get("browser_download_url"),
            PUBLISHED_ZIP_ASSET_NAME
        )
        if not zip_content:
            logger.error("Failed to download published.zip")
            return False

        # Verify checksum if enabled
        if self.verify_checksum:
            with spinner_context("Verifying file integrity..."):
                metadata_asset = None
                for asset in release_payload.get("assets", []):
                    if asset.get("name") == PUBLISHED_METADATA_ASSET_NAME:
                        metadata_asset = asset
                        break

                if metadata_asset:
                    metadata_content = self.download_asset(
                        metadata_asset.get("browser_download_url"),
                        PUBLISHED_METADATA_ASSET_NAME
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
                                    logger.error("Checksum verification failed, aborting installation")
                                    return False
                                temp_zip.unlink()
                        except json.JSONDecodeError:
                            logger.warning("Could not parse metadata file, skipping checksum verification")
                else:
                    logger.warning("No metadata asset found, skipping checksum verification")

        # Extract and install
        if self.extract_and_install(zip_content, release_version, p_mission_folder):
            logger.info(f"Successfully updated to version {release_version}")
            console.print(WORK_DONE_MESSAGE)
            return True
        else:
            logger.error("Installation failed")
            return False


# ============================================================================
# Main Entry Point
# ============================================================================


def main(
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    force: bool = typer.Option(False, help="Ignore version check and install anyway"),
    tag: Optional[str] = typer.Option(None, help="Tag name to fetch (default: published-latest)"),
    token: Optional[str] = typer.Option(None, help="GitHub Personal Access Token (overrides config file)"),
    mission_folder: Optional[str] = typer.Argument(None, help="Mission folder path (overrides config file)"),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
    no_verify_checksum: bool = typer.Option(False, help="Skip checksum verification (not recommended)"),
    zip_file: Optional[str] = typer.Option(None, help="Path to local published.zip file (for testing, skips GitHub)"),
) -> None:
    """
    Downloads the latest VEAF Tools files from GitHub using Git tags.

    This command fetches compiled tools and scripts from GitHub releases.
    By default, it uses the 'published-latest' tag which always points to the most recent version.
    
    For testing, use --zip-file to install from a local published.zip file instead of GitHub.
    """
    logger.set_verbose(verbose)

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


if __name__ == "__main__":
    typer.run(main)


