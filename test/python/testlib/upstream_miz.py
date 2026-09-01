"""Build a synthetic upstream ``.miz`` shaped like a Foothold release.

Every `--update` test that existed was gated on a real Lekaa archive sitting at a hard-coded
path on one machine (``VEAF_TEST_FOOTHOLD_MIZ``). That file is on nobody's CI runner, so the
whole ``TestOtherMissionConverterIntegration`` class **skips** — which is how the defects of
`FIX-CONVERT-OTHER-UPDATE-BLIND-SPOTS` reached five real missions with a green suite behind them.
A skipped test and a passing one are indistinguishable in a summary line.

What matters for those tests is not Lekaa's actual content but the *shape* of a Foothold
release: scripts loaded by native triggers, some of them staged with ``c_time_after``, and a
release that renames one of them between versions. That shape fits in a few dozen lines here,
runs everywhere, and lets a test express "the upstream dropped this script" — which no fixture
of a single frozen archive can.
"""

from __future__ import annotations

import tempfile
import zipfile
from collections.abc import Mapping, Sequence
from pathlib import Path
from typing import Any

import luadata
from veaf_libs.dcs_countries import country_id_for_name

# One loader per script, as Foothold does: script name, and the staging delay in seconds
# (``None`` for "loads with the rest at t=0").
UpstreamScript = tuple[str, float | None]

#: Aircraft groups of a mission, as DCS files them:
#: ``{coalition: {country: {"plane"|"helicopter": [group table, …]}}}``.
UpstreamAircraft = Mapping[str, Mapping[str, Mapping[str, Sequence[dict[str, Any]]]]]

#: The five staged loaders of a Foothold release, AIEN last and latest — the case that matters,
#: since it inventories ground groups once and Foothold creates part of them from t=2 s.
FOOTHOLD_SHAPE: tuple[UpstreamScript, ...] = (
    ("Foothold Config.lua", None),
    ("zoneCommander.lua", None),
    ("Foothold CTLD.lua", 3.0),
    ("Zeus.lua", 3.0),
    ("AIEN.lua", 12.0),
)


def _trigrule(index: int, resource_key: str, delay: float | None) -> str:
    """Render one loader trigrule, with a ``c_time_after`` rule when it is staged."""
    rules = (
        ""
        if delay is None
        else f"""            ["rules"] =
            {{
                [1] =
                {{
                    ["predicate"] = "c_time_after",
                    ["seconds"] = {delay},
                }},
            }},
"""
    )
    return f"""        [{index}] =
        {{
            ["comment"] = "ScriptLoader {index}",
{rules}            ["actions"] =
            {{
                [1] =
                {{
                    ["predicate"] = "a_do_script_file",
                    ["file"] = "{resource_key}",
                }},
            }},
        }},
"""


def _coalition_block(aircraft: UpstreamAircraft) -> str:
    """Render the ``coalition`` entry of a mission table from *aircraft*.

    Args:
        aircraft: ``{coalition: {country: {"plane"|"helicopter": [group, …]}}}``.

    Returns:
        The Lua source of the ``["coalition"] = { … },`` entry, ready to be spliced into a
        ``mission`` table (indented one level, trailing comma included).
    """
    table = {
        coalition: {
            "country": [
                {
                    "name": country,
                    "id": country_id_for_name(country) or 0,
                    "plane": {"group": list(tables.get("plane", ()))},
                    "helicopter": {"group": list(tables.get("helicopter", ()))},
                }
                for country, tables in countries.items()
            ]
        }
        for coalition, countries in aircraft.items()
    }
    # luadata renders a bare table; indent it one level and hang it off the "coalition" key.
    body = "\n".join(f"    {line}" for line in luadata.serialize(table, indent="    ").splitlines())
    return f'    ["coalition"] =\n{body},\n'


def make_upstream_miz(
    scripts: Sequence[UpstreamScript] = FOOTHOLD_SHAPE,
    *,
    folder: Path | None = None,
    name: str = "upstream.miz",
    body: str = "-- upstream\n",
    theatre: str = "Caucasus",
    aircraft: UpstreamAircraft | None = None,
) -> Path:
    """Write a ``.miz`` whose native triggers load *scripts*, in order.

    Args:
        scripts: ``(filename, delay_seconds or None)`` pairs, in load order. The filenames land
            in ``l10n/DEFAULT/`` so the extractor copies them to ``src/scripts/``.
        folder: Where to write the archive (a fresh temporary folder by default).
        name: The archive's file name. Only cosmetic, but a release's name carries its version
            upstream and one ticket of this lot is precisely about that.
        body: The content given to every script, so a test can prove a refresh overwrote them.
        theatre: The DCS map, as ``mission`` declares it. Lekaa ships one archive per map, so
            this is what identifies which mission folder a release belongs to.
        aircraft: Aircraft groups to file under ``coalition``, keyed
            ``{coalition: {country: {"plane"|"helicopter": [group, …]}}}``. Omitted → no
            ``coalition`` table at all, as before.

    Returns:
        The path to the written ``.miz``.
    """
    folder = folder or Path(tempfile.mkdtemp())
    folder.mkdir(parents=True, exist_ok=True)
    miz = folder / name

    trigrules = "".join(_trigrule(i, f"ResKey_{i}", delay) for i, (_, delay) in enumerate(scripts, start=1))
    coalition = _coalition_block(aircraft) if aircraft else ""
    mission_lua = (
        f'mission =\n{{\n    ["theatre"] = "{theatre}",\n{coalition}'
        f'    ["trigrules"] =\n    {{\n{trigrules}    }},\n}}\n'
    )

    resources = "".join(f'    ["ResKey_{i}"] = "{script}",\n' for i, (script, _) in enumerate(scripts, start=1))
    map_resource_lua = f"mapResource =\n{{\n{resources}}}\n"

    with zipfile.ZipFile(miz, "w") as archive:
        archive.writestr("mission", mission_lua)
        archive.writestr("options", "options = {}")
        archive.writestr("warehouses", "warehouses = {}")
        archive.writestr("l10n/DEFAULT/dictionary", "dictionary = {}")
        archive.writestr("l10n/DEFAULT/mapResource", map_resource_lua)
        for script, _ in scripts:
            archive.writestr(f"l10n/DEFAULT/{script}", body)
    return miz


def make_release_zip(miz: Path, *, name: str) -> Path:
    """Wrap *miz* in a release ``.zip``, the way Lekaa publishes one.

    The archive's name carries the version (``Foothold_CA_4.7.0_…``) while the VEAF mission
    folders are named after the map, which is the whole subject of ticket 04.

    Args:
        miz: The mission to wrap.
        name: The archive file name, written beside *miz*.

    Returns:
        The path to the written ``.zip``.
    """
    release = miz.parent / name
    with zipfile.ZipFile(release, "w") as archive:
        archive.write(miz, arcname=miz.name)
    return release
