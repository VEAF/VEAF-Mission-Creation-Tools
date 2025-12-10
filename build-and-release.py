#!/usr/bin/env python3
"""
VEAF Tools - Build and Release Script

Compiles VEAF Tools executables and prepares a release.

This script automates the complete build and release process:
1. Validates prerequisites (PyInstaller, Git, etc.)
2. Builds the Lua scripts artifact
3. Compiles Python executables (veaf-tools, veaf-tools-updater)
4. Creates a release package (published.zip)
5. Optionally publishes to GitHub

Usage:
    python build-and-release.py build --version 6.0.2
    python build-and-release.py publish --version 6.0.2
    python build-and-release.py build --version 6.0.2 --skip-lua
    python build-and-release.py --help
"""

import json
import os
import re
import shutil
import subprocess
import sys
import zipfile
from datetime import datetime
from pathlib import Path
from hashlib import sha256
from typing import Optional, Dict, Any

import typer
import yaml
from rich.console import Console
from rich.markdown import Markdown
from rich.table import Table
from rich.progress import Progress, SpinnerColumn, BarColumn, TextColumn, TimeRemainingColumn
from rich.live import Live

# Setup logging and console - must be done before imports to avoid circular dependencies
# Note: We'll initialize logger after adding sys.path
sys.path.insert(0, str(Path(__file__).parent / "src" / "python" / "veaf-tools"))

from veaf_libs.logger import logger, console
from veaf_libs.progress import spinner_context, progress_context

README_HELP: str = "Provide access to the README file."
VERBOSE_HELP: str = "If set, the script will output a lot of debug information."
PAUSE_MESSAGE: str = "Press Enter to exit..."
CONFIG_FILE: str = "veaf-tools-config.yaml"

app = typer.Typer()


def load_config() -> Dict[str, Any]:
    """Load configuration from veaf-tools-config.yaml if it exists."""
    config_path = Path.cwd() / CONFIG_FILE

    if not config_path.exists():
        return {}

    try:
        with open(config_path, "r", encoding="utf-8") as f:
            config = yaml.safe_load(f)
            if config is None:
                return {}
            logger.debug(f"Loaded configuration from {config_path}")
            return config
    except Exception as e:
        logger.warning(f"Failed to load configuration file: {e}")
        return {}


