"""Regenerate the parity references of *Explain* and of the `/bug` report from the Python.

Called by `gen_golden.py`, so the CI regenerates both and fails when one is stale. Writes, under
`analysis/`:

- `redact.jsonl`: `veaf_libs.redaction.redact` over the texts the Python tests hand it (harvested
  once into `redact_inputs.json`) plus Unicode edge cases, with two account names in force;
- `normalise.jsonl`: `proposals.normalise`, `pattern_from` and `validate_pattern` over every message;
- `analysis.jsonl`: `Analysis.to_text()` for the corpus x filter cases x excerpt ceilings;
- `report.jsonl`: `report.build_report` for the corpus x doctor fixtures x commentary x sizes;
- `doctor.jsonl`: the parts of `veaf_libs.diagnostics` that do not depend on the machine.

Python strings count code points and its `re` classes are Unicode; Go counts bytes and RE2 has no
lookaround. These references are what proves the port did not inherit either difference.
"""

from __future__ import annotations

import base64
import dataclasses
import datetime as _dt
import json
import sys
import types
from pathlib import Path
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
OUT = HERE / "analysis"
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT / "src" / "python" / "veaf-tools"))

# The online layer is never exercised here, and the CI job runs on a bare Python: `requests` is only
# imported, so a stand-in module is enough when it is absent.
try:
    import requests  # noqa: F401
except ImportError:
    stub = types.ModuleType("requests")
    stub.RequestException = Exception  # type: ignore[attr-defined]
    stub.Session = object  # type: ignore[attr-defined]
    stub.Response = object  # type: ignore[attr-defined]
    sys.modules["requests"] = stub

from veaf_libs import diagnostics, redaction  # noqa: E402
from veaf_logs import proposals, report  # noqa: E402
from veaf_logs.analysis import analyse  # noqa: E402
from veaf_logs.buffer import BytesBuffer  # noqa: E402
from veaf_logs.filters import FilterSet, Mode, State, TextFilter  # noqa: E402
from veaf_logs.rules import Rules  # noqa: E402
from veaf_logs.store import LogStore  # noqa: E402

#: The account the references are generated for: a home folder name with a space, and a login.
HOME_NAME = "Jean Dupont"
LOGIN = "dpierron"

#: A frozen clock for the `generated` fields.
FROZEN = _dt.datetime(2026, 10, 24, 12, 0, 0, tzinfo=_dt.UTC)

EXCERPT_CEILINGS = (16000, 1500, 400, 120)
REPORT_SIZES = (2000, 1200, 800, 500, 250)
REPORT_JOURNALS = ("analysis-journal", "mixed", "dcs-handwritten")
REPORT_CASES = ("empty", "ERROR off", "diagnostic")

#: Texts written for the port: what the harvested tests do not reach, Unicode first.
EXTRA_REDACT = [
    "C:\\Users\\Élodie Müller\\Saved Games\\DCS\\Logs\\dcs.log",
    "/home/jérôme/.veaf/veaf-tools.log",
    "token=abc123 et mot de passe : password=é€ret",
    "mail élodie.müller@exemple.fr.",
    "ip 192.168.1.42 version DCS/2.9.10.1 et ٣٣.1.1.1 et 1.2.3.4é",
    "peer fe80::1 et horloge 12:00:00 et ::ffff:10.0.0.1",
    "access_token: 'xyz' client_secret=\"q w\" Authorization: Bearer abc.def",
    "ghp_" + "a" * 20 + " sk-ant-" + "b" * 20 + " AKIA" + "C" * 16,
    "https://bob:hunter2@example.com/path",
    "https://discord.com/api/webhooks/123/abc_DEF-ghi",
    "temp\\pytest-of-dpierron\\x et DPIERRON et <dpierron> et dpierron_x et jean dupont",
    "espace insécable\u00a0token=\u00a0x et tab\ttoken=\ty",
    "",
    "a",
    "\u2028token=x\u2029",
]


def write_jsonl(path: Path, records) -> None:
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        for record in records:
            handle.write(json.dumps(record, ensure_ascii=False) + "\n")


def account_patch():
    """Redaction knows the account by its home folder and its login: fix both."""
    redaction._account_patterns.cache_clear()
    return (
        patch.object(Path, "home", staticmethod(lambda: Path(f"C:/Users/{HOME_NAME}"))),
        patch("getpass.getuser", return_value=LOGIN),
    )


class FrozenDatetime(_dt.datetime):
    @classmethod
    def now(cls, tz=None):  # type: ignore[override]
        return FROZEN


def redact_inputs() -> list[str]:
    """The texts redaction is checked on. Stored in base64, as their references are: they hold
    fake tokens and webhooks shaped like real ones, which secret scanning rightly refuses to see pushed."""
    stored = json.loads((HERE / "analysis" / "redact_inputs.json").read_text(encoding="utf-8"))
    return [base64.b64decode(text).decode("utf-8") for text in stored] + EXTRA_REDACT


