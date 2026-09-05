"""Downloading what a reporter attached, and turning it into something publishable.

The reports worth having come with files. Issue #215 carried a ``dcs.log``, two ``~mis*.zip`` and
the whole mission — which is what made it reproducible. But those files cannot be published as they
arrive:

* a real ``dcs.log`` was measured at **11.1 MB** on David's machine, which is neither readable nor
  attachable as prose;
* a ``.miz`` is a binary archive that can carry a mission password and a squadron's briefing;
* every one of them carries ``C:\\Users\\Firstname Lastname\\…``;
* and a Discord attachment URL is **signed and expires**, so a report that merely linked them would
  be worthless within days. What survives is what gets re-uploaded to the issue itself.

## What this module does, in order

1. **Download**, under a per-file ceiling, a whole-report ceiling and a suffix allow-list. The size
   is checked against ``Content-Length`` *and* enforced while reading, because a header is a claim.
2. **Classify** by suffix into log, mission, or plain text.
3. **Reduce**: a log becomes a bounded excerpt through the shared builder, a mission becomes the
   explicitly chosen field set. The original still travels — reduction is for the issue body, not a
   substitute for the evidence.
4. **Redact** every text artefact through the tools' single helper — the quoted body of a text
   file, the member names of an archive, and the reporter's own filename. A ``.miz`` is not redacted, it
   is *summarised*: its published fields are chosen, which is the stronger guarantee, and the
   archive itself is only attached when the reporter's own summary shows nothing to withhold.
5. **Hand back** :class:`Prepared` items for ticket 05 to upload, and :class:`Rejected` ones for the
   report to list.

## Nothing here can abort a report

Oversized, unknown, unreachable, corrupt: each becomes a :class:`Rejected` with a reason the user
reads, and the flow continues. An issue missing one attachment is a smaller loss than a report that
never got filed because a file was 30 MB.
"""

from __future__ import annotations

import zipfile
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from pathlib import Path, PurePosixPath

from veaf_support_bot.checkout import Checkout
from veaf_support_bot.logging_setup import get_logger
from veaf_support_bot.toolkit import ToolkitUnavailable, digest_log, redact, summarise_mission

#: Largest single attachment downloaded, in bytes. Above it the file is refused with its size named,
#: so the reporter can decide what to do rather than wonder why it vanished.
DEFAULT_MAX_FILE_BYTES = 25 * 1024 * 1024

#: Largest total across one report. A ceiling per file alone lets twenty files past it.
DEFAULT_MAX_TOTAL_BYTES = 60 * 1024 * 1024

#: Suffixes accepted, and what each one is treated as. Anything else is refused by name: an
#: allow-list is the only way an intake desk stays predictable, and a report needing something else
#: is a conversation with a maintainer, not a silent download.
ACCEPTED_SUFFIXES: dict[str, str] = {
    ".log": "log",
    ".txt": "text",
    ".miz": "mission",
    ".yaml": "text",
    ".yml": "text",
    ".json": "text",
    ".lua": "text",
    ".md": "text",
    ".zip": "archive",
}

#: Kinds whose content is published as text in the issue body.
TEXT_KINDS = frozenset({"text"})

#: Longest text attachment quoted in the body. Beyond it the file is attached and not quoted.
MAX_QUOTED_TEXT_CHARS = 4000

#: How many members of an archive are listed. A ``~mis*.zip`` holds the whole mission tree; the
#: listing is a shape, not an inventory.
MAX_ARCHIVE_MEMBERS = 40

#: Stands in for an attachment name when redaction is not reachable. The file still travels and its
#: reason is still stated; only the name a stranger chose is withheld.
UNREDACTED_NAME = "(a filename that could not be redacted)"


@dataclass(frozen=True)
class Incoming:
    """One attachment as Discord described it, before anything was downloaded.

    Attributes:
        filename: The name the reporter's file had. Untrusted: it can hold path separators and
            traversal segments, and :func:`safe_name` is what makes it usable.
        url: The signed, expiring Discord URL.
        size: The size Discord reported, in bytes. A claim, checked again while reading.
        content_type: What Discord guessed, kept for the record and never trusted for routing.
    """

    filename: str
    url: str
    size: int = 0
    content_type: str = ""


