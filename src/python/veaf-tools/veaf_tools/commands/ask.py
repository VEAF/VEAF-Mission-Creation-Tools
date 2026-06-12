"""``ask`` command — query the VEAF documentation chatbot from the CLI (CHATBOT-CLI-004)."""

import typer
from doc_chatbot import DocChatWorker, MissingApiKeyError
from rich.markdown import Markdown
from veaf_libs.i18n import current_language

from veaf_tools.app import VERBOSE_HELP, app, console, logger, t

#: Cap the in-memory REPL history (the worker only sends the most recent turns).
_MAX_KEPT_TURNS = 24


def _stream_answer(worker: DocChatWorker, question: str, history: list[dict[str, str]]) -> str:
    """Stream one answer to the console as it arrives and return the full text.

    Args:
        worker: The configured chat worker.
        question: The user's question.
        history: Prior turns (read-only here; the caller updates it).

    Returns:
        The complete answer text (also rendered as Markdown once finished).
    """
    parts: list[str] = []
    with console.status(t("ask.thinking"), spinner="dots"):
        stream = worker.ask(question, history)
        first = next(stream, None)
    if first is not None:
        parts.append(first)
        for chunk in stream:
            parts.append(chunk)
    answer = "".join(parts).strip()
    console.print(Markdown(answer or t("ask.empty_answer")))
    return answer


@app.command(no_args_is_help=False, help=t("cmd.ask.help"))
def ask(
    question: list[str] = typer.Argument(None, help=t("cmd.ask.opt.question")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
) -> None:
    """Ask the documentation a question (one-shot) or start an interactive session."""
    logger.set_verbose(verbose)
    try:
        worker = DocChatWorker(lang=current_language())
    except MissingApiKeyError as exc:
        console.print(str(exc), style="red")
        raise typer.Exit(code=1) from exc

    history: list[dict[str, str]] = []

    def _answer(text: str) -> None:
        answer = _stream_answer(worker, text, history)
        history.append({"role": "user", "content": text})
        history.append({"role": "assistant", "content": answer})
        # Cap the in-memory history in long REPL sessions (the worker only sends the tail anyway).
        del history[:-_MAX_KEPT_TURNS]

    def _print_error(exc: Exception) -> None:
        # RuntimeError already carries a localized Gemini message; an OSError means
        # the index could not be downloaded and no cache exists.
        console.print(str(exc) if isinstance(exc, RuntimeError) else t("ask.index_unavailable"), style="red")

    one_shot = " ".join(question).strip() if question else ""
    if one_shot:
        try:
            _answer(one_shot)
        except (RuntimeError, OSError) as exc:
            _print_error(exc)
            raise typer.Exit(code=1) from exc
        return

    # Interactive REPL.
    console.print(t("ask.repl_intro"))
    while True:
        try:
            line = console.input(t("ask.prompt")).strip()
        except (EOFError, KeyboardInterrupt):
            console.print()
            break
        if not line:
            continue
        if line.lower() in {"quit", "exit", "q"}:
            break
        try:
            _answer(line)
        except (RuntimeError, OSError) as exc:
            _print_error(exc)
