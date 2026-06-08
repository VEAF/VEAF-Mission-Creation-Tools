"""
Thin wrapper — delegates to veaf_build.radio_specs_updater.

Prefer using the Poetry script instead:
    poetry run update-radio-specs
"""

from veaf_build.radio_specs_updater import main

if __name__ == "__main__":
    main()
