"""Tests for veaf_libs.ai_clients.setup_cherry — the VEAF server in Cherry Studio's database (FEAT-CHERRY-AI-SETUP).

Every database here is built in `tmp_path` from the schema of Cherry Studio 2.2.3 (`data/`), never from a
real installation.
"""

import json
import shutil
import sqlite3
import subprocess
from pathlib import Path
from typing import Any

import pytest
from veaf_libs import ai_clients
from veaf_libs.ai_clients import (
    CHERRY_SERVER_NAME,
    cherry_is_running,
    setup_all,
    setup_cherry,
)

SCHEMA = (Path(__file__).parent / "data" / "cherry-studio-2.2.3-schema.sql").read_text(encoding="utf-8")
EXE = Path(r"C:\VEAF\veaf-tools.exe")
NOW = 1_800_000_000.0  # seconds; Cherry stores milliseconds
MISSIONS_ID = "a-missions"


def _closed(_user_data: Path) -> bool:
    return False


def _open(_user_data: Path) -> bool:
    return True


def _user_data(tmp_path: Path) -> Path:
    return tmp_path / "Roaming" / "CherryStudio"


def _db(tmp_path: Path) -> Path:
    return _user_data(tmp_path) / "Data" / "cherrystudio.sqlite"


def _make_cherry(
    tmp_path: Path, *, veaf_rows: int = 1, schema: str = SCHEMA, env: str | None = '{"FOO":"1"}', other: bool = True
) -> Path:
    """Build a Cherry 2.2.3 database shaped like the starting backup the friends restore."""
    db = _db(tmp_path)
    db.parent.mkdir(parents=True)
    con = sqlite3.connect(db)
    con.executescript(schema)
    con.execute("PRAGMA journal_mode=WAL")
    for assistant_id, name, deleted in (
        (MISSIONS_ID, "VEAF missions", None),
        ("a-chatbot", "VEAF chatbot", None),
        ("a-cheri", "Chéri", None),
        ("a-gone", "Old one", 1),
    ):
        con.execute(
            "INSERT INTO assistant (id, name, emoji, settings, order_key, created_at, updated_at, deleted_at)"
            " VALUES (?, ?, '🙂', '{}', 'a0', 1, 1, ?)",
            (assistant_id, name, deleted),
        )
    if other:
        con.execute(
            "INSERT INTO mcp_server (id, name, type, command, args, env, is_active, created_at, updated_at)"
            " VALUES ('s-other', 'fetch', 'stdio', 'uvx', '[\"mcp-server-fetch\"]', '{}', 1, 1, 1)"
        )
    for i in range(veaf_rows):
        con.execute(
            "INSERT INTO mcp_server (id, name, type, command, args, env, is_active, install_source, is_trusted,"
            " created_at, updated_at) VALUES (?, ?, 'stdio', 'C:/old/veaf-tools.exe', '[\"mcp\"]', ?, 1, 'manual',"
            " 1, 5, 5)",
            (f"s-veaf-{i}", CHERRY_SERVER_NAME, env),
        )
    if veaf_rows:
        con.execute(
            "INSERT INTO assistant_mcp_server (assistant_id, mcp_server_id, created_at, updated_at)"
            " VALUES (?, 's-veaf-0', 5, 5)",
            (MISSIONS_ID,),
        )
    con.commit()
    con.close()
    return db


def _rows(db: Path, sql: str) -> list[tuple[Any, ...]]:
    con = sqlite3.connect(db)
    try:
        return con.execute(sql).fetchall()
    finally:
        con.close()


def _veaf(db: Path) -> dict[str, Any]:
    con = sqlite3.connect(db)
    con.row_factory = sqlite3.Row
    try:
        rows = con.execute("SELECT * FROM mcp_server WHERE name = ?", (CHERRY_SERVER_NAME,)).fetchall()
    finally:
        con.close()
    assert len(rows) == 1
    return dict(rows[0])


def _links(db: Path) -> set[tuple[str, str]]:
    return {(a, s) for a, s in _rows(db, "SELECT assistant_id, mcp_server_id FROM assistant_mcp_server")}


def _backups(db: Path) -> list[Path]:
    return sorted(db.parent.glob(f"{db.name}.veaf-backup-*"))


def _setup(tmp_path: Path, **kwargs: Any) -> ai_clients.ClientResult:
    kwargs.setdefault("is_running", _closed)
    return setup_cherry(EXE, appdata=tmp_path / "Roaming", home=tmp_path / "home", clock=lambda: NOW, **kwargs)


def test_cherry_absent_is_not_found(tmp_path: Path) -> None:
    assert _setup(tmp_path).status == "not_found"


