"""``ask`` command — query the VEAF documentation chatbot from the CLI (CHATBOT-CLI)."""

import typer
from doc_chatbot import WorkerChatWorker
from rich.live import Live
from rich.markdown import Markdown
from veaf_libs.i18n import current_language

from veaf_tools.app import VERBOSE_HELP, app, console, logger, t

#: Cap the in-memory REPL history (the Worker only uses the most recent turns).
_MAX_KEPT_TURNS = 24


def _stream_answer(worker: WorkerChatWorker, question: str, history: list[dict[str, str]]) -> str:
    """Stream one answer to the console as it arrives and return the full text.

    Args:
        worker: The configured chat client.
        question: The user's question.
        history: Prior turns (read-only here; the caller updates it).

    Returns:
        The complete answer text (rendered as Markdown, live, as it arrives).
    """
    # Spin until the worker call AND the first chunk arrive, so any latency (network,
    # auth, …) is covered by the same "thinking" indicator; then live-render the
    # Markdown so the answer appears as it streams in (a cut stream is visible, not silent).
    with console.status(t("ask.thinking"), spinner="dots"):
        stream = worker.ask(question, history)
        first = next(stream, None)
    if first is None:
        console.print(Markdown(t("ask.empty_answer")))
        return ""
    parts: list[str] = [first]
    with Live(Markdown(first), console=console, refresh_per_second=12, vertical_overflow="visible") as live:
        for chunk in stream:
            parts.append(chunk)
            live.update(Markdown("".join(parts)))
    answer = "".join(parts).strip()
    if not answer:
        # Stream yielded only blank chunks → keep the explicit empty-answer notice.
        console.print(Markdown(t("ask.empty_answer")))
    return answer


@app.command(no_args_is_help=False, help=t("cmd.ask.help"))
def ask(
    question: list[str] = typer.Argument(None, help=t("cmd.ask.opt.question")),
    verbose: bool = typer.Option(False, help=VERBOSE_HELP),
) -> None:
    """Ask the documentation a question (one-shot) or start an interactive session."""
    logger.set_verbose(verbose)
    worker = WorkerChatWorker(lang=current_language())
    history: list[dict[str, str]] = []

    def _answer(text: str) -> None:
        answer = _stream_answer(worker, text, history)
        history.append({"role": "user", "content": text})
        history.append({"role": "assistant", "content": answer})
        # Cap the in-memory history in long REPL sessions (the Worker only sends the tail anyway).
        del history[:-_MAX_KEPT_TURNS]

    one_shot = " ".join(question).strip() if question else ""
    if one_shot:
        try:
            _answer(one_shot)
        except RuntimeError as exc:
            console.print(str(exc), style="red")
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
        except Exception as exc:
            # Only RuntimeError used to be caught, so anything else -- a JSON decode error, a
            # connection reset -- ended the whole session on one bad question (SECREV-2 / VMR-064).
            # A REPL's job is to survive its inputs. The type is named so a real bug stays visible
            # rather than reading like a service hiccup.
            label = str(exc) if isinstance(exc, RuntimeError) else f"{type(exc).__name__}: {exc}"
            console.print(label, style="red")
