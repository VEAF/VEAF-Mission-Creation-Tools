"""Assemble the *map capture kit* — the zip handed to helpers to collect map data.

The kit lets a non-developer capture a theatre's airbases with no source checkout,
Python or Poetry (see ``doc/developer/capture-airbases.md``). It bundles:

- ``veaf-tools.exe`` — carries ``capture-map`` / ``inject-bridge``.
- ``dcs-serve.exe`` — the bridge server, taken from a VEAF-dcs-bridge release zip.
- ``missions/bridge-<Theatre>.miz`` — ready-to-run bridge missions, generated here
  **without DCS** (blank mission + bridge trigger) for every supported theatre.
- ``PROCEDURE.md`` — the step-by-step guide.

No ``dcs-serve.yaml`` is shipped: ``dcs-serve`` writes one (with a freshly generated
``api_key``) on first launch, and ``capture-map`` reads the key from it automatically —
so no secret is ever baked into a public release artifact.

Used by the release workflow; runs on any OS (it only zips files).
"""

from __future__ import annotations

import shutil
import tempfile
import zipfile
from pathlib import Path

MISSIONS_SUBDIR = "missions"


def build_bridge_mission(theatre: str, out_miz: Path, bridge_lua: Path) -> Path:
    """Generate a ready-to-run bridge mission ``.miz`` for *theatre*, without DCS.

    A blank mission is synthesized in memory, zipped as a ``.miz``, then the
    ``dcs-bridge.lua`` load trigger is injected into it.

    Args:
        theatre: DCS theatre name (must be supported by ``blank_mission``).
        out_miz: Destination ``.miz`` path (parent directories are created).
        bridge_lua: Local ``dcs-bridge.lua`` to embed.

    Returns:
        The written ``.miz`` path.
    """
    from veaf_libs.blank_mission import generate_blank_mission  # noqa: PLC0415
    from veaf_libs.dcs_bridge_capture import inject_bridge  # noqa: PLC0415

    out_miz.parent.mkdir(parents=True, exist_ok=True)
    members = generate_blank_mission(theatre)
    # Build + inject inside a scratch dir: the injection helper writes a timestamped
    # backup next to its target, which must not end up shipped in the kit.
    with tempfile.TemporaryDirectory() as tmp:
        staged = Path(tmp) / out_miz.name
        with zipfile.ZipFile(staged, "w", compression=zipfile.ZIP_DEFLATED) as zf:
            for member_path, content in members.items():
                zf.writestr(member_path, content)
        inject_bridge(staged, bridge_lua)
        shutil.move(str(staged), out_miz)
    return out_miz


def build_bridge_missions(out_dir: Path, bridge_lua: Path, theatres: list[str] | None = None) -> list[Path]:
    """Generate one bridge mission per supported theatre.

    Args:
        out_dir: Directory to write the ``bridge-<Theatre>.miz`` files into.
        bridge_lua: Local ``dcs-bridge.lua`` to embed.
        theatres: Theatres to generate. Defaults to every supported theatre.

    Returns:
        The written ``.miz`` paths, sorted by theatre.
    """
    from veaf_libs.blank_mission import supported_theatres  # noqa: PLC0415

    names = theatres if theatres is not None else supported_theatres()
    return [build_bridge_mission(t, out_dir / f"bridge-{t}.miz", bridge_lua) for t in sorted(names)]


def _extract_member(bridge_zip: Path, basename: str, dest_dir: Path) -> Path | None:
    """Extract a zip member by basename (case-insensitive); return ``None`` if absent."""
    dest_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(bridge_zip) as zf:
        member = next((n for n in zf.namelist() if Path(n).name.lower() == basename.lower()), None)
        if member is None:
            return None
        out = dest_dir / basename
        with zf.open(member) as src, open(out, "wb") as dst:
            shutil.copyfileobj(src, dst)
    return out


def extract_dcs_serve(bridge_zip: Path, dest_dir: Path) -> Path:
    """Extract ``dcs-serve.exe`` from a VEAF-dcs-bridge release zip.

    Args:
        bridge_zip: The ``dcs-bridge-<version>.zip`` release asset.
        dest_dir: Directory to extract the executable into.

    Returns:
        Path to the extracted ``dcs-serve.exe``.

    Raises:
        RuntimeError: If the zip carries no ``dcs-serve.exe``.
    """
    out = _extract_member(bridge_zip, "dcs-serve.exe", dest_dir)
    if out is None:
        raise RuntimeError(f"no dcs-serve.exe inside {bridge_zip.name}")
    return out


def extract_bridge_lua(bridge_zip: Path, dest_dir: Path) -> Path | None:
    """Extract ``dcs-bridge.lua`` from a release zip, so the kit's missions match its server.

    Args:
        bridge_zip: The ``dcs-bridge-<version>.zip`` release asset.
        dest_dir: Directory to extract into.

    Returns:
        Path to the extracted Lua, or ``None`` when the zip does not carry it (the caller
        then falls back to downloading the published script).
    """
    return _extract_member(bridge_zip, "dcs-bridge.lua", dest_dir)


def assemble_kit(
    staging_dir: Path,
    zip_path: Path,
    *,
    veaf_tools_exe: Path,
    procedure_md: Path,
    bridge_lua: Path,
    bridge_zip: Path | None = None,
) -> Path:
    """Stage every kit file and zip it.

    Args:
        staging_dir: Working directory the kit tree is laid out in (created/emptied).
        zip_path: Destination zip.
        veaf_tools_exe: The built ``veaf-tools`` executable.
        procedure_md: The helper procedure to ship as ``PROCEDURE.md``.
        bridge_lua: ``dcs-bridge.lua`` used to build the bridge missions.
        bridge_zip: Optional VEAF-dcs-bridge release zip to take ``dcs-serve.exe`` from.
            When absent, the kit ships without the server (the procedure then points to
            the bridge release page).

    Returns:
        The written zip path.
    """
    if staging_dir.exists():
        shutil.rmtree(staging_dir)
    staging_dir.mkdir(parents=True)

    shutil.copy2(veaf_tools_exe, staging_dir / veaf_tools_exe.name)
    shutil.copy2(procedure_md, staging_dir / "PROCEDURE.md")
    if bridge_zip is not None:
        extract_dcs_serve(bridge_zip, staging_dir)
    build_bridge_missions(staging_dir / MISSIONS_SUBDIR, bridge_lua)

    zip_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for path in sorted(staging_dir.rglob("*")):
            if path.is_file():
                zf.write(path, path.relative_to(staging_dir).as_posix())
    return zip_path