def test_the_existing_veaf_server_gets_the_exe_and_the_compact_profile(tmp_path: Path) -> None:
    db = _make_cherry(tmp_path)

    result = _setup(tmp_path)

    assert result.status == "configured", result.detail
    veaf = _veaf(db)
    assert veaf["id"] == "s-veaf-0"
    assert veaf["command"] == str(EXE)
    assert veaf["args"] == '["mcp"]'
    assert json.loads(veaf["env"]) == {"FOO": "1", "VEAF_MCP_PROFILE": "compact"}
    assert veaf["updated_at"] == int(NOW * 1000)
    assert veaf["created_at"] == 5


def test_links_and_other_servers_are_left_alone(tmp_path: Path) -> None:
    db = _make_cherry(tmp_path)
    others = _rows(db, "SELECT * FROM mcp_server WHERE name <> 'veaf'")
    assistants = _rows(db, "SELECT * FROM assistant")

    _setup(tmp_path)

    assert _links(db) == {(MISSIONS_ID, "s-veaf-0")}
    assert _rows(db, "SELECT * FROM mcp_server WHERE name <> 'veaf'") == others
    assert _rows(db, "SELECT * FROM assistant") == assistants


def test_without_a_veaf_server_one_is_created_and_linked_to_nobody(tmp_path: Path) -> None:
    db = _make_cherry(tmp_path, veaf_rows=0)

    result = _setup(tmp_path)

    assert result.status == "configured", result.detail
    veaf = _veaf(db)
    stamp = int(NOW * 1000)
    assert (veaf["type"], veaf["command"], veaf["args"]) == ("stdio", str(EXE), '["mcp"]')
    assert json.loads(veaf["env"]) == {"VEAF_MCP_PROFILE": "compact"}
    assert (veaf["is_active"], veaf["is_trusted"], veaf["install_source"]) == (1, 1, "manual")
    assert veaf["trusted_at"] == veaf["installed_at"] == veaf["created_at"] == veaf["updated_at"] == stamp
    assert len(veaf["id"]) == 36
    assert _links(db) == set()


def test_a_veaf_server_without_env_gets_the_profile(tmp_path: Path) -> None:
    db = _make_cherry(tmp_path, env=None)

    _setup(tmp_path)

    assert json.loads(_veaf(db)["env"]) == {"VEAF_MCP_PROFILE": "compact"}


def test_an_inactive_or_non_stdio_veaf_server_is_repaired_once(tmp_path: Path) -> None:
    """A server imported through Cherry's link is inactive; one of another type never runs the command."""
    db = _make_cherry(tmp_path)
    con = sqlite3.connect(db)
    con.execute("UPDATE mcp_server SET is_active = 0, type = 'sse', install_source = 'protocol' WHERE name = 'veaf'")
    con.commit()
    con.close()

    first = _setup(tmp_path)
    after_first = _rows(db, "SELECT * FROM mcp_server ORDER BY id")
    backups = _backups(db)
    second = setup_cherry(
        EXE, appdata=tmp_path / "Roaming", home=tmp_path / "home", is_running=_closed, clock=lambda: NOW + 60
    )

    assert first.status == second.status == "configured"
    veaf = _veaf(db)
    assert (veaf["type"], veaf["is_active"], veaf["command"]) == ("stdio", 1, str(EXE))
    assert _rows(db, "SELECT * FROM mcp_server ORDER BY id") == after_first
    assert _backups(db) == backups


def test_running_twice_changes_nothing_the_second_time(tmp_path: Path) -> None:
    db = _make_cherry(tmp_path)
    _setup(tmp_path)
    before = _rows(db, "SELECT * FROM mcp_server ORDER BY id")
    backups = _backups(db)

    result = setup_cherry(
        EXE, appdata=tmp_path / "Roaming", home=tmp_path / "home", is_running=_closed, clock=lambda: NOW + 60
    )

    assert result.status == "configured", result.detail
    assert _rows(db, "SELECT * FROM mcp_server ORDER BY id") == before
    assert _backups(db) == backups


def test_the_database_is_backed_up_before_the_write(tmp_path: Path) -> None:
    db = _make_cherry(tmp_path)

    _setup(tmp_path)

    backups = _backups(db)
    assert len(backups) == 1
    assert _rows(backups[0], "SELECT command FROM mcp_server WHERE name = 'veaf'") == [("C:/old/veaf-tools.exe",)]


