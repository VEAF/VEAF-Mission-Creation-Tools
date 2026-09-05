"""Makes ``python -m veaf_support_bot`` the same entry point as the ``veaf-support-bot`` script."""

from __future__ import annotations

import sys

from veaf_support_bot.cli import main

if __name__ == "__main__":
    sys.exit(main())
