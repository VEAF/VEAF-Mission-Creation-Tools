"""VEAF Tools build and release system."""

import sys
from pathlib import Path

# Add veaf-tools Python source to sys.path so veaf_libs can be imported.
# This must happen before any veaf_libs imports in submodules.
_PROJECT_ROOT = Path(__file__).parent.parent.resolve()
sys.path.insert(0, str(_PROJECT_ROOT / "src" / "python" / "veaf-tools"))

from veaf_build.cli import app, main  # noqa: E402 (must come after sys.path setup)

__all__ = ["app", "main"]