def test_cherry_open_is_refused_and_nothing_is_written(tmp_path: Path) -> None:
    db = _make_cherry(tmp_path)

    result = _setup(tmp_path, is_running=_open)

    assert result.status == "failed"
    assert "close Cherry Studio" in result.detail
    assert _veaf(db)["command"] == "C:/old/veaf-tools.exe"
    assert _backups(db) == []


def test_a_cherry_folder_without_database_is_refused(tmp_path: Path) -> None:
    _user_data(tmp_path).mkdir(parents=True)

    result = _setup(tmp_path)

    assert result.status == "failed"
    assert "cherrystudio.sqlite" in result.detail


@pytest.mark.parametrize(
    ("old", "new"),
    [
        ("\t`env` text,\n", ""),  # a column the write needs is gone
        ("\t`headers` text,\n", "\t`headers` text,\n\t`owner` text NOT NULL,\n"),  # a NOT NULL column it cannot fill
    ],
)
def test_an_unexpected_table_structure_is_refused_and_nothing_is_written(tmp_path: Path, old: str, new: str) -> None:
    assert old in SCHEMA
    db = _make_cherry(tmp_path, veaf_rows=0, schema=SCHEMA.replace(old, new, 1), other=False)

    result = _setup(tmp_path)

    assert result.status == "failed"
    assert "2.2.3" in result.detail
    assert _rows(db, "SELECT count(*) FROM mcp_server") == [(0,)]
    assert _backups(db) == []


def test_two_veaf_servers_are_refused(tmp_path: Path) -> None:
    db = _make_cherry(tmp_path, veaf_rows=2)

    result = _setup(tmp_path)

    assert result.status == "failed"
    assert _rows(db, "SELECT DISTINCT command FROM mcp_server WHERE name = 'veaf'") == [("C:/old/veaf-tools.exe",)]


def test_an_env_that_is_not_a_json_object_is_refused(tmp_path: Path) -> None:
    db = _make_cherry(tmp_path, env="not json")

    result = _setup(tmp_path)

    assert result.status == "failed"
    assert _veaf(db)["env"] == "not json"


def test_cherry_assistant_links_only_the_named_assistant(tmp_path: Path) -> None:
    db = _make_cherry(tmp_path)

    result = _setup(tmp_path, assistants=["VEAF chatbot", "VEAF missions"])

    assert result.status == "configured", result.detail
    assert _links(db) == {(MISSIONS_ID, "s-veaf-0"), ("a-chatbot", "s-veaf-0")}


def test_an_unknown_or_deleted_assistant_is_a_warning_not_an_error(tmp_path: Path) -> None:
    db = _make_cherry(tmp_path)

    result = _setup(tmp_path, assistants=["Nobody", "Old one"])

    assert result.status == "configured"
    assert "Nobody" in result.detail and "Old one" in result.detail
    assert _links(db) == {(MISSIONS_ID, "s-veaf-0")}


def test_a_relocated_user_data_folder_is_followed(tmp_path: Path) -> None:
    moved = tmp_path / "D" / "Cherry"
    _make_cherry(tmp_path)
    moved.parent.mkdir()
    _user_data(tmp_path).rename(moved)
    boot = tmp_path / "home" / ".cherrystudio" / "boot-config.json"
    boot.parent.mkdir(parents=True)
    boot.write_text(json.dumps({"app.user_data_path": {r"C:\Cherry Studio.exe": str(moved)}}), encoding="utf-8")

    result = _setup(tmp_path)

    assert result.status == "configured", result.detail
    assert _veaf(moved / "Data" / "cherrystudio.sqlite")["command"] == str(EXE)


def test_a_boot_config_with_two_folders_is_refused(tmp_path: Path) -> None:
    _make_cherry(tmp_path)
    boot = tmp_path / "home" / ".cherrystudio" / "boot-config.json"
    boot.parent.mkdir(parents=True)
    boot.write_text(json.dumps({"app.user_data_path": {"a.exe": str(tmp_path / "x"), "b.exe": str(tmp_path / "y")}}))

    result = _setup(tmp_path)

    assert result.status == "failed"
    assert "boot-config.json" in result.detail


def test_a_boot_config_without_relocation_keeps_the_default_folder(tmp_path: Path) -> None:
    db = _make_cherry(tmp_path)
    boot = tmp_path / "home" / ".cherrystudio" / "boot-config.json"
    boot.parent.mkdir(parents=True)
    boot.write_text(json.dumps({"app.language": "fr-FR"}))

    assert _setup(tmp_path).status == "configured"
    assert _veaf(db)["command"] == str(EXE)