@dataclass(frozen=True)
class Prepared:
    """An attachment that survived, ready to be uploaded to the issue.

    Attributes:
        filename: A safe, **redacted** name derived from the reporter's. Safe for the filesystem
            and safe to publish are two different properties, and this is the second one; the
            bytes live at :attr:`path`, under the first.
        kind: One of the values of :data:`ACCEPTED_SUFFIXES`.
        path: Where the bytes are on local disk.
        size: Actual size in bytes.
        rendered: What the issue body says about this file — a log excerpt, a mission shape, a
            quoted text — already redacted. Empty when the file is attached without a summary.
        withheld: What was deliberately not published from it.
    """

    filename: str
    kind: str
    path: Path
    size: int
    rendered: str = ""
    withheld: tuple[str, ...] = ()


@dataclass(frozen=True)
class Rejected:
    """An attachment that did not survive, and why.

    Attributes:
        filename: The reporter's name for the file, redacted.
        reason: A sentence the reporter reads. Never a stack trace, and never a quotation of the
            file's own content.
    """

    filename: str
    reason: str


@dataclass(frozen=True)
class Harvest:
    """The whole attachment pass over one report.

    Attributes:
        prepared: What can be uploaded.
        rejected: What could not, each with its reason.
    """

    prepared: tuple[Prepared, ...] = ()
    rejected: tuple[Rejected, ...] = ()


#: What downloads one URL into a file. Injected so the whole pass is testable without a network:
#: it takes the URL, the destination and the byte ceiling, and returns the number of bytes written.
Downloader = Callable[[str, Path, int], Awaitable[int]]


class TooLarge(RuntimeError):
    """The ceiling was reached while reading, whatever the headers claimed."""


def safe_name(raw: str) -> str:
    """Turn a reporter-supplied filename into one that can only name a file in one directory.

    Args:
        raw: The filename as it arrived.

    Returns:
        The basename with every path separator, traversal segment and control character gone,
        bounded in length. Never empty: an unusable name becomes ``attachment``.
    """
    flattened = raw.replace("\\", "/")
    base = PurePosixPath(flattened).name
    cleaned = "".join(character for character in base if character.isprintable() and character not in '/:*?"<>|')
    cleaned = cleaned.strip(" .")
    return cleaned[:120] or "attachment"


def classify(filename: str) -> str:
    """Say what kind of file a name claims to be.

    Args:
        filename: A safe filename.

    Returns:
        The kind, or an empty string when the suffix is not on the allow-list.
    """
    return ACCEPTED_SUFFIXES.get(PurePosixPath(filename).suffix.lower(), "")


def describe_size(size: int) -> str:
    """Render a byte count the way the refusal message says it.

    Args:
        size: Bytes.

    Returns:
        e.g. ``"11.1 MB"``.
    """
    if size < 1024:
        return f"{size} B"
    if size < 1024 * 1024:
        return f"{size / 1024:.1f} kB"
    return f"{size / (1024 * 1024):.1f} MB"