class BuildAndReleaseWorker:
    """Worker class for build and release operations."""

    def __init__(
        self,
        version: Optional[str] = None,
        skip_lua: bool = False,
        skip_python: bool = False,
        development_build: bool = False,
        publish_to_github: bool = False,
        github_token: Optional[str] = None,
        output_path: Optional[Path] = None,
        verbose: bool = False,
        config: Optional[Dict[str, Any]] = None,
    ):
        """Initialize the build and release worker."""
        self.config = config or {}
        
        # GitHub configuration from config file or defaults
        github_config = self.config.get("github", {})
        self.github_owner = github_config.get("owner", "VEAF")
        self.github_repo = github_config.get("repo", "VEAF-Mission-Creation-Tools")
        
        # Use CLI token if provided, otherwise fall back to config file, then env var
        if github_token:
            self.github_token = github_token
        else:
            self.github_token = github_config.get("token") or os.getenv("GITHUB_TOKEN")
        
        self.script_root = Path(__file__).parent.resolve()
        self.build_dir = self.script_root / "build"
        self.src_dir = self.script_root / "src"
        self.dist_dir = self.script_root / "dist"
        self.version_file = self.script_root / "package.json"

        self.version = version
        self.skip_lua = skip_lua
        self.skip_python = skip_python
        self.development_build = development_build
        self.publish_to_github = publish_to_github
        self.github_token = github_token
        self.output_path = output_path or self.script_root
        self.verbose = verbose

        logger.set_verbose(verbose)

    # ========================================================================
    # Validation
    # ========================================================================

    def check_command(self, command: str, display_name: str) -> bool:
        """Check if a command is available."""
        try:
            result = subprocess.run(
                [command, "--version"],
                capture_output=True,
                text=True,
                timeout=5,
            )
            return result.returncode == 0
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return False

    def validate_prerequisites(self):
        """Validate that all required tools are available."""
        with spinner_context("Checking prerequisites..."):
            required_tools = {
                "python": "Python",
                "git": "Git",
            }

            missing_tools = []
            for cmd, display_name in required_tools.items():
                if not self.check_command(cmd, display_name):
                    missing_tools.append(display_name)

            if missing_tools:
                logger.error(
                    f"Missing required tools: {', '.join(missing_tools)}. "
                    f"Please install them and try again."
                )

            # Check for PyInstaller if not skipping Python build
            if not self.skip_python:
                try:
                    import PyInstaller  # noqa: F401
                except ImportError:
                    logger.error(
                        "PyInstaller is not installed. Install it with: pip install pyinstaller"
                    )

    def get_version_from_file(self) -> str:
        """Read version from package.json."""
        if not self.version_file.exists():
            logger.error(f"package.json not found at {self.version_file}")

        with open(self.version_file, "r") as f:
            data = json.load(f)
            version = data.get("version")
            if not version:
                logger.error("'version' field not found in package.json")
            return version

    # ========================================================================
    # Build Functions
    # ========================================================================

    def build_lua_scripts(self):
        """Build Lua scripts artifact by concatenating all Lua files."""
        with spinner_context("Building Lua scripts..."):
            try:
                # Define the list of scripts to concatenate (order matters!)
                lua_scripts = [
                    "dcsUnits.lua",
                    "veafCacheManager.lua",
                    "veafEventHandler.lua",
                    "veafMarkers.lua",
                    "veafInterpreter.lua",
                    "veafRadio.lua",
                    "veafRemote.lua",
                    "veafSpawn.lua",
                    "veafSecurity.lua",
                    "veafShortcuts.lua",
                    "veafAirbases.lua",
                    "veafAirWaves.lua",
                    "veafAssets.lua",
                    "veafCarrierOperations.lua",
                    "veafCasMission.lua",
                    "veafCombatMission.lua",
                    "veafCombatZone.lua",
                    "veafGrass.lua",
                    "veafMissileGuardian.lua",
                    "veafMove.lua",
                    "veafNamedPoints.lua",
                    "veafQraManager.lua",
                    "veafSanctuary.lua",
                    "veafSkynetIadsHelper.lua",
                    "veafSkynetIadsMonitor.lua",
                    "veafTime.lua",
                    "veafTransportMission.lua",
                    "veafUnits.lua",
                    "veafGroundAI.lua",
                    "veafWeather.lua",
                ]

                # Step 1: Clean and recreate build directory
                if self.build_dir.exists():
                    shutil.rmtree(self.build_dir)
                self.build_dir.mkdir(exist_ok=True)

                # Step 2: Copy all Lua scripts from src/scripts/veaf to build directory
                src_scripts_dir = self.script_root / "src" / "scripts" / "veaf"
                if not src_scripts_dir.exists():
                    logger.error(f"Source scripts directory not found: {src_scripts_dir}")

                for lua_file in src_scripts_dir.rglob("*.lua"):
                    dest = self.build_dir / lua_file.name
                    shutil.copy2(lua_file, dest)

                # Step 3: Modify veaf.lua based on options
                veaf_lua_path = self.build_dir / "veaf.lua"
                if veaf_lua_path.exists():
                    content = veaf_lua_path.read_text(encoding="utf-8")

                    # Set development version flag
                    dev_flag = "true" if self.development_build else "false"
                    content = re.sub(
                        r"veaf\.Development = (true|false)",
                        f"veaf.Development = {dev_flag}",
                        content,
                    )

                    # Security flag (always disabled in this context)
                    content = re.sub(
                        r"veaf\.SecurityDisabled = (true|false)",
                        "veaf.SecurityDisabled = false",
                        content,
                    )

                    veaf_lua_path.write_text(content, encoding="utf-8")

                # Step 4: Comment out trace/debug logging if not development build
                if not self.development_build:
                    for lua_file in self.build_dir.glob("*.lua"):
                        content = lua_file.read_text(encoding="utf-8")
                        # Comment out trace, debug, marker, and cleanupMarkers calls
                        content = re.sub(
                            r"(^\s*)(.*veaf\.loggers\.get\(.*\):(trace|debug|marker|cleanupMarkers))",
                            r"\1-- LOGGING DISABLED WHEN COMPILING",
                            content,
                            flags=re.MULTILINE,
                        )
                        lua_file.write_text(content, encoding="utf-8")

                # Step 5: Create output file with header and concatenated scripts
                output_filename = "veaf-scripts.lua"
                output_path = self.build_dir / output_filename
                
                # Read package.json for version
                with open(self.version_file, "r") as f:
                    package_data = json.load(f)
                    version = package_data.get("version", self.version)
                
                # Create version marker
                datetime_str = datetime.now().strftime("%Y.%m.%d.%H.%M.%S")
                version_tag = "-dev" if self.development_build else ""
                version_marker = f"{version}{version_tag};{datetime_str}"

                # Write header
                header = (
                    "\n"
                    + "-" * 85 + "\n"
                    + f"-- Veaf scripts {version_marker}\n"
                    + "-" * 85 + "\n"
                    + "\n"
                )

                with open(output_path, "w", encoding="utf-8") as out_file:
                    out_file.write(header)

                    # Add veaf.lua first
                    veaf_path = self.build_dir / "veaf.lua"
                    if veaf_path.exists():
                        out_file.write("\n")
                        out_file.write("--" + "-" * 75 + "\n")
                        out_file.write("-- START script veaf.lua\n")
                        out_file.write("--" + "-" * 75 + "\n")
                        out_file.write("\n")
                        out_file.write(veaf_path.read_text(encoding="utf-8"))
                        out_file.write("\n")
                        out_file.write("--" + "-" * 75 + "\n")
                        out_file.write("-- END script veaf.lua\n")
                        out_file.write("--" + "-" * 75 + "\n")
                        out_file.write("\n")

                    # Add other scripts in order
                    for script_name in lua_scripts:
                        script_path = self.build_dir / script_name
                        if script_path.exists():
                            out_file.write("\n")
                            out_file.write("--" + "-" * 75 + "\n")
                            out_file.write(f"-- START script {script_name}\n")
                            out_file.write("--" + "-" * 75 + "\n")
                            out_file.write("\n")
                            out_file.write(script_path.read_text(encoding="utf-8"))
                            out_file.write("\n")
                            out_file.write("--" + "-" * 75 + "\n")
                            out_file.write(f"-- END script {script_name}\n")
                            out_file.write("--" + "-" * 75 + "\n")
                            out_file.write("\n")

                    # Add footer
                    footer = (
                        "\n"
                        + "\n"
                        + "\n"
                        + "-" * 85 + "\n"
                        + f"-- END OF Veaf scripts {version_marker}\n"
                        + "-" * 85 + "\n"
                        + "\n"
                    )
                    out_file.write(footer)

                logger.debug(f"Scripts main file created: {output_filename}")

            except Exception as e:
                logger.error(f"Lua build failed: {e}")

    def build_python_executables(self):
        """Build Python executables using PyInstaller."""
        # Clean dist directory
        with spinner_context("Preparing build environment..."):
            if self.dist_dir.exists():
                logger.debug("Removing previous dist directory...")
                shutil.rmtree(self.dist_dir)
            self.dist_dir.mkdir(exist_ok=True)

        # Store original file contents for restoration
        original_contents = {}
        
        try:
            # Temporarily inject version into source files
            original_contents = self._inject_version_into_python_files_temporarily()

            # Build veaf-tools executable
            with spinner_context("Building veaf-tools executable..."):
                self._build_pyinstaller_executable(
                    "veaf-tools",
                    self.src_dir / "python" / "veaf-tools" / "veaf-tools.py",
                )

            # Build veaf-tools-updater executable
            with spinner_context("Building veaf-tools-updater executable..."):
                self._build_pyinstaller_executable(
                    "veaf-tools-updater",
                    self.src_dir / "python" / "veaf-tools" / "veaf-tools-updater.py",
                )
        finally:
            # Restore original file contents
            if original_contents:
                self._restore_python_files(original_contents)

    def _build_pyinstaller_executable(self, name: str, entry_point: Path):
        """Build a single PyInstaller executable."""
        if not entry_point.exists():
            logger.error(f"Entry point not found: {entry_point}")

        try:
            cmd = [
                "pyinstaller",
                "--onefile",
                "--name",
                name,
                "--distpath",
                str(self.dist_dir),
                "--specpath",
                str(self.dist_dir / "build"),
                "--workpath",
                str(self.dist_dir / "build"),
                str(entry_point),
            ]

            logger.debug(f"Running PyInstaller: {' '.join(cmd)}")
            
            # Capture all output to log it, but keep console clean with spinner
            result = subprocess.run(
                cmd,
                cwd=str(self.script_root),
                capture_output=True,
                text=True
            )

            # Log PyInstaller output regardless of success
            if result.stdout:
                logger.debug(f"PyInstaller stdout:\n{result.stdout}")
            if result.stderr:
                logger.debug(f"PyInstaller stderr:\n{result.stderr}")

            if result.returncode != 0:
                logger.error(
                    f"PyInstaller build failed for {name} with exit code {result.returncode}"
                )
                raise subprocess.CalledProcessError(result.returncode, cmd, result.stdout, result.stderr)

        except subprocess.CalledProcessError as e:
            logger.error(f"PyInstaller build failed for {name}: {e}")

    def _inject_version_into_python_files_temporarily(self) -> Dict[str, str]:
        """
        Temporarily inject version into Python source files for compilation.
        
        Returns a dict mapping file paths to their original contents so they can
        be restored later (keeping git working tree clean).
        """
        with spinner_context("Injecting version into source files..."):
            original_contents = {}
            try:
                # Python files to inject version into
                python_files = [
                    self.src_dir / "python" / "veaf-tools" / "veaf-tools.py",
                    self.src_dir / "python" / "veaf-tools" / "veaf-tools-updater.py",
                ]

                for file_path in python_files:
                    if not file_path.exists():
                        logger.warning(f"Source file not found: {file_path}")
                        continue

                    # Read and save original content
                    original_content = file_path.read_text(encoding="utf-8")
                    original_contents[str(file_path)] = original_content

                    # Replace VERSION line with the current version
                    # Match patterns like: VERSION: str = "6.0.0" or VERSION:str = "6.0.0"
                    # Capture the exact format so we can restore it later
                    pattern = r'(VERSION\s*:\s*str\s*=\s*)"[^"]+"'
                    match = re.search(pattern, original_content)
                    
                    if match:
                        # Use the exact format from the original file for injection
                        prefix = match.group(1)
                        replacement = f'{prefix}"{self.version}"'
                        new_content = re.sub(pattern, replacement, original_content, count=1)
                        
                        # Write modified content
                        file_path.write_text(new_content, encoding="utf-8")
                        logger.debug(f"Injected version {self.version} into {file_path.name}")
                    else:
                        logger.warning(f"Could not find VERSION pattern in {file_path.name}")
                        # Still save it in case of other patterns
                        original_contents[str(file_path)] = original_content

            except Exception as e:
                logger.error(f"Failed to inject version into Python files: {e}")
                # Restore on error
                for file_path, content in original_contents.items():
                    Path(file_path).write_text(content, encoding="utf-8")
                original_contents.clear()

            return original_contents

    def _restore_python_files(self, original_contents: Dict[str, str]):
        """Restore Python files to their original contents."""
        with spinner_context("Restoring source files..."):
            try:
                for file_path_str, original_content in original_contents.items():
                    file_path = Path(file_path_str)
                    file_path.write_text(original_content, encoding="utf-8")
                    logger.debug(f"Restored {file_path.name} to original state")
            except Exception as e:
                logger.warning(f"Failed to restore source files: {e}")



    # ========================================================================
    # Release Package
    # ========================================================================

    def create_release_package(self) -> Dict[str, any]:
        """Create a release package (ZIP file)."""
        with spinner_context("Creating release package..."):
            # Verify that build artifacts exist
            veaf_scripts_path = self.build_dir / "veaf-scripts.lua"
            if not veaf_scripts_path.exists():
                logger.error("Lua scripts not found. Run build first.")

            output_file = self.output_path / "published.zip"
            output_file.parent.mkdir(parents=True, exist_ok=True)

            try:
                with zipfile.ZipFile(output_file, "w", zipfile.ZIP_DEFLATED) as zf:
                    # Add Lua scripts to src/scripts/veaf directory
                    if veaf_scripts_path.exists():
                        arcname = "src/scripts/veaf/veaf-scripts.lua"
                        zf.write(veaf_scripts_path, arcname)
                        logger.debug(f"Added {arcname} to ZIP")
                    
                    # Add both executables at root level
                    if self.dist_dir.exists():
                        for exe_name in ["veaf-tools.exe", "veaf-tools-updater.exe"]:
                            exe_file = self.dist_dir / exe_name
                            if exe_file.exists():
                                zf.write(exe_file, exe_name)
                                logger.debug(f"Added {exe_name} to ZIP")
                    
                    # Add defaults directory
                    defaults_dir = self.src_dir / "defaults"
                    if defaults_dir.exists():
                        for file_path in defaults_dir.rglob("*"):
                            if file_path.is_file():
                                arcname = file_path.relative_to(self.src_dir.parent)
                                zf.write(file_path, arcname)
                                logger.debug(f"Added {arcname} to ZIP")
                    
                    # Add build-scripts directory
                    build_scripts_dir = self.src_dir / "build-scripts"
                    if build_scripts_dir.exists():
                        for file_path in build_scripts_dir.rglob("*"):
                            if file_path.is_file():
                                arcname = file_path.relative_to(self.src_dir)
                                zf.write(file_path, arcname)
                                logger.debug(f"Added {arcname} to ZIP")
                    
                    # Add community scripts directory to src/scripts/community
                    community_dir = self.src_dir / "scripts" / "community"
                    if community_dir.exists():
                        for file_path in community_dir.rglob("*"):
                            if file_path.is_file():
                                # Preserve relative path structure within community folder
                                rel_path = file_path.relative_to(community_dir)
                                arcname = f"src/scripts/community/{rel_path}"
                                zf.write(file_path, arcname)
                                logger.debug(f"Added {arcname} to ZIP")
                    
                    # Add documentation files
                    doc_files = ["README.md", "package.json"]
                    for doc_file in doc_files:
                        doc_path = Path.cwd() / doc_file
                        if doc_path.exists():
                            zf.write(doc_path, doc_file)
                            logger.debug(f"Added {doc_file} to ZIP")

                logger.debug(f"Release package created: {output_file}")

            except Exception as e:
                logger.error(f"Failed to create release package: {e}")

        # Calculate SHA256
        with spinner_context("Calculating SHA256 checksum..."):
            file_hash = self._calculate_sha256(output_file)
            logger.info(f"SHA256: {file_hash}")

        # Create metadata file with checksum for integrity verification
        metadata = {
            "published_zip_sha256": file_hash,
            "version": self.version,
            "created_at": datetime.now().isoformat(),
        }
        metadata_file = self.output_path / "published-metadata.json"
        try:
            with open(metadata_file, "w", encoding="utf-8") as f:
                json.dump(metadata, f, indent=2)
            logger.debug(f"Metadata file created: {metadata_file}")
        except Exception as e:
            logger.warning(f"Failed to create metadata file: {e}")

        return {
            "path": output_file,
            "hash": file_hash,
            "size": output_file.stat().st_size,
            "version": self.version,
        }

    @staticmethod
    def _calculate_sha256(file_path: Path) -> str:
        """Calculate SHA256 hash of a file."""
        sha256_hash = sha256()
        with open(file_path, "rb") as f:
            for byte_block in iter(lambda: f.read(4096), b""):
                sha256_hash.update(byte_block)
        return sha256_hash.hexdigest()

    # ========================================================================
    # GitHub Publishing
    # ========================================================================

    def _do_publish_to_github(self, package_path: Path, package_hash: str, force: bool = False):
        """Publish release to GitHub using git tags."""
        token = self.github_token or os.getenv("GITHUB_TOKEN")
        if not token:
            logger.warning(
                "GitHub token not provided. Use --token parameter or set GITHUB_TOKEN environment variable",
                no_console=True
            )
            logger.info(
                "Proceeding with git tags only (release assets must be uploaded manually)",
                no_console=True
            )

        try:
            self._publish_with_git_tags(package_path)
            if token:
                self._publish_with_gh_cli(package_path, package_hash, force=force)

        except subprocess.CalledProcessError as e:
            logger.error(f"GitHub publishing failed: {e}")

    def _publish_with_git_tags(self, package_path: Path):
        """Publish using git tags."""
        try:
            tag_name = f"published-v{self.version}"
            latest_tag_name = "published-latest"

            # Delete old tags if they exist
            subprocess.run(
                ["git", "tag", "-d", tag_name],
                cwd=str(self.script_root),
                capture_output=True,
            )
            subprocess.run(
                ["git", "tag", "-d", latest_tag_name],
                cwd=str(self.script_root),
                capture_output=True,
            )

            # Create new tags
            subprocess.run(
                ["git", "tag", tag_name],
                cwd=str(self.script_root),
                capture_output=True,
                check=True,
            )
            subprocess.run(
                ["git", "tag", latest_tag_name],
                cwd=str(self.script_root),
                capture_output=True,
                check=True,
            )

            # Push tags
            subprocess.run(
                ["git", "push", "origin", "-f", tag_name],
                cwd=str(self.script_root),
                capture_output=True,
                check=True,
            )
            subprocess.run(
                ["git", "push", "origin", "-f", latest_tag_name],
                cwd=str(self.script_root),
                capture_output=True,
                check=True,
            )

            logger.debug(f"Git tags created and pushed: {tag_name}, {latest_tag_name}", no_console=True)

        except subprocess.CalledProcessError as e:
            logger.error(f"Git operation failed: {e}")

    def _publish_with_gh_cli(self, package_path: Path, package_hash: str, force: bool = False):
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
            if self.github_token:
                env["GH_TOKEN"] = self.github_token

            # Delete existing release if force is enabled
            if force:
                delete_result = subprocess.run(
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
            release_cmd = ["gh", "release", "create", tag_name, "--latest", "-t", f"VEAF Tools v{self.version}"]
            release_cmd.extend(notes_arg)
            
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

            # Upload release assets in order: updater first, then main zip
            # First upload veaf-tools-updater.exe if it exists
            updater_exe = self.dist_dir / "veaf-tools-updater.exe"
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
                    logger.debug(f"Uploaded veaf-tools-updater.exe to release")
            
            # Then upload the main ZIP
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

            # Upload metadata file for checksum verification
            metadata_file = self.output_path / "published-metadata.json"
            if metadata_file.exists():
                subprocess.run(
                    ["gh", "release", "upload", tag_name, str(metadata_file)],
                    cwd=str(self.script_root),
                    env=env,
                    capture_output=True,
                    text=True,
                )
                logger.debug(f"Uploaded published-metadata.json to release")

            # Delete auto-generated source archives
            for source_asset in ["Source code (zip)", "Source code (tar.gz)"]:
                delete_result = subprocess.run(
                    ["gh", "release", "delete-asset", tag_name, source_asset, "--yes"],
                    cwd=str(self.script_root),
                    env=env,
                    capture_output=True,
                    text=True,
                )
                if delete_result.returncode == 0:
                    logger.debug(f"Deleted auto-generated {source_asset}")
                # Ignore errors if asset doesn't exist

            logger.debug(f"GitHub release created and assets uploaded for {tag_name}", no_console=True)

            # Create or update the "latest" release pointing to the same assets
            # Delete old latest release if it exists
            delete_latest_result = subprocess.run(
                ["gh", "release", "delete", latest_tag_name, "--yes"],
                cwd=str(self.script_root),
                env=env,
                capture_output=True,
                text=True,
            )
            # Ignore errors if release doesn't exist

            # Create new latest release
            latest_release_cmd = ["gh", "release", "create", latest_tag_name, "--latest", "-t", f"VEAF Tools Latest (v{self.version})"]
            latest_release_cmd.extend(notes_arg)
            
            result = subprocess.run(
                latest_release_cmd,
                cwd=str(self.script_root),
                env=env,
                capture_output=True,
                text=True,
            )
            if result.returncode != 0:
                logger.warning(f"GitHub latest release creation failed: {result.stderr}")
            else:
                # Upload assets to latest release
                if updater_exe.exists():
                    subprocess.run(
                        ["gh", "release", "upload", latest_tag_name, str(updater_exe)],
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

                # Upload metadata file for checksum verification
                metadata_file = self.output_path / "published-metadata.json"
                if metadata_file.exists():
                    subprocess.run(
                        ["gh", "release", "upload", latest_tag_name, str(metadata_file)],
                        cwd=str(self.script_root),
                        env=env,
                        capture_output=True,
                        text=True,
                    )
                    logger.debug(f"Uploaded published-metadata.json to latest release")
                
                logger.debug(f"GitHub latest release created and assets uploaded for {latest_tag_name}", no_console=True)

        except Exception as e:
            logger.error(f"GitHub CLI operation failed: {e}")

    def prepare_release_notes(self) -> Path:
        """
        Prepare release notes for publishing.
        
        If RELEASE_NOTES.md exists, ask the user whether to use it or overwrite with template.
        If it doesn't exist, create it from template.
        
        Returns:
            Path to the release notes file
        """
        release_notes_path = self.script_root / "RELEASE_NOTES.md"
        
        if release_notes_path.exists():
            # File exists, ask user what to do
            console.print(f"\n[bold yellow]RELEASE_NOTES.md already exists[/bold yellow]")
            console.print(f"Location: {release_notes_path}")
            
            response = typer.confirm(
                "Do you want to overwrite it with a fresh template?",
                default=False
            )
            
            if response:
                # Overwrite with template
                self._create_release_notes_template(release_notes_path)
                console.print("[bold green]✓[/bold green] New release notes template created")
            else:
                console.print("[bold green]✓[/bold green] Using existing release notes")
        else:
            # File doesn't exist, create from template
            self._create_release_notes_template(release_notes_path)
            console.print("[bold green]✓[/bold green] Release notes template created")
        
        return release_notes_path

    def _create_release_notes_template(self, release_notes_path: Path):
        """Create release notes template file."""
        template = f"""# VEAF Tools Release v{self.version}

**Release Date:** {datetime.now().strftime('%Y-%m-%d')}

## What's New

[Edit this section with actual features and changes]

## Bug Fixes

[Edit this section with bug fixes]

## Breaking Changes

[Edit this section if there are any breaking changes, or write "None" if not applicable]

## Installation

### Quick Start

The easiest way to get started:

1. **Download `veaf-tools-updater.exe`** from this release
2. **Run it** - it will automatically download and install everything else:
   ```bash
   veaf-tools-updater.exe
   ```

That's it! The updater will:
- Create the necessary directories
- Download and extract the VEAF tools to your mission folder
- Set up your configuration

### Manual Installation

If you prefer to install manually:

1. Download `published.zip` from this release
2. Extract it to your VEAF mission folder
3. Run `veaf-tools.exe` to start using the tools

### Updating Existing Installation

If you already have VEAF tools installed:

```bash
veaf-tools-updater.exe update
```

This will download and install the latest version.

---

## Installation 🇫🇷

### Démarrage Rapide

Le moyen le plus simple de commencer :

1. **Téléchargez `veaf-tools-updater.exe`** depuis cette release
2. **Exécutez-le** - il téléchargera et installera automatiquement tout le reste :
   ```bash
   veaf-tools-updater.exe
   ```

C'est tout ! L'updater va :
- Créer les répertoires nécessaires
- Télécharger et extraire les outils VEAF dans votre dossier de mission
- Configurer votre environnement

### Installation Manuelle

Si vous préférez installer manuellement :

1. Téléchargez `published.zip` depuis cette release
2. Extrayez-le dans votre dossier VEAF mission
3. Exécutez `veaf-tools.exe` pour commencer à utiliser les outils

### Mise à Jour d'une Installation Existante

Si vous avez déjà VEAF tools installé :

```bash
veaf-tools-updater.exe update
```

Cela téléchargera et installera la dernière version.

---

## Changelog

See git history for detailed changes.

---
**Generated by build-and-release.py**
"""

        release_notes_path.write_text(template, encoding="utf-8")
        logger.debug(f"Release notes template created: {release_notes_path}")

    # ========================================================================
    # Main Process
    # ========================================================================

    def run(self):
        """Execute the build and release process."""
        # Get version if not provided
        if not self.version:
            self.version = self.get_version_from_file()
            logger.info(f"Version not specified, using from package.json: {self.version}")

        # Print configuration
        table = Table(title="Build Configuration")
        table.add_column("Setting", style="cyan")
        table.add_column("Value", style="magenta")
        table.add_row("Release Version", self.version)
        table.add_row("Development Build", str(self.development_build))
        table.add_row("Skip Lua Build", str(self.skip_lua))
        table.add_row("Skip Python Build", str(self.skip_python))
        table.add_row("Publish to GitHub", str(self.publish_to_github))
        console.print(table)

        try:
            # Validate prerequisites
            self.validate_prerequisites()

            # Build Lua scripts
            if not self.skip_lua:
                self.build_lua_scripts()
            else:
                logger.warning("Skipping Lua build")

            # Build Python executables
            if not self.skip_python:
                self.build_python_executables()
            else:
                logger.warning("Skipping Python build")

            # Create release package
            package_info = self.create_release_package()

            # Publish to GitHub if requested
            if self.publish_to_github:
                self._do_publish_to_github(package_info["path"], package_info["hash"])

            # Print summary
            self._print_summary(package_info)

        except Exception as e:
            logger.error(str(e))
            sys.exit(1)

    def _print_summary(self, package_info: Dict):
        """Print build summary."""
        console.print("\n[bold green]Build and release process completed![/bold green]")

        summary_table = Table(title="Deliverables")
        summary_table.add_column("Item", style="cyan")
        summary_table.add_column("Path/Value", style="magenta")
        summary_table.add_row("Release Package", str(package_info["path"]))
        summary_table.add_row("Release Notes", str(self.script_root / "RELEASE_NOTES.md"))
        summary_table.add_row("SHA256", package_info["hash"])
        summary_table.add_row("Size", f"{package_info['size'] / (1024*1024):.2f} MB")
        console.print(summary_table)

        console.print("\n[bold cyan]Next Steps:[/bold cyan]")
        console.print("  1. Review release notes in RELEASE_NOTES.md")
        console.print("  2. Edit release notes with actual changes")
        if self.publish_to_github:
            console.print(f"  3. Use GitHub CLI to create release (already done via gh CLI)")
        else:
            console.print("  3. To publish to GitHub, run with --publish flag")


# ============================================================================
# Typer Commands
# ============================================================================


@app.callback(invoke_without_command=True)
def callback(ctx: typer.Context) -> None:
    """VEAF Tools Build and Release Script"""
    # If no command is invoked, execute build_and_publish as default
    if ctx.invoked_subcommand is None:
        # Execute build_and_publish with default arguments
        _execute_build_and_publish()


def _execute_build_and_publish(
    version: Optional[str] = None,
    token: Optional[str] = None,
    skip_lua: bool = False,
    skip_python: bool = False,
    dev: bool = False,
    output: str = ".",
    verbose: bool = False,
) -> None:
    """Internal function to execute build and publish"""
    logger.set_verbose(verbose)
    console.print("[bold green]VEAF Tools Build & Publish[/bold green]")

    config = load_config()

    if not version:
        version_file = Path("package.json")
        if version_file.exists():
            with open(version_file, "r") as f:
                version = json.load(f).get("version")
        else:
            logger.error("Version not specified and package.json not found")
            sys.exit(1)

    # Determine GitHub token with fallback: CLI arg > config file > env var
    github_config = config.get("github", {})
    effective_token = token or github_config.get("token") or os.getenv("GITHUB_TOKEN")

    if not effective_token:
        logger.error("GitHub token not provided. Use --token, set GITHUB_TOKEN env var, or add to veaf-tools-config.yaml")
        sys.exit(1)

    try:
        # Step 1: Build
        console.print("\n[bold cyan]Step 1: Building...[/bold cyan]")
        worker = BuildAndReleaseWorker(
            version=version,
            skip_lua=skip_lua,
            skip_python=skip_python,
            development_build=dev,
            output_path=Path(output),
            verbose=verbose,
            config=config,
        )
        worker.run()

        # Step 2: Prepare release notes
        console.print("\n[bold cyan]Step 2: Preparing release notes...[/bold cyan]")
        release_notes_path = worker.prepare_release_notes()

        # Step 3: Pause for editing release notes
        console.print("\n[bold yellow]⏸️  Pause: Edit RELEASE_NOTES.md and press Enter to continue publishing...[/bold yellow]")
        console.print(f"File location: {release_notes_path.resolve()}")
        input(PAUSE_MESSAGE)

        # Step 4: Publish
        console.print("\n[bold cyan]Step 3: Publishing to GitHub...[/bold cyan]")
        
        # Verify that published.zip exists
        published_zip = Path("published.zip")
        if not published_zip.exists():
            logger.error(f"Release package not found at {published_zip}")
            sys.exit(1)

        # Calculate SHA256
        with spinner_context("Calculating SHA256..."):
            with open(published_zip, "rb") as f:
                package_hash = sha256(f.read()).hexdigest()

        # Publish to GitHub
        with spinner_context("Publishing to GitHub..."):
            publish_worker = BuildAndReleaseWorker(
                version=version,
                github_token=effective_token,
                verbose=verbose,
                config=config,
            )
            publish_worker._do_publish_to_github(published_zip, package_hash, force=False)

        # Display release information
        release_url = f"https://github.com/{publish_worker.github_owner}/{publish_worker.github_repo}/releases/tag/published-v{version}"

        from rich.table import Table
        table = Table(title=f"[bold green]Release v{version} Published[/bold green]")
        table.add_column("Property", style="cyan")
        table.add_column("Value", style="green")
        table.add_row("Version", f"v{version}")
        table.add_row("Package", published_zip.name)
        table.add_row("SHA256", package_hash[:16] + "...")
        table.add_row("Size", f"{published_zip.stat().st_size / (1024*1024):.1f} MB")
        table.add_row("URL", release_url)
        console.print("")
        console.print(table)
        console.print("")

    except Exception as e:
        logger.error(f"Build and publish failed: {e}")
        sys.exit(1)


@app.command()
def build_and_publish(
    version: Optional[str] = typer.Option(
        None,
        help="Semantic version for the release (e.g., '6.0.2'). If not specified, reads from package.json",
    ),
    token: Optional[str] = typer.Option(
        None,
        help="GitHub Personal Access Token with 'repo' scope (or use GITHUB_TOKEN env var)",
    ),
    skip_lua: bool = typer.Option(False, help="Skip Lua script build"),
    skip_python: bool = typer.Option(False, help="Skip Python executable build"),
    dev: bool = typer.Option(False, "--dev", help="Build in development mode"),
    output: str = typer.Option(
        ".", help="Output directory for release package"
    ),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
) -> None:
    """
    Build VEAF Tools and publish to GitHub (default command).
    
    This command builds everything and then pauses to let you edit RELEASE_NOTES.md
    before publishing to GitHub.
    """
    _execute_build_and_publish(
        version=version,
        token=token,
        skip_lua=skip_lua,
        skip_python=skip_python,
        dev=dev,
        output=output,
        verbose=verbose,
    )


@app.command()
def build(
    version: Optional[str] = typer.Option(
        None,
        help="Semantic version for the release (e.g., '6.0.2'). If not specified, reads from package.json",
    ),
    skip_lua: bool = typer.Option(False, help="Skip Lua script build"),
    skip_python: bool = typer.Option(False, help="Skip Python executable build"),
    dev: bool = typer.Option(False, "--dev", help="Build in development mode"),
    output: str = typer.Option(
        ".", help="Output directory for release package"
    ),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    pause: bool = typer.Option(False, help="Pause when finished"),
) -> None:
    """
    Build VEAF Tools without publishing to GitHub.
    """
    logger.set_verbose(verbose)
    console.print("[bold green]VEAF Tools Build[/bold green]")
    config = load_config()

    worker = BuildAndReleaseWorker(
        version=version,
        skip_lua=skip_lua,
        skip_python=skip_python,
        development_build=dev,
        output_path=Path(output),
        verbose=verbose,
        config=config,
    )
    worker.run()

    if pause:
        input(PAUSE_MESSAGE)


@app.command()
def publish(
    version: Optional[str] = typer.Option(
        None,
        help="Semantic version for the release (e.g., '6.0.2'). If not specified, reads from package.json",
    ),
    token: Optional[str] = typer.Option(
        None,
        help="GitHub Personal Access Token with 'repo' scope (or use GITHUB_TOKEN env var)",
    ),
    force: bool = typer.Option(
        False,
        help="Force publish even if release already exists (overwrites with --clobber)",
    ),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    pause: bool = typer.Option(False, help="Pause when finished"),
) -> None:
    """
    Publish existing release to GitHub (without recompiling).
    
    Use this after running 'build' and editing RELEASE_NOTES.md.
    It will publish the already-compiled artifacts to GitHub.
    """
    logger.set_verbose(verbose)
    console.print("[bold green]VEAF Tools Publish[/bold green]")
    config = load_config()

    if not version:
        # Read version from package.json
        version_file = Path("package.json")
        if version_file.exists():
            with open(version_file, "r") as f:
                version = json.load(f).get("version")
        else:
            logger.error("Version not specified and package.json not found")
            sys.exit(1)
    
    # Determine GitHub token with fallback: CLI arg > config file > env var
    github_config = config.get("github", {})
    effective_token = token or github_config.get("token") or os.getenv("GITHUB_TOKEN")
    
    if not effective_token:
        logger.error("GitHub token not provided. Use --token, set GITHUB_TOKEN env var, or add to veaf-tools-config.yaml")
        sys.exit(1)
    
    # Verify that published.zip exists
    published_zip = Path("published.zip")
    if not published_zip.exists():
        logger.error(f"Release package not found at {published_zip}. Run 'build' first.")
        sys.exit(1)
    
    # Prepare release notes (create or ask about overwriting)
    console.print("\n[bold cyan]Preparing release notes...[/bold cyan]")
    with spinner_context("Loading release notes handler..."):
        worker = BuildAndReleaseWorker(
            version=version,
            verbose=verbose,
            config=config,
        )
    
    release_notes_path = worker.prepare_release_notes()
    
    # Pause for editing release notes
    console.print("\n[bold yellow]⏸️  Pause: Edit RELEASE_NOTES.md and press Enter to continue publishing...[/bold yellow]")
    console.print(f"File location: {release_notes_path.resolve()}")
    input(PAUSE_MESSAGE)
    
    try:
        # Calculate SHA256
        with spinner_context("Calculating SHA256..."):
            with open(published_zip, "rb") as f:
                package_hash = sha256(f.read()).hexdigest()
        
        # Publish to GitHub
        with spinner_context("Publishing to GitHub..."):
            worker = BuildAndReleaseWorker(
                version=version,
                github_token=effective_token,
                verbose=verbose,
                config=config,
            )
            worker._do_publish_to_github(published_zip, package_hash, force=force)
        
        # Display release information
        release_url = f"https://github.com/{worker.github_owner}/{worker.github_repo}/releases/tag/published-v{version}"
        
        from rich.table import Table
        table = Table(title=f"[bold green]Release v{version} Published[/bold green]")
        table.add_column("Property", style="cyan")
        table.add_column("Value", style="green")
        table.add_row("Version", f"v{version}")
        table.add_row("Package", published_zip.name)
        table.add_row("SHA256", package_hash[:16] + "...")
        table.add_row("Size", f"{published_zip.stat().st_size / (1024*1024):.1f} MB")
        table.add_row("URL", release_url)
        console.print("")
        console.print(table)
        console.print("")
        
    except Exception as e:
        logger.error(f"Publishing failed: {e}")
        sys.exit(1)

    if pause:
        input(PAUSE_MESSAGE)


@app.command()
def about() -> None:
    """
    Shows information about the VEAF Tools build system
    """
    url = "https://www.veaf.org"
    console.print(__doc__)
    console.print("[bold green]The VEAF - Virtual European Air Force[/bold green]")
    console.print(
        "The VEAF is a community of virtual pilots dedicated to creating and flying high-quality missions in DCS World."
    )
    console.print(f"Website: {url}", style="blue")
    if typer.confirm("Do you want to open the VEAF website in your browser?"):
        typer.launch(url)


def main():
    """Main entry point."""
    app()


if __name__ == "__main__":
    main()
