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
import zipfile
from typing import Optional, Dict, Any

import typer
import requests
import yaml

from veaf_libs.logger import logger, console
from veaf_libs.progress import spinner_context

VERSION: str = "6.0.1"
README_HELP: str = "Provide access to the README file."
VERSION: str = "6.0.1"
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
PACKAGE_JSON_FILE = "package.json"
CONFIG_FILE = "veaf-tools-config.yaml"

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
    ):
        """Initialize the update worker."""
        self.mission_folder = mission_folder
        self.tag = tag or GITHUB_PUBLISHED_LATEST_TAG
        self.token = token
        self.force = force
        self.verify_checksum = verify_checksum
        self.verbose = verbose

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

    def extract_and_install(self, zip_content: bytes, release_version: str, mission_folder: Path) -> bool:
        """Extract the published.zip file and install it to the mission folder."""
        try:
            with spinner_context(f"Extracting published.zip (version {release_version})..."):
                zip_file = zipfile.ZipFile(BytesIO(zip_content))
                zip_file.extractall(mission_folder)

            logger.info(f"Successfully extracted release version {release_version}")

            # Copy key files to current directory
            with spinner_context("Installing tools to current directory..."):
                exe_source = mission_folder / PUBLISHED_DIR / VEAF_TOOLS_EXE
                if exe_source.exists():
                    shutil.copy2(exe_source, Path.cwd() / VEAF_TOOLS_EXE)
                    logger.info(f"Copied {VEAF_TOOLS_EXE} to current directory")

                scripts_dir = mission_folder / PUBLISHED_DIR / BUILD_SCRIPTS_DIR
                if scripts_dir.exists():
                    for script_file in scripts_dir.glob("*.cmd"):
                        shutil.copy2(script_file, Path.cwd() / script_file.name)
                    logger.info("Copied build scripts to current directory")

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
        console.print(f"Requested tag: {self.tag}\n")

        # Resolve mission folder
        p_mission_folder = resolve_path(path=self.mission_folder, default_path=str(Path.cwd()), should_exist=True)

        # Fetch release information
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
) -> None:
    """
    Downloads the latest VEAF Tools files from GitHub using Git tags.

    This command fetches compiled tools and scripts from GitHub releases.
    By default, it uses the 'published-latest' tag which always points to the most recent version.
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
    )

    success = worker.run()

    if pause:
        input(PAUSE_MESSAGE)

    if not success:
        raise typer.Exit(code=1)


if __name__ == "__main__":
    typer.run(main)