def test_a_forced_data_folder_is_the_only_one_written(tmp_path: Path) -> None:
    default_db = _make_cherry(tmp_path)
    forced = tmp_path / "E" / "cherry-profile"
    shutil.copytree(_user_data(tmp_path), forced)
    boot = tmp_path / "home" / ".cherrystudio" / "boot-config.json"
    boot.parent.mkdir(parents=True)
    boot.write_text(json.dumps({"app.user_data_path": {"a.exe": str(tmp_path / "x"), "b.exe": str(tmp_path / "y")}}))

    result = _setup(tmp_path, data_dir=forced)

    assert result.status == "configured", result.detail
    assert _veaf(forced / "Data" / "cherrystudio.sqlite")["command"] == str(EXE)
    assert _veaf(default_db)["command"] == "C:/old/veaf-tools.exe"
    assert _backups(default_db) == []


@pytest.mark.parametrize("with_folder", [True, False])
def test_a_forced_data_folder_without_database_is_refused(tmp_path: Path, with_folder: bool) -> None:
    forced = tmp_path / "E" / "cherry-profile"
    if with_folder:
        forced.mkdir(parents=True)

    result = _setup(tmp_path, data_dir=forced)

    assert result.status == "failed"
    assert str(forced) in result.detail


def test_an_assistant_name_with_accents_spaces_and_a_dash_is_linked(tmp_path: Path) -> None:
    db = _make_cherry(tmp_path)
    con = sqlite3.connect(db)
    con.execute("UPDATE assistant SET name = 'VEAF - édition de mission' WHERE id = 'a-chatbot'")
    con.commit()
    con.close()

    result = _setup(tmp_path, assistants=["VEAF - édition de mission"])

    assert result.status == "configured", result.detail
    assert "not found" not in result.detail
    assert ("a-chatbot", "s-veaf-0") in _links(db)


def _no_process(*_a: Any, **_k: Any) -> subprocess.CompletedProcess[str]:
    return subprocess.CompletedProcess([], 0, stdout="INFO: No tasks are running.\n", stderr="")


def test_cherry_is_running_when_its_process_is_listed(tmp_path: Path) -> None:
    def tasklist(*_a: Any, **_k: Any) -> subprocess.CompletedProcess[str]:
        return subprocess.CompletedProcess(
            [], 0, stdout='"Cherry Studio.exe","4242","Console","1","200 K"\n', stderr=""
        )

    assert cherry_is_running(tmp_path, run=tasklist, windows=True)


def test_cherry_is_running_when_its_lockfile_is_locked(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    (tmp_path / "lockfile").write_text("")

    def locked(*_a: Any, **_k: Any) -> Any:
        raise PermissionError(13, "Permission denied")

    monkeypatch.setattr(Path, "open", locked)

    assert cherry_is_running(tmp_path, run=_no_process, windows=True)


def test_cherry_is_not_running_with_a_free_lockfile_and_no_process(tmp_path: Path) -> None:
    (tmp_path / "lockfile").write_text("")

    assert not cherry_is_running(tmp_path, run=_no_process, windows=True)


def test_a_process_list_that_cannot_be_read_counts_as_running(tmp_path: Path) -> None:
    def broken(*_a: Any, **_k: Any) -> subprocess.CompletedProcess[str]:
        raise OSError("tasklist missing")

    assert cherry_is_running(tmp_path, run=broken, windows=True)


def test_setup_all_passes_the_assistants_to_cherry_studio(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    # The other clients are stubbed: the real Claude Code one would run the `claude` found on this PC's PATH.
    for name in ("claude_desktop", "claude_code", "gemini", "antigravity", "codex", "opencode"):
        monkeypatch.setattr(
            ai_clients, f"setup_{name}", lambda *_a, _n=name, **_k: ai_clients.ClientResult(_n, "not_found")
        )
    seen: dict[str, Any] = {}

    def cherry(exe: Path, *, appdata: Path, home: Path, assistants: Any, data_dir: Any) -> ai_clients.ClientResult:
        seen.update(exe=exe, appdata=appdata, home=home, assistants=assistants, data_dir=data_dir)
        return ai_clients.ClientResult("Cherry Studio", "configured")

    monkeypatch.setattr(ai_clients, "setup_cherry", cherry)

    results = setup_all(
        EXE,
        home=tmp_path / "home",
        appdata=tmp_path / "Roaming",
        localappdata=tmp_path / "Local",
        cherry_assistants=["VEAF missions"],
        cherry_data_dir=tmp_path / "E",
    )

    assert results[-1].client == "Cherry Studio"
    assert seen == {
        "exe": EXE,
        "appdata": tmp_path / "Roaming",
        "home": tmp_path / "home",
        "assistants": ["VEAF missions"],
        "data_dir": tmp_path / "E",
    }
