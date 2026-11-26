"""Every text that explains `delay_before_activating` says what `veafQraCore.lua` does (MCP-CONTEXT-BUDGET).

The count starts at the first intrusion once the QRA is ready (`STATUS_READY` -> `STATUS_READY_WAITINGFORMORE`),
an intruder leaving does not stop it, and only a rearm (`VeafQRACore:rearm`, back to `STATUS_READY`) starts it
again. On 2026-11-26 a first correction said "counted again at each entry", which the code never does.
"""

from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
PROMPTS = ROOT / "src/python/veaf-tools/veaf_mission_mcp/data/mission-prompts"

#: Each text, with the phrase it must carry about the count and the one it must not.
TEXTS = {
    "doc/mission-maker/scripts/veafQraManager.en.md": "first intrusion",
    "doc/mission-maker/scripts/veafQraManager.md": "première intrusion",
    "src/python/veaf-tools/veaf_mission_mcp/data/authoring-guide.md": "first intrusion",
    "src/python/veaf-tools/veaf_libs/data/known-limitations.yaml": "first intrusion",
    (PROMPTS.relative_to(ROOT) / "new-objective-mission.en.md").as_posix(): "first intrusion",
    (PROMPTS.relative_to(ROOT) / "new-objective-mission.fr.md").as_posix(): "première intrusion",
}

WRONG = ("each entry", "chaque entrée", "intruder stays", "intrus reste", "intruder spends")


@pytest.mark.parametrize("relative", sorted(TEXTS))
def test_the_qra_delay_counts_from_the_first_intrusion(relative: str) -> None:
    text = (ROOT / relative).read_text(encoding="utf-8")
    assert TEXTS[relative] in text, f"{relative} does not say the count starts at the first intrusion"
    # What follows each mention of the setting, where its explanation sits.
    windows = [text[at : at + 500] for at in range(len(text)) if text.startswith("elay_before_activating", at)]
    windows += [text[at : at + 500] for at in range(len(text)) if text.startswith("qra-has-no-start-time", at)]
    for phrase in WRONG:
        assert not any(phrase in window for window in windows), f"{relative} still says {phrase!r} about the delay"
