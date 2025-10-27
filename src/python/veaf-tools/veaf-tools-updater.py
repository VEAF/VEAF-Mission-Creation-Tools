"""
This program provides a command-line interface (CLI) for updating the veaf-tools program and the scripts.

Features:
- Provides a CLI interface.
- Logs the details of the operation in the 'veaf-tools-updater.log' file.

Usage:
- Run the script with 'veaf-tools-updater.exe' to access the CLI.
"""

from io import BytesIO
import json
from pathlib import Path
import re
import shutil
import zipfile
from rich.markdown import Markdown
from typing import Optional

from veaf_logger import logger, console
from mission_tools import spinner_context
import typer
import requests

VERSION:str = "6.0.1"
README_HELP: str = "Provide access to the README file."
PAUSE_HELP: str = "If set, the script will pause when finished and wait for the user to press a key."
VERBOSE_HELP: str = "If set, the script will output a lot of debug information."

# String constants
DEFAULT_MISSION_FILE = "mission.miz"
DEFAULT_PRESETS_FILE = "./src/presets.yaml"
CONFIRM_DISPLAY_DOC = "Do you want to display the documentation?"
WORK_DONE_MESSAGE = "[bold blue]Work done![/bold blue]"

app = typer.Typer(no_args_is_help=True)

def resolve_path(path: str, default_path: str = None, should_exist: bool = False, create_if_not_exist: bool = False) -> Path:
    
    """Resolve and validate a file path."""
    if not path and default_path:
        result = Path(default_path)
    elif path:
        result = Path(path)
    else:
        logger.error(message="Either path or default_path must be provided", exception_type=ValueError)
    
    result = result.resolve()
    
    if create_if_not_exist and not result.exists():
        result.parent.mkdir(parents=True, exist_ok=True)
        if not result.suffix:  # It's a directory
            result.mkdir(exist_ok=True)
    
    if should_exist and not result.exists():
        logger.error(f"Path does not exist: {result}")
        exit(-1)
    
    return result

@app.command(no_args_is_help=True)
def about(
) -> None:
    """
    Shows information about the veaf-tools program
    """
    url = "https://www.veaf.org"
    console.print(__doc__)
    console.print("[bold green]The VEAF - Virtual European Air Force[/bold green]")
    console.print("The VEAF is a community of virtual pilots dedicated to creating and flying high-quality missions in DCS World.")
    console.print(f"Website: {url}", style="blue")
    if typer.confirm("Do you want to open the VEAF website in your browser?"):
        typer.launch(url)

@app.command()
def update(
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
    force: bool = typer.Option(False, help="If set, no check will be done and the files will be downloaded from GitHub"),
    tag: Optional[str] = typer.Option("latest", help="Tag that will be used to fetch files from GitHub"),
    token: Optional[str] = typer.Option(None, help="GitHub Personal Access Token - optional, may help with rate limiting"),
    mission_folder: Optional[str] = typer.Argument(".", help="Folder with the mission files."),
    pause: bool = typer.Option(False, help=PAUSE_HELP),
    confirm: bool = typer.Option(True, help="If set, the script will ask for confirmation before updating if a new version is found."),
) -> None:
    """
    Gets the latest VEAF Tools files from GitHub.
    """

    def check_github_response(response: requests.Response, action: str):
        if response.status_code == 403 and response.reason == "rate limit exceeded":
            logger.warning("\nGitHub API has reached its rate limit. You should wait for a moment (suggesting an hour) and retry...")
            logger.error(f'{action} failed: {response.reason} ({response.status_code})')
        elif response.status_code != 200:
            logger.error(f'\n{action} failed: {response.reason} ({response.status_code})')    
    
    def get_releases(tag: str):
        response = requests.get(f"https://api.github.com/repos/VEAF/VEAF-Mission-Creation-Tools/releases/tags/{tag}", headers=headers)
        if response.status_code == 404: # tag does not exist
            tag = "latest"
            response = requests.get("https://api.github.com/repos/VEAF/VEAF-Mission-Creation-Tools/releases/latest", headers=headers)
        check_github_response(response=response, action=f"Getting release '{tag}' from Github")
        return response.json()
    
    def check_last_release(release_payload) -> tuple[bool, str, str]:
        release_tag = release_payload.get("tag_name")
        release_version = re.sub('^v', '', release_tag)
        update = True
        installed_version = None
        if not force:
            package_json_path = p_mission_folder / "published" / "package.json"
            if package_json_path.exists():
                # Read the installed package.json file
                with open(package_json_path, 'r') as f:
                    package_payload = json.load(f)
                    if installed_version := package_payload.get("version"):
                        if installed_version >= release_version:
                            update = False
        return (update, installed_version, release_version)
    
    def install_update(tag: str, release_version: str):
        with spinner_context(f"Downloading release tag:'{tag}' version:{release_version} from Github"):
            if published_file_urls := [
                e.get("url")
                for e in release_payload.get("assets", [])
                if e.get("name") == "published.zip"
            ]:
                published_file_url = published_file_urls[0]
                response = requests.get(published_file_url, headers=headers)
                check_github_response(response=response, action=f"Getting detailed info about release tag:'{tag}' version:{release_version} from Github")
                published_file_payload = response.json()
                if published_file_download_url := published_file_payload.get("browser_download_url"):
                    response = requests.get(published_file_download_url, headers=headers)
                    check_github_response(response=response, action=f"Downloading 'published.zip' from release {tag} from Github")
                    zip_file = zipfile.ZipFile(BytesIO(response.content))
                    zip_file.extractall(p_mission_folder)
                    published_veaftools_exe_path = p_mission_folder / "published" / "veaf-tools.exe"
                    shutil.copy2(published_veaftools_exe_path, Path.cwd())
                    published_build_scripts_path = p_mission_folder / "published" / "build-scripts"
                    for file in published_build_scripts_path.glob("*.cmd"):
                        shutil.copy2(file, Path.cwd() / file.name)
        logger.info(f"Release tag:'{tag}' version:{release_version} has been downloaded from Github")
        logger.info(f"Extracted release tag:'{tag}' version:{release_version} to {p_mission_folder}")

    logger.set_verbose(verbose)

    # Set the title and version
    console.print(f"[bold green]veaf-tools updater v{VERSION}[/bold green]")

    # Resolve output mission folder
    p_mission_folder = resolve_path(path=mission_folder, default_path=Path.cwd(), should_exist=True)
    if not p_mission_folder.exists():
        logger.error(f"Mission folder {p_mission_folder} does not exist!", exception_type=FileNotFoundError)

    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json"
    } if token else None

    with spinner_context(f"Getting release '{tag}' from Github"):
        release_payload = get_releases(tag)
    
    with spinner_context(f"Checking release '{tag}' from Github"):
        update, installed_version, release_version = check_last_release(release_payload)

    if update:
        if confirm:
            if typer.confirm(f"Do you want to update your folder to version:{release_version}?"):
                install_update(tag, release_version)
    else:
        logger.info(f"No need to update, release version:{release_version} is not newer than installed version:{installed_version}!")

    console.print(WORK_DONE_MESSAGE)
    if pause: input("Press Enter to exit...")

if __name__ == "__main__":
    app()