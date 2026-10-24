"""Regenerate the parity corpus and its golden dumps from the Python reference.

Run from the repository root:

    poetry run python src/go/veaf-logs/testdata/gen_golden.py

Writes `corpus/*.log` (synthetic: no real journal is committed, they carry
player names and paths) and `golden/*.jsonl`, one record per entry as produced
by `veaf_logs.store.LogStore`. `parity_test.go` indexes the same corpus with
the Go core and compares record by record.
"""

from __future__ import annotations

import json
import random
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT / "src" / "python" / "veaf-tools"))

from veaf_logs.buffer import BytesBuffer  # noqa: E402
from veaf_logs.filters import FilterSet, Mode, PatternError, State, TextFilter, evaluate  # noqa: E402
from veaf_logs.rules import Rules  # noqa: E402
from veaf_logs.store import LogStore  # noqa: E402

SERVER = "VEAF (www.veaf.org) [fr] - Public 1"

DCS = [
    b"=== Log opened UTC 2026-08-31 09:50:40",
    b"2026-08-31 11:50:40.872 ERROR   APP (Main): Error: Unit [F-14B]: Corrupt damage model.",
    b"2026-08-31 11:50:41.000 INFO    SCRIPTING (Main): VEAF|I|5390: Loading version 6.16.5",
    b"2026-08-31 11:50:41.001 INFO    SCRIPTING (Main): VEAF-GRASS|W|log|123: zone introuvable",
    b"2026-08-31 11:50:41.002 INFO    SCRIPTING (Main): VEAF|D|log|1: debug detail",
    b"2026-08-31 11:50:41.003 INFO    SCRIPTING (Main): VEAF-DYNAMICLOADER: loading",
    b"2026-08-31 11:50:43.000 INFO    SCRIPTING (Main): [CTLD][INFO] scene registered",
    b"2026-08-31 11:50:43.001 INFO    SCRIPTING (Main): [CTLD][WARNING] low fuel",
    b"2026-08-31 11:50:43.002 INFO    SCRIPTING (Main): [CTLD][BOGUS] unknown level token",
    b"2026-08-31 11:50:43.003 INFO    SCRIPTING (Main):   E - CSAR - pilot lost",
    b"2026-08-31 11:50:43.004 INFO    SCRIPTING (Main): AIEN|T|trace line",
    b"2026-08-31 11:50:43.005 INFO    SCRIPTING (Main): something SKYNET related",
    b"2026-08-31 11:50:43.006 INFO    SCRIPTING (Main): Slmod: loaded",
    b"2026-08-31 11:50:43.007 INFO    SCRIPTING (Main): uses MIST helpers",
    b"2026-08-31 11:50:43.008 INFO    SCRIPTING (Main): MOOSE framework",
    b"2026-08-31 11:50:43.009 INFO    SCRIPTING (Main): [dcs-bridge] started",
    b"2026-08-31 11:50:43.010 INFO    SCRIPTING (Main): DCS-gRPC listening",
    b"2026-08-31 11:50:43.011 INFO    SCRIPTING (Main): SRS: connected",
    b"2026-08-31 11:50:43.012 INFO    SCRIPTING (Main): STTS ready",
    b"2026-08-31 11:50:43.013 INFO    SCRIPTING (Main): SRSX is not SRS",
    b"2026-08-31 11:55:01.930 ERROR   SCRIPTING (Main): Mission script error: CSAR.lua:2213",
    b"stack traceback:",
    b"\t[C]: in function 'getUnitRecordById'",
    b'\t[string "C:/x.lua"]:12: in main chunk',
    b"2026-08-31 11:55:10.095 WARNING FLIGHT (Main): No taxiroad found on Batumi from 1 to 2",
    b"2026-08-31 11:55:10.096 WARNING MissionScripting::initialize (12345): scoped subsystem",
    b"2026-08-31 11:55:10.097 ALERT   (Main): empty subsystem",
    b"2026-08-31 11:55:10.098 ERROR_ONCE APP (Main): once only",
    b"2026-08-31 11:55:10.099 TRACE   APP (7788): tracing",
    b"2026-08-31 11:55:10.100 DEBUG   APP (Main):",
    b"2026-08-31 11:55:10.101 WEIRD   APP (Main): level the catalogue does not know",
    b"2026-08-31 11:55:11.000 INFO    EDCORE (Main): Need to reprocess [DDS] image x",
    b"2026-08-31 11:55:11.001 INFO    EDCORE (Main): hypervisor is active",
    b"2026-08-31 11:55:11.002 WARNING EDCORE (Main): Can't open file: /textures/a.dds",
    b"2026-08-31 11:55:11.003 WARNING EDCORE (Main): Can't load lod abc Reason: nope",
    b"2026-08-31 11:55:11.004 WARNING EDCORE (Main): Scene was removed with 12 alive objects",
    b"2026-08-31 11:55:11.005 WARNING EDCORE (Main): texture 'x.dds' not found",
    b"2026-08-31 11:55:11.006 WARNING EDCORE (Main): Texture [abc] not found",
    b"2026-08-31 11:55:11.007 INFO    EDCORE (Main): duplicate message(s) skipped.",
    b"2026-08-31 11:55:11.008 INFO    SCRIPTING (Main): negative weight of payload and Corrupt damage model.",
    # Accents and non-ASCII in header-adjacent and message positions.
    "2026-08-31 11:55:12.000 INFO    SCRIPTING (Main): VEAF|I|log|1: zone « Bastogne » créée".encode(),
    "2026-08-31 11:55:12.001 INFO    SCRIPTING (Main): ligne avec \u2028 separateur".encode(),
    b"2026-08-31 11:55:12.002 INFO    SCRIPTING (Main): form\x0cfeed in a line",
    b"2026-08-31 11:55:12.003 INFO    SCRIPTING (Main): bad byte \xff\xfe in a line",
    b"2026-08-31 11:55:12.004 INFO    SCRIPTING (Main): CRLF ending\r",
    b"continuation after CRLF\r",
    b"",
    b"   leading spaces continuation",
    b"=== Log closed UTC 2026-08-31 09:57:00",
    b"=== Log opened UTC 2026-08-31 10:00:00",
    b"2026-08-31 12:00:00.000 INFO    APP (Main): after a reopen",
]

