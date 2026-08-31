"""Entry script PyInstaller reads to build ``veaf-tools.exe`` (``veaf_build/worker.py``).

It delegates to :func:`veaf_tools.app.main`, the same function the ``veaf-tools`` console
script calls, and holds no CLI logic of its own **on purpose**. It used to be a copy of
``main()`` — the ``--lang`` pre-parse, the command registration, the TUI bridge, the exit
pause — and the copy silently fell behind: ``main()`` gained ``build_cli_tree(app)`` and this
file did not, so the themed tree that ``doc/CLI_REFERENCE`` documents existed only for
developers running from a checkout, never in the executable every mission maker actually has
(FIX-EXE-COMMAND-TREE). One implementation cannot diverge from itself.

PyInstaller finds modules by reading ``import`` statements, and it reads the ones inside
function bodies too — the imports ``main()`` performs are followed from here just as they were
when they sat in this file. The ``exe-smoke`` CI job builds this and runs the tree, which is
what actually proves it.
"""

from veaf_libs.i18n import set_language_from_argv

# Before importing anything that translates: `help=` strings are `t()` calls evaluated at
# import time and Typer's `--help` is eager, so `--lang` has to be applied first. `main()`
# applies it again, harmlessly — but by then `veaf_tools.app` has already been imported.
set_language_from_argv()

from veaf_tools.app import main  # noqa: E402  — must follow the language setup above

if __name__ == "__main__":
    main()