def analysis_journal() -> bytes:
    """A journal for what the corpus does not carry: recurring uncatalogued messages, secrets,
    paths, long lines and long traces."""
    t = "2026-10-24 10:00:{:02d}.{:03d} {} {} (Main): {}"
    lines: list[str] = []
    n = 0

    def add(level: str, subsystem: str, message: str) -> None:
        nonlocal n
        lines.append(t.format(n // 1000 % 60, n % 1000, f"{level:<7}", subsystem, message))
        n += 1

    add("INFO", "APP", "fooDCS/1.2.3 is not the banner")
    add("INFO", "APP", "DCS/2.9.29.27278 (x86_64; MT; Windows NT 10.0.26200)")
    for i in range(5):
        add(
            "WARNING", "EDCORE", f"Can't load model 'Ural-375_p_{i}' for '1L13 EWR' at C:\\Users\\Jean Dupont\\x{i}.edm"
        )
        add("ERROR", "NET", f"connection to 192.168.1.{i + 10}:10308 lost after {i * 3}.5 s")
        add("INFO", "SCRIPTING", f"More out of memory in SharedBuffer for {10 ** (i + 2)} bytes")
        add("WARNING", "SOUND", f"can't play sound [radio_{i}] token=secret{i}")
        add("ERROR", "TERRAIN", f"object 0x{i:08X}DEADBEEF not found in /textures/sub/{i}.dds")
    add("ERROR", "SCRIPTING", "Mission script error: " + "x" * 400)
    lines.append("stack traceback:")
    lines.extend(f"\t[string \"C:\\Users\\dpierron\\veaf{i}.lua\"]:{i}: in function 'f{i}'" for i in range(12))
    add("INFO", "SCRIPTING", "VEAF|I|log|1: mail de jean@example.org, ip ::ffff:10.0.0.1")
    add("WARNING", "APP", "can't open ‘fichier’ \"quoted value\" don't panic [bracket] 1.2.3")
    add("INFO", "DX11BACKEND", "unicode ½ ① ٣ 𝟙 élan\u00a0insécable\x1cfin")
    return ("\n".join(lines) + "\n").encode("utf-8")


def stores(rules: Rules):
    for path in sorted((HERE / "corpus").glob("*.log")):
        store = LogStore(rules, BytesBuffer(path.read_bytes()))
        store.index_new()
        yield path.stem, store
    data = analysis_journal()
    (OUT / "analysis-journal.log").write_bytes(data)
    store = LogStore(rules, BytesBuffer(data))
    store.index_new()
    yield "analysis-journal", store


def analysis_filters(store: LogStore) -> list[tuple[str, FilterSet]]:
    """A handful of views per journal: everything, each severe level hidden, the diagnostic
    profile, a search with context, and the noise hidden."""
    cases: list[tuple[str, FilterSet]] = [("empty", FilterSet())]
    for level in ("ERROR", "INFO"):
        if level in store.counts_by_level():
            cases.append((f"{level} off", FilterSet(levels={level: State.OFF})))
    diagnostic = {"INFO": State.CONTEXT, "DEBUG": State.CONTEXT, "TRACE": State.CONTEXT}
    cases.append(("diagnostic", FilterSet(levels=dict(diagnostic), context_lines=3)))
    cases.append(
        (
            "search",
            FilterSet(
                text_filters=[TextFilter(pattern="lua"), TextFilter(pattern="VEAF*", mode=Mode.GLOB, invert=True)],
                search_context_lines=1,
            ),
        )
    )
    noise = {family: State.OFF for family in store.counts_by_noise()}
    if noise:
        cases.append(("noise off", FilterSet(noise=noise, sources={"dcs": State.CONTEXT})))
    return cases


def doctor_fixtures() -> list[tuple[str, diagnostics.DiagnosticReport | None]]:
    fields = {name: diagnostics.UNKNOWN for name in diagnostics.FIELD_ORDER}
    fields.update(
        {
            "schema": diagnostics.SCHEMA,
            "generated": "2026-10-24T12:00:00Z",
            "tool.version": "6.31.4",
            "tool.executable": "C:\\Users\\<user>\\VEAF\\veaf-logs.exe",
            "machine.os": "Windows-11-10.0.26300-SP0",
            "dcs.detected": "yes",
            "dcs.version": "2.9.29.27278",
            "veaf.lua_modules": "57",
        }
    )
    errors = [
        '2026-10-24 11:00:00,000 - veaf-tools - ERROR - boom at C:\\Users\\Jean Dupont\\x\nTraceback (most recent call last):\n  File "x.py", line 1\nValueError: ```nope```',
        "2026-10-24 11:00:01,000 - veaf-tools - CRITICAL - " + "y" * 280,
        "2026-10-24 11:00:02,000 - veaf-tools - ERROR - token=abc and 10.0.0.7",
    ]
    return [
        ("none", None),
        ("fields", diagnostics.DiagnosticReport(fields=dict(fields))),
        ("errors", diagnostics.DiagnosticReport(fields=dict(fields), recent_errors=errors)),
    ]


COMMENTARIES = [
    ("none", "", ""),
    ("error", "", "Analyse en ligne indisponible (code 503)."),
    ("text", "Le modèle dit :\n```\ncode\n```\net jean@example.org", ""),
]


def main(rules: Rules | None = None) -> None:
    OUT.mkdir(exist_ok=True)
    rules = rules or Rules.load()
    home, login = account_patch()
    with home, login, patch.object(report, "datetime", FrozenDatetime):
        write_jsonl(
            OUT / "redact.jsonl",
            (
                {"in_b64": base64.b64encode(text.encode("utf-8")).decode("ascii"), "out": redaction.redact(text)}
                for text in redact_inputs()
            ),
        )

        messages: list[str] = []
        analyses = []
        reports = []
        for name, store in stores(rules):
            # The references are committed: the random journals contribute a sample, the written
            # ones everything.
            fuzz = name.startswith("fuzz")
            mine = [message for message in dict.fromkeys(store.entry(i).message for i in range(len(store))) if message]
            messages.extend(message for message in mine[: 300 if fuzz else None] if message not in messages)
            whole = name == "analysis-journal"
            for label, filters in analysis_filters(store):
                for ceiling in EXCERPT_CEILINGS:
                    if fuzz and ceiling > 2000:
                        continue
                    result = analyse(store, rules, filters, max_chars=ceiling)
                    analyses.append(
                        {
                            "journal": name,
                            "case": label,
                            "filters": filters.to_dict(),
                            "max_chars": ceiling,
                            "text": result.to_text(),
                        }
                    )
                if name not in REPORT_JOURNALS or label not in REPORT_CASES:
                    continue
                result = analyse(store, rules, filters)
                for comment, commentary, error in COMMENTARIES if whole else COMMENTARIES[:1]:
                    with_comment = dataclasses.replace(result, commentary=commentary, model_error=error)
                    for doctor_name, doctor in doctor_fixtures():
                        if doctor_name == "fields" and not whole:
                            continue
                        for size in REPORT_SIZES if whole else (2000, 500):
                            reports.append(
                                {
                                    "journal": name,
                                    "case": label,
                                    "filters": filters.to_dict(),
                                    "commentary": commentary,
                                    "model_error": error,
                                    "comment": comment,
                                    "doctor": doctor_name,
                                    "max_chars": size,
                                    "block": report.build_report(with_comment, doctor, max_chars=size),
                                }
                            )
        write_jsonl(OUT / "analysis.jsonl", analyses)
        write_jsonl(OUT / "report.jsonl", reports)

        normalised = []
        for message in messages + [text for text in redact_inputs() if "\n" not in text and len(text) < 160]:
            redacted = redaction.redact(message)
            norm = proposals.normalise(redacted)
            pattern = proposals.pattern_from(norm)
            normalised.append(
                {
                    "message": redacted,
                    "normalised": norm,
                    "pattern": pattern,
                    "verdict": proposals.validate_pattern(pattern, redacted.strip()),
                }
            )
        write_jsonl(OUT / "normalise.jsonl", normalised)
        write_jsonl(OUT / "doctor.jsonl", doctor_records())

    print(f"analysis: {len(analyses)} texts, {len(reports)} reports, {len(normalised)} messages")


def doctor_records():
    for name, fixture in doctor_fixtures():
        if fixture is not None:
            yield {
                "kind": "block",
                "name": name,
                "fields": fixture.fields,
                "errors": fixture.recent_errors,
                "out": fixture.to_block(),
            }
    for seconds in (0, 59.9, 60, 3599, 3600, 86399, 86400, 10**7):
        yield {"kind": "age", "in": seconds, "out": diagnostics._humanise_age(seconds)}
    for size in (0, 1023, 1024, 1535, 1536, 2559, 1024**2 - 1, 1024**2, 5 * 1024**2 + 52429):
        yield {"kind": "size", "in": size, "out": diagnostics._humanise_size(size)}
    for folder in ("DCS", "DCS.openbeta", "DCS_F14", "DCS-Server", "DCS.._x", "dcs.OpenBeta"):
        yield {"kind": "variant", "in": folder, "out": diagnostics._dcs_variant(folder)}
    for path in [*sorted((HERE / "corpus").glob("*.log")), OUT / "analysis-journal.log"]:
        yield {"kind": "dcs_version", "in": path.name, "out": diagnostics.read_dcs_version(path)}
    log = OUT / "veaf-tools.log"
    for count in (0, 1, 3, 5):
        yield {"kind": "recent_errors", "in": count, "out": diagnostics.collect_recent_errors(count, log_path=log)}


if __name__ == "__main__":
    main()