OTHERS = [
    b"2026-09-29 18:02:42.798 INFO\tDCSServerBot v3.0.4.22 starting up ...",
    b"2026-09-29 18:02:44.490 WARNING\tNew update for DCSServerBot available!",
    b"Use /node upgrade or enable autoupdate to apply it.",
    b"2026-09-29 18:09:52.501 DEBUG\tHOST->" + SERVER.encode() + b': {"command": "getMissionUpdate"}',
    b"2026-09-29 18:09:52.502 DEBUG\t" + SERVER.encode() + b'->HOST: {"command": "onMissionEvent", "x": 1}',
    b"2026-09-29 18:09:52.503 DEBUG\t" + SERVER.encode() + b'->HOST: {"command": "perfmon"}',
    b"2026-09-29 18:09:52.504 INFO\tnode registered with the cloud.",
    b"2026-09-29 18:03:38,541\tINFO\t4.80s\tServerImpl.apply_mission_changes()",
    b"2026-09-29 18:02:44.490 CRITICAL\tboom",
    b"2026-09-29 18:04:38.123 DEBUG\tSRS: is NOT running (process)",
    b"2026-09-29 18:04:38.124 DEBUG\tVEAF|I|not a script here",
    b"2026-09-29 18:04:38.125 BOGUS\tunknown level",
    b"2026-09-29T20:03:44.385+0200\tWARN\tno suitable weather preset for code=FEW and base=6561",
    b"2026-09-29T20:04:38.522+0200\tFATAL\tno weather data received",
    b"2026-09-29T20:04:38.523+0200\tPANIC\tp",
    b"2026-09-29T20:04:38.524-0100\tDPANIC\tdp",
    b"2026-09-29T20:04:38.525+0200\tINFO\tusing real weather v2.5.0",
    b"[2026-09-29 20:05:21 +02:00] [W] [clienthandler] Client deleted",
    b"[2026-09-29 20:05:21 +02:00] [I] [clienthandler] Init",
    b"[2026-09-29 20:05:21 +02:00] [I] [clienthandler] Init extra",
    b"[2026-09-29 20:05:22 +02:00] [I] [NetServer] Incoming connection from x",
    b'[2026-09-29 20:05:23 +02:00] [I] [clientserver]  - "key" : value',
    b'[2026-09-29 20:05:24 +02:00] [I] [clientserver] Airport: 12 "Batumi" MapObject::COALITION_BLUE',
    b"[2026-07-23 22:00:55 +02:00] [I] --------------------",
    b"[2026-07-23 22:00:56 +02:00] [E] [a.b:c] error with component",
    b"[2026-07-23 22:00:57 +02:00] [X] unknown letter",
    b"2026-05-26T00:47:56.023909: Task exception was never retrieved",
    b"Traceback (most recent call last):",
    b"TimeoutError",
    b"==================================================",
    b"2026-05-26T07:33:56.307607: Task exception was never retrieved",
    b"[]  INFO    SCRIPTING: VEAF|W|log|9: bracket format script line",
    b"[12:00:01]  ERROR   SCRIPTING: [CTLD][ERROR] bracket ctld",
    b"[]  INFO    SCRIPTING:",
    b"[]  INFO    SRS: bracket srs",
    # Unknown formats, each line stays alone.
    b"just some text with no header",
    b"another line of text",
    b"2026-08-31 broken header, starts with a date",
    b"2026-08-31 11:50:40.872 ERROR no thread parens here",
    b"\xe2\x82",
]