class AttachmentCollector:
    """Downloads, reduces and redacts the attachments of one report."""

    def __init__(
        self,
        checkout: Checkout,
        download: Downloader,
        *,
        max_file_bytes: int = DEFAULT_MAX_FILE_BYTES,
        max_total_bytes: int = DEFAULT_MAX_TOTAL_BYTES,
    ) -> None:
        """Initialize the collector.

        Args:
            checkout: The working copy the reduction helpers are imported from.
            download: How bytes are fetched.
            max_file_bytes: Per-file ceiling.
            max_total_bytes: Whole-report ceiling.
        """
        self._checkout = checkout
        self._download = download
        self._max_file = max_file_bytes
        self._max_total = max_total_bytes
        self._logger = get_logger("intake")

    async def collect(self, incoming: list[Incoming], workdir: Path) -> Harvest:
        """Run the whole pass.

        Args:
            incoming: What the thread carried.
            workdir: A directory the caller owns and cleans up.

        Returns:
            The harvest. Never raises for one bad file.
        """
        prepared: list[Prepared] = []
        rejected: list[Rejected] = []
        spent = 0

        for item in incoming:
            # Two names, because they answer two different questions. `safe_name` makes a name that
            # can only name a file in one directory, which is what the download needs; `_publishable`
            # makes one that can go in a public issue, which is what every `Prepared` and `Rejected`
            # below carries. A name Discord kept — `dcs - Jean Dupont.log`, a mission exported under
            # its author's own name — is reporter-supplied text like any other.
            name = safe_name(item.filename)
            shown = self._publishable(name)
            kind = classify(name)
            if not kind:
                rejected.append(
                    Rejected(shown, f"unsupported file type ({PurePosixPath(shown).suffix or 'no suffix'})")
                )
                continue
            if item.size and item.size > self._max_file:
                rejected.append(
                    Rejected(
                        shown, f"too large ({describe_size(item.size)}; the limit is {describe_size(self._max_file)})"
                    )
                )
                continue
            remaining = min(self._max_file, self._max_total - spent)
            if remaining <= 0:
                rejected.append(
                    Rejected(shown, f"the report already reached {describe_size(self._max_total)} of files")
                )
                continue

            target = _unique(workdir / name)
            try:
                written = await self._download(item.url, target, remaining)
            except TooLarge:
                target.unlink(missing_ok=True)
                rejected.append(Rejected(shown, f"larger than the {describe_size(remaining)} left for this report"))
                continue
            except Exception as error:  # noqa: BLE001 - one unreachable file is not a failed report
                target.unlink(missing_ok=True)
                self._logger.warning(
                    "an attachment could not be downloaded",
                    extra={"event": "intake.download_failed", "error": type(error).__name__},
                )
                rejected.append(Rejected(shown, f"could not be downloaded ({type(error).__name__})"))
                continue

            spent += written
            prepared.append(self._reduce(shown, kind, target, written, rejected))

        return Harvest(prepared=tuple(prepared), rejected=tuple(rejected))

    def _publishable(self, name: str) -> str:
        """Turn a filesystem-safe name into one that can be published.

        Args:
            name: The output of :func:`safe_name`.

        Returns:
            The redacted name, or :data:`UNREDACTED_NAME` when redaction is not reachable. It fails
            closed for the same reason :func:`veaf_support_bot.bugreport.safe_redact` does: a name
            nobody could redact is not a name to print in a public issue.
        """
        try:
            return redact(self._checkout.root, name)
        except ToolkitUnavailable as error:
            self._logger.warning(
                "an attachment name could not be redacted; it is withheld",
                extra={"event": "intake.name_not_redacted", "error": type(error).__name__},
            )
            return UNREDACTED_NAME

    def _reduce(self, name: str, kind: str, path: Path, size: int, rejected: list[Rejected]) -> Prepared:
        """Turn one downloaded file into what the issue says about it.

        Args:
            name: The publishable filename.
            kind: Its classification.
            path: Where it landed.
            size: Its actual size.
            rejected: Collector for problems that do not stop the file from being attached.

        Returns:
            The prepared attachment. A reduction that fails still yields an attachment: the file
            travels, the summary does not, and the reason is recorded.
        """
        renderer = {
            "log": self._render_log,
            "mission": self._render_mission,
            "text": self._render_text,
            "archive": self._render_archive,
        }[kind]
        try:
            rendered, withheld = renderer(path)
        except ToolkitUnavailable as error:
            rejected.append(Rejected(name, f"attached, but not summarised: {error}"))
            rendered, withheld = "", ()
        except (OSError, ValueError, zipfile.BadZipFile) as error:
            rejected.append(Rejected(name, f"attached, but unreadable: {type(error).__name__}"))
            rendered, withheld = "", ()
        return Prepared(filename=name, kind=kind, path=path, size=size, rendered=rendered, withheld=withheld)

    def _render_log(self, path: Path) -> tuple[str, tuple[str, ...]]:
        """Reduce a log through the shared excerpt builder.

        Args:
            path: The downloaded log.

        Returns:
            The rendered excerpt with its catalogue matches, and what was withheld.
        """
        digest = digest_log(self._checkout.root, path)
        header = (
            f"{digest.selected_records} of {digest.total_records} records kept by the *Diagnostic* profile; "
            f"{digest.uncatalogued} of them match no catalogue entry."
        )
        return f"{header}\n\n{digest.catalogue}\n\n{digest.excerpt}", (
            "everything the Diagnostic profile filtered out",
        )

    def _render_mission(self, path: Path) -> tuple[str, tuple[str, ...]]:
        """Summarise a mission through the tools' own export.

        Args:
            path: The downloaded ``.miz``.

        Returns:
            The rendered field set, and the field groups deliberately dropped.
        """
        summary = summarise_mission(self._checkout.root, path)
        lines = [f"- {key}: {value}" for key, value in sorted(summary.fields.items())]
        return "\n".join(lines) or "(the mission stated none of the published fields)", summary.withheld

    def _render_text(self, path: Path) -> tuple[str, tuple[str, ...]]:
        """Quote a small text file, redacted.

        Args:
            path: The downloaded file.

        Returns:
            The redacted content, or an empty string when the file is too long to quote.
        """
        content = path.read_text(encoding="utf-8", errors="replace")
        if len(content) > MAX_QUOTED_TEXT_CHARS:
            return "", (f"the file is {len(content)} characters; it is attached rather than quoted",)
        return redact(self._checkout.root, content), ()

    def _render_archive(self, path: Path) -> tuple[str, tuple[str, ...]]:
        """List the shape of an archive without extracting it.

        A ``~mis*.zip`` is a DCS autosave of the whole mission tree. Listing member names says what
        the reporter was working on; extracting it would publish it.

        Args:
            path: The downloaded archive.

        Returns:
            The listing, and what was withheld.

        Raises:
            zipfile.BadZipFile: The archive is corrupt; the caller records that and attaches it
                anyway.
        """
        with zipfile.ZipFile(path) as archive:
            names = sorted(info.filename for info in archive.infolist() if not info.is_dir())
        shown = names[:MAX_ARCHIVE_MEMBERS]
        listing = "\n".join(f"- {name}" for name in shown)
        withheld: tuple[str, ...] = ("the archive's contents; only member names are listed",)
        if len(names) > len(shown):
            listing += f"\n- … and {len(names) - len(shown)} more"
        # Member names are text a stranger wrote, exactly like the body of a `.txt`: a `~mis*.zip` is
        # a DCS autosave and its paths carry the account name. Redacted here rather than at render
        # time so step 4 of this module's header holds for every text artefact without exception —
        # and so a redaction that cannot run refuses the listing instead of publishing it raw.
        return redact(self._checkout.root, listing), withheld


