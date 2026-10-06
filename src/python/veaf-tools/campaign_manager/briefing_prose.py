"""The written half of the campaign briefing: `briefing.yaml` (FEAT-CAMPAIGN-BRIEFING-DECK ticket 03).

The tools generate what the campaign knows — zones, owners, friendly reserves, objectives, the map,
the rules. What a staff writes — the political and economic situation, the intent, the concept, the
rules of engagement, the coming mission's tasks — is written by Claude or the mission maker into this
file of the campaign folder, kept from one mission to the next, and rewritten where the last mission
changed it.

Every text is a string or a list of strings (one paragraph or bullet each).
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml
from veaf_libs.i18n import t
from veaf_libs.mission_validator import ERROR, WARNING, ValidationIssue

#: The prose file, next to `campaign.yaml`.
PROSE_FILE = "briefing.yaml"

#: The sections of the file, and their sub-sections when they have some.
SECTIONS: dict[str, tuple[str, ...]] = {
    "operation": (),
    "subtitle": (),
    "situation": ("political", "economic", "enemy_course_of_action", "friendly"),
    "mission": (),
    "intent": ("purpose", "main_effect", "method", "end_state"),
    "objectives": ("political", "military", "economic"),
    "concept": ("phases", "attention"),
    "rules_of_engagement": ("targeting", "civilians", "self_defence"),
    "missions": (),
}


@dataclass(frozen=True)
class Titled:
    """A text under its title: a phase of the concept, a task of a mission."""

    title: str
    text: tuple[str, ...]


@dataclass(frozen=True)
class MissionPage:
    """The page of one mission: its title and its tasks."""

    title: str
    tasks: tuple[Titled, ...]


@dataclass(frozen=True)
class BriefingProse:
    """A `briefing.yaml`, read: every section by its name, texts as tuples of paragraphs."""

    operation: str | None = None
    subtitle: str | None = None
    texts: dict[str, dict[str, tuple[str, ...]]] = field(default_factory=dict)
    """``situation``, ``intent``, ``objectives``, ``rules_of_engagement`` and ``concept.attention``:
    section → sub-section → paragraphs; the mission statement is ``texts["mission"]["mission"]``."""
    phases: tuple[Titled, ...] = ()
    missions: dict[int, MissionPage] = field(default_factory=dict)

    def text(self, section: str, part: str) -> tuple[str, ...]:
        """The paragraphs of a sub-section, empty when it is not written."""
        return self.texts.get(section, {}).get(part, ())


def _issue(level: str, key: str, **kwargs: Any) -> ValidationIssue:
    return ValidationIssue(level, t(f"campaign.issue.prose.{key}", **kwargs))


def _paragraphs(where: str, value: Any, issues: list[ValidationIssue]) -> tuple[str, ...]:
    """A string or a list of strings, as paragraphs; anything else is reported."""
    if isinstance(value, str) and value.strip():
        return (value.strip(),)
    if isinstance(value, list) and value and all(isinstance(item, str) and item.strip() for item in value):
        return tuple(item.strip() for item in value)
    issues.append(_issue(ERROR, "not_text", section=where))
    return ()


def _titled(where: str, value: Any, issues: list[ValidationIssue]) -> Titled | None:
    """A `{title, text}` entry."""
    if not isinstance(value, dict) or not isinstance(value.get("title"), str) or not value["title"].strip():
        issues.append(_issue(ERROR, "not_titled", section=where))
        return None
    return Titled(value["title"].strip(), _paragraphs(f"{where}.text", value.get("text"), issues))


def _unknown_keys(where: str, raw: dict[str, Any], known: tuple[str, ...], issues: list[ValidationIssue]) -> None:
    for key in raw:
        if key not in known:
            issues.append(_issue(ERROR, "unknown_key", section=where, key_name=key, known=", ".join(known)))


def parse_prose(raw: Any, missions: int, coming: int) -> tuple[BriefingProse | None, list[ValidationIssue]]:
    """Read a loaded `briefing.yaml`.

    Args:
        raw: The file's content, as loaded.
        missions: The campaign's mission count: one phase per mission at most, mission pages within it.
        coming: The mission the briefing is for; its page missing is a warning.

    Returns:
        The prose, ``None`` when any issue is an error, and every issue found.
    """
    issues: list[ValidationIssue] = []
    if not isinstance(raw, dict):
        return None, [_issue(ERROR, "not_a_mapping")]
    _unknown_keys("briefing.yaml", raw, tuple(SECTIONS), issues)

    names = {}
    for key in ("operation", "subtitle"):
        if key in raw:
            text = _paragraphs(key, raw[key], issues)
            names[key] = text[0] if text else None

    texts: dict[str, dict[str, tuple[str, ...]]] = {}
    if "mission" in raw:
        texts["mission"] = {"mission": _paragraphs("mission", raw["mission"], issues)}
    for section in ("situation", "intent", "objectives", "rules_of_engagement"):
        if section not in raw:
            continue
        value = raw[section]
        if not isinstance(value, dict):
            issues.append(_issue(ERROR, "not_a_section", section=section))
            continue
        _unknown_keys(section, value, SECTIONS[section], issues)
        texts[section] = {
            part: _paragraphs(f"{section}.{part}", text, issues)
            for part, text in value.items()
            if part in SECTIONS[section]
        }

    phases: list[Titled] = []
    concept = raw.get("concept")
    if concept is not None:
        if not isinstance(concept, dict):
            issues.append(_issue(ERROR, "not_a_section", section="concept"))
        else:
            _unknown_keys("concept", concept, SECTIONS["concept"], issues)
            for index, entry in enumerate(concept.get("phases") or [], 1):
                phase = _titled(f"concept.phases[{index}]", entry, issues)
                if phase:
                    phases.append(phase)
            if len(phases) > missions:
                issues.append(_issue(ERROR, "too_many_phases", count=len(phases), missions=missions))
            if "attention" in concept:
                texts["concept"] = {"attention": _paragraphs("concept.attention", concept["attention"], issues)}

    pages: dict[int, MissionPage] = {}
    raw_missions = raw.get("missions") or {}
    if not isinstance(raw_missions, dict):
        issues.append(_issue(ERROR, "not_a_section", section="missions"))
        raw_missions = {}
    for number, page in raw_missions.items():
        if not isinstance(number, int) or not 1 <= number <= missions:
            issues.append(_issue(ERROR, "mission_out_of_range", mission=number, missions=missions))
            continue
        if not isinstance(page, dict) or not isinstance(page.get("title"), str):
            issues.append(_issue(ERROR, "not_titled", section=f"missions.{number}"))
            continue
        tasks = [_titled(f"missions.{number}.tasks[{i}]", task, issues) for i, task in enumerate(page.get("tasks") or [], 1)]
        pages[number] = MissionPage(page["title"].strip(), tuple(task for task in tasks if task))
    if coming not in pages:
        issues.append(_issue(WARNING, "no_mission_page", mission=coming))

    if any(issue.level == ERROR for issue in issues):
        return None, issues
    return (
        BriefingProse(
            operation=names.get("operation"),
            subtitle=names.get("subtitle"),
            texts=texts,
            phases=tuple(phases),
            missions=pages,
        ),
        issues,
    )


def load_prose(folder: Path, missions: int, coming: int) -> tuple[BriefingProse | None, list[ValidationIssue]]:
    """Read the campaign folder's `briefing.yaml`, if it has one.

    Args:
        folder: The campaign folder.
        missions: The campaign's mission count.
        coming: The mission the briefing is for.

    Returns:
        The prose — ``None`` when the file is missing (no issue then) or has an error — and every
        issue found.
    """
    path = folder / PROSE_FILE
    if not path.is_file():
        return None, []
    try:
        raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as error:
        return None, [_issue(ERROR, "unreadable", path=path, error=error)]
    return parse_prose(raw, missions, coming)