def mutate(rng: random.Random, line: bytes) -> bytes:
    """A seeded corruption of a line: the regexes of both engines must agree on it too."""
    data = bytearray(line)
    for _ in range(rng.randint(1, 3)):
        kind = rng.randint(0, 5)
        if kind == 0 and data:
            del data[rng.randrange(len(data)) :]
        elif kind == 1 and data:
            data[rng.randrange(len(data))] = rng.choice(b"\t \r()[]|:-\xc3\xa9")
        elif kind == 2:
            data.insert(rng.randint(0, len(data)), rng.choice(b"\t\r \xff"))
        elif kind == 3 and len(data) > 1:
            i = rng.randrange(len(data) - 1)
            data[i], data[i + 1] = data[i + 1], data[i]
        elif kind == 4:
            data = bytearray(rng.choice(DCS + OTHERS)[:20]) + data
        elif kind == 5 and data:
            data.extend(b" " * rng.randint(1, 4))
    return bytes(data)


def build_fuzz(seed: int, count: int) -> bytes:
    rng = random.Random(seed)
    pool = [line for line in DCS + OTHERS if line]
    lines = [mutate(rng, rng.choice(pool)) if rng.random() < 0.7 else rng.choice(pool) for _ in range(count)]
    lines = [line.replace(b"\n", b" ") for line in lines]
    return b"\n".join(lines) + b"\n"


CORPUS = {
    "dcs-handwritten": b"\n".join(DCS) + b"\n",
    "other-formats": b"\n".join(OTHERS) + b"\n",
    "mixed": b"\n".join(DCS[:20] + OTHERS[:20] + DCS[20:] + OTHERS[20:]) + b"\n",
    "fuzz-1": build_fuzz(1, 2500),
    "fuzz-2": build_fuzz(2, 2500),
    # The last line has no newline: it must not be indexed.
    "no-final-newline": b"2026-08-31 11:50:40.872 ERROR   APP (Main): complete\n2026-08-31 11:50:41.000 INFO    APP (Main): incompl",
    "empty": b"",
}


def main() -> None:
    (HERE / "corpus").mkdir(exist_ok=True)
    (HERE / "golden").mkdir(exist_ok=True)
    rules = Rules.load()
    for name, data in CORPUS.items():
        (HERE / "corpus" / f"{name}.log").write_bytes(data)
        store = LogStore(rules, BytesBuffer(data))
        store.index_new()
        with open(HERE / "golden" / f"{name}.jsonl", "w", encoding="utf-8", newline="\n") as handle:
            for i in range(len(store)):
                e = store.entry(i)
                record = {
                    "lineno": e.lineno,
                    "level": e.level,
                    "source": e.source,
                    "label": e.source_label,
                    "module": e.module,
                    "noise": list(e.noise),
                    "timestamp": e.timestamp,
                    "subsystem": e.subsystem,
                    "message": e.message,
                    "conts": len(e.continuations),
                }
                handle.write(json.dumps(record, ensure_ascii=False) + "\n")
        counts = {
            "level": store.counts_by_level(),
            "source": store.counts_by_source(),
            "noise": store.counts_by_noise(),
        }
        (HERE / "golden" / f"{name}.counts.json").write_text(json.dumps(counts, sort_keys=True), encoding="utf-8")
        write_filter_golden(store, HERE / "golden" / f"{name}.filters.jsonl")
        print(f"{name}: {len(store)} entries")