#: How long one attachment download is given.
DOWNLOAD_TIMEOUT_SECONDS = 120.0

#: Size of one read while streaming a download. Small enough that the ceiling is enforced on a
#: kilobyte rather than after a whole file has landed on the disk.
DOWNLOAD_CHUNK_BYTES = 64 * 1024


async def http_download(url: str, target: Path, ceiling: int) -> int:
    """Stream one attachment to disk, stopping the moment it exceeds the ceiling.

    Streaming rather than ``read()`` is the whole point: ``Content-Length`` is a claim by whoever
    serves the URL, and a service that trusts it writes whatever it is sent. The ceiling is enforced
    on the bytes that actually arrive.

    Args:
        url: The attachment URL Discord signed.
        target: Where to write.
        ceiling: Most bytes to accept.

    Returns:
        The number of bytes written.

    Raises:
        TooLarge: The body exceeded *ceiling*; the partial file is removed by the caller.
        aiohttp.ClientError: The download failed. Caught by :meth:`AttachmentCollector.collect`.
    """
    import aiohttp

    timeout = aiohttp.ClientTimeout(total=DOWNLOAD_TIMEOUT_SECONDS)
    written = 0
    async with aiohttp.ClientSession(timeout=timeout) as session:
        async with session.get(url) as response:
            response.raise_for_status()
            with target.open("wb") as handle:
                async for chunk in response.content.iter_chunked(DOWNLOAD_CHUNK_BYTES):
                    written += len(chunk)
                    if written > ceiling:
                        raise TooLarge(f"the body passed {ceiling} bytes")
                    handle.write(chunk)
    return written


def _unique(target: Path) -> Path:
    """Return a path that does not exist yet, so two attachments of the same name both survive.

    Args:
        target: The wanted path.

    Returns:
        *target*, or the same name with a counter inserted.
    """
    if not target.exists():
        return target
    for index in range(1, 1000):
        candidate = target.with_name(f"{target.stem}-{index}{target.suffix}")
        if not candidate.exists():
            return candidate
    raise OSError(f"could not find a free name beside {target}")
