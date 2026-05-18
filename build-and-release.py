#!/usr/bin/env python3
"""
Backward-compatibility shim.

Prefer using the Poetry-managed entry point instead:

    poetry run veaf-build build --version 6.0.2
    poetry run veaf-build publish --version 6.0.2
    poetry run veaf-build --help
"""

import sys
from pathlib import Path

# Ensure veaf_build package is importable from the project root
sys.path.insert(0, str(Path(__file__).parent))

from veaf_build import main

if __name__ == "__main__":
    main()