# Patterns chosen against the corpus: literals, wildcards, classes, alternation,
# the anchors (`^` and `$` bind to each line, not to the search block), and an
# invalid regex. ASCII only: on non-ASCII
# text Python's bytes IGNORECASE and Go's (?i) do not fold the same way, a
# divergence pinned by a test of its own rather than hidden in the parity.
TEXT_CASES = [
    ("VEAF", "plain"),
    ("veaf", "plain"),
    ("zone introuvable", "plain"),
    ("stack traceback", "plain"),
    ("a.b", "plain"),
    ("[CTLD]", "plain"),
    ("VEAF*W*", "glob"),
    ("*.lua", "glob"),
    ("*error*lua*", "glob"),
    ("?ission", "glob"),
    ("CSAR.lua", "glob"),
    (r"VEAF\|[WE]\|", "regex"),
    (r"\d{4}-\d\d-\d\d", "regex"),
    (r"[a-z]+\.lua:\d+", "regex"),
    ("Error|WARNING", "regex"),
    ("^2026", "regex"),
    ("^=== Log", "regex"),
    (r"\.$", "regex"),
    ("2$", "regex"),
    # Every line that is not empty: `$` binds to each line end, not only to the block's last one.
    (".$", "regex"),
    ("x*", "regex"),
    # No empty line in the corpus: must keep nothing, though it matches past the block's final newline.
    ("^$", "regex"),
    ("$", "regex"),
    # Across a line inside an entry, and across two entries: a match the line-by-line shortcut cannot see.
    (r"traceback:\s+\S", "regex"),
    (r"\n2026", "regex"),
    ("[non fermee", "regex"),
]


def filter_cases(store: LogStore) -> list[tuple[str, FilterSet]]:
    """Every filter case, enumerated from what the journal holds rather than sampled."""
    cases: list[tuple[str, FilterSet]] = [("empty", FilterSet())]
    families = [
        ("levels", sorted(store.counts_by_level())),
        ("sources", sorted(store.counts_by_source())),
        ("noise", sorted(store.counts_by_noise())),
    ]
    for kind, keys in families:
        for key in keys:
            off = FilterSet()
            off.set_state(kind, key, State.OFF)
            cases.append((f"{kind}:{key}=off", off))
            for lines in (0, 1, 3):
                context = FilterSet(context_lines=lines)
                context.set_state(kind, key, State.CONTEXT)
                cases.append((f"{kind}:{key}=context±{lines}", context))
    for pattern, mode in TEXT_CASES:
        for case_sensitive in (False, True):
            for invert in (False, True):
                for search in (0, 2):
                    criterion = TextFilter(
                        pattern=pattern, mode=Mode(mode), case_sensitive=case_sensitive, invert=invert
                    )
                    label = f"{mode}:{pattern} case={case_sensitive} invert={invert} search±{search}"
                    cases.append((label, FilterSet(text_filters=[criterion], search_context_lines=search)))
    # The categories and the text together: the diagnostic profile, a search
    # inside it, a search context that must not reopen hidden lines, per-criterion
    # and per-category spans, two cumulative criteria.
    diagnostic = {"INFO": State.CONTEXT, "DEBUG": State.CONTEXT, "TRACE": State.CONTEXT}
    cases.append(("diagnostic", FilterSet(levels=dict(diagnostic), context_lines=3)))
    cases.append(
        (
            "diagnostic+search",
            FilterSet(
                levels=dict(diagnostic),
                text_filters=[TextFilter(pattern="lua")],
                context_lines=2,
                search_context_lines=1,
            ),
        )
    )
    cases.append(
        (
            "info hidden+search±3",
            FilterSet(levels={"INFO": State.OFF}, text_filters=[TextFilter(pattern="VEAF")], search_context_lines=3),
        )
    )
    spans = FilterSet(levels={"INFO": State.CONTEXT, "WARNING": State.CONTEXT}, context_lines=0)
    spans.set_span("levels", "INFO", 2)
    cases.append(("per-category span", spans))
    cases.append(
        (
            "two criteria, own span",
            FilterSet(
                text_filters=[
                    TextFilter(pattern="SCRIPTING"),
                    TextFilter(pattern="VEAF", mode=Mode.GLOB, context_lines=4),
                ],
                search_context_lines=1,
            ),
        )
    )
    cases.append(
        (
            "disabled criterion",
            FilterSet(text_filters=[TextFilter(pattern="VEAF", enabled=False)], levels={"ERROR": State.OFF}),
        )
    )
    return cases


def ranges(indices: list[int]) -> list[list[int]]:
    """Visible indices as `[first, last]` runs: compact, and still readable in a diff."""
    out: list[list[int]] = []
    for index in indices:
        if out and out[-1][1] == index - 1:
            out[-1][1] = index
        else:
            out.append([index, index])
    return out


def write_filter_golden(store: LogStore, path: Path) -> None:
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        for label, filters in filter_cases(store):
            record: dict[str, object] = {"case": label, "filters": filters.to_dict()}
            try:
                record["visible"] = ranges(evaluate(store, filters))
            except PatternError:
                record["error"] = True
            handle.write(json.dumps(record, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
