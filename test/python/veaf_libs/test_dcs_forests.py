"""Tests for the forest reader of DCS ``.surface5`` map files (FEAT-FOREST-CHECK).

The fixtures are built here, byte by byte, in the layout measured on Syria's 30 GB file: a header
whose u64 at offset 8 is where the data pool starts, nodes opened by a 4x4 matrix, ``Trees`` meshes
whose ``baseIndex`` points into the node's ``Pbase``.
"""

from __future__ import annotations

import struct
from dataclasses import dataclass, field
from pathlib import Path

import pytest
from veaf_libs.dcs_forests import (
    SurfaceForests,
    SurfaceFormatError,
    find_surface_file,
    surface_file_for_theatre,
)


@dataclass
class TreesMesh:
    """An overlay mesh, a forest by default: indices into the node's base vertices, and triangles over them.

    ``priority`` is the draw order written after the material; ``uvw_size`` the element size of its
    ``parametricUVW`` (4, a texture index; 12, a road's offsets; ``None``, no such array).
    """

    base_index: list[int]
    triangles: list[tuple[int, int, int]]
    shader: bytes = b"Simple5.1"
    kind: bytes = b"Trees"
    priority: int = 0x5D
    uvw_size: int | None = 4


@dataclass
class Node:
    """A node of the file: its origin, its base vertices (local), its forest meshes."""

    origin: tuple[float, float]
    vertices: list[tuple[float, float, float]]
    trees: list[TreesMesh] = field(default_factory=list)


class _Builder:
    def __init__(self) -> None:
        self.meta = bytearray()
        self.pool = bytearray()

    def array(self, name: bytes, type_code: int, elem_size: int, payload: bytes, more: bool = True) -> None:
        while len(self.pool) % 8:
            self.pool += b"\0"
        offset = len(self.pool)
        self.pool += payload
        self.meta += struct.pack("<I", len(name)) + name
        self.meta += struct.pack("<HHIQ", type_code, elem_size, 0, len(payload))
        self.meta += offset.to_bytes(6, "little")
        self.meta += struct.pack("<I", 1 if more else 0)


def build_surface(nodes: list[Node], *, decl_table: bool = False) -> bytes:
    """Write a minimal ``.surface5`` holding *nodes*, in the layout measured on Syria."""
    b = _Builder()
    b.meta += struct.pack("<II", 5, 4) + bytes(16)
    for node in nodes:
        ox, oz = node.origin
        b.meta += struct.pack("<16f", 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, ox, 0, oz, 1)
        b.meta += bytes(8)
        for mesh in node.trees:
            count = len(mesh.base_index)
            b.meta += struct.pack("<IIII", 2, count, 6, 1)
            b.array(b"baseIndex", 4, 4, struct.pack(f"<{count}I", *mesh.base_index))
            if mesh.uvw_size is not None:
                b.array(b"parametricUVW", 4 if mesh.uvw_size == 4 else 2, mesh.uvw_size, bytes(mesh.uvw_size * count))
            b.array(b"offset", 0, 4, struct.pack(f"<{count}f", *([1.0] * count)))
            b.array(b"materialParamsIndex", 4, 4, bytes(4 * count))
            flat = [i for tri in mesh.triangles for i in tri]
            b.array(b"TRI", 6, 12, struct.pack(f"<{len(flat)}I", *flat), more=False)
            b.meta += b"\xfb\xff\x00\x00\x02\x00\x00\x00"
            b.meta += struct.pack("<I", len(mesh.shader)) + mesh.shader + struct.pack("<I", len(mesh.kind)) + mesh.kind
            used = [node.vertices[i] for i in mesh.base_index if i < len(node.vertices)]
            lo = [min(v[k] for v in used) for k in range(3)]
            hi = [max(v[k] for v in used) for k in range(3)]
            b.meta += struct.pack("<III", 0, mesh.priority, 1) + b"\xff\x02" + struct.pack("<6f", *lo, *hi)
            b.meta += struct.pack("<I", 1) + b"\0"
        flat_v = [c for v in node.vertices for c in v]
        b.meta += struct.pack("<IIII", 2, len(node.vertices), 1, 1)
        b.array(b"Pbase", 2, 12, struct.pack(f"<{len(flat_v)}f", *flat_v), more=False)
    if decl_table:
        # The material table at the end of the real file names the shader too, with no mesh before it.
        b.meta += bytes(64) + struct.pack("<I", 9) + b"Simple5.1" + struct.pack("<I", 5) + b"Trees"
        b.meta += struct.pack("<I", 3) + bytes(32)
    header = bytearray(struct.pack("<II", 2, 0x30) + bytes(8) + bytes(16))
    header += struct.pack("<I", 0x18) + b"landscape5::Surface5File"
    pool_start = len(header) + len(b.meta)
    struct.pack_into("<Q", header, 8, pool_start)
    return bytes(header) + bytes(b.meta) + bytes(b.pool)


# A 1 km square forest at node origin (10000, 20000): local x 100..1100, z 200..1200.
SQUARE = Node(
    origin=(10000.0, 20000.0),
    vertices=[(0.0, 0.0, 0.0), (100.0, 5.0, 200.0), (1100.0, 5.0, 200.0), (1100.0, 5.0, 1200.0), (100.0, 5.0, 1200.0)],
    trees=[TreesMesh(base_index=[1, 2, 3, 4], triangles=[(0, 1, 2), (0, 2, 3)])],
)


def _write(tmp_path: Path, nodes: list[Node], **kwargs: bool) -> Path:
    path = tmp_path / "Test.surface5"
    path.write_bytes(build_surface(nodes, **kwargs))
    return path


def test_a_point_inside_the_forest_is_in_forest(tmp_path: Path) -> None:
    with SurfaceForests(_write(tmp_path, [SQUARE])) as forests:
        assert forests.in_forest(10600.0, 20700.0)


@pytest.mark.parametrize(
    ("x", "y"),
    [
        (10050.0, 20700.0),  # west of the square
        (10600.0, 21300.0),  # north in mission y, beyond the far edge
        (10600.0, 20100.0),  # before the near edge
        (20000.0, 10000.0),  # x and y swapped: proves the axes are not
    ],
)
def test_a_point_outside_the_forest_is_not(tmp_path: Path, x: float, y: float) -> None:
    with SurfaceForests(_write(tmp_path, [SQUARE])) as forests:
        assert not forests.in_forest(x, y)


def test_the_mission_y_axis_is_the_engine_z_axis(tmp_path: Path) -> None:
    """A thin strip along local z: only a point placed by mission y = origin z + local z falls in it."""
    strip = Node(
        origin=(0.0, 0.0),
        vertices=[(0.0, 0.0, 0.0), (0.0, 0.0, 5000.0), (10.0, 0.0, 5000.0), (10.0, 0.0, 0.0)],
        trees=[TreesMesh(base_index=[0, 1, 2, 3], triangles=[(0, 1, 2), (0, 2, 3)])],
    )
    with SurfaceForests(_write(tmp_path, [strip])) as forests:
        assert forests.in_forest(5.0, 4000.0)
        assert not forests.in_forest(4000.0, 5.0)


def test_each_node_uses_its_own_origin_and_vertices(tmp_path: Path) -> None:
    other = Node(
        origin=(-50000.0, -80000.0),
        vertices=[(0.0, 0.0, 0.0), (0.0, 0.0, 100.0), (100.0, 0.0, 100.0)],
        trees=[TreesMesh(base_index=[0, 1, 2], triangles=[(0, 1, 2)])],
    )
    with SurfaceForests(_write(tmp_path, [SQUARE, other])) as forests:
        assert forests.mesh_count == 2
        assert forests.in_forest(-49990.0, -79950.0)
        assert forests.in_forest(10600.0, 20700.0)
        assert not forests.in_forest(-49950.0, -79990.0)  # the other half of that square


@pytest.mark.parametrize(
    ("shader", "kind"),
    [(b"Simple5.1", b"Trees"), (b"CaucasusSimple5.1", b"Forest"), (b"HardSplat5.1", b"Forest")],
)
def test_every_forest_material_measured_is_read(tmp_path: Path, shader: bytes, kind: bytes) -> None:
    """Syria and Afghanistan say ``Trees``; Caucasus, Normandy, Germany and the others say ``Forest``."""
    square = Node(
        origin=SQUARE.origin,
        vertices=SQUARE.vertices,
        trees=[TreesMesh(base_index=[1, 2, 3, 4], triangles=[(0, 1, 2), (0, 2, 3)], shader=shader, kind=kind)],
    )
    with SurfaceForests(_write(tmp_path, [square])) as forests:
        assert forests.in_forest(10600.0, 20700.0)


def test_another_kind_of_mesh_is_not_a_forest(tmp_path: Path) -> None:
    field = Node(
        origin=SQUARE.origin,
        vertices=SQUARE.vertices,
        trees=[TreesMesh(base_index=[1, 2, 3, 4], triangles=[(0, 1, 2), (0, 2, 3)], kind=b"Field")],
    )
    with SurfaceForests(_write(tmp_path, [field])) as forests:
        assert forests.mesh_count == 0
        assert not forests.in_forest(10600.0, 20700.0)


def test_the_material_table_is_not_a_mesh(tmp_path: Path) -> None:
    with SurfaceForests(_write(tmp_path, [SQUARE], decl_table=True)) as forests:
        assert forests.mesh_count == 1


def test_a_file_with_no_forest_answers_no(tmp_path: Path) -> None:
    bare = Node(origin=(0.0, 0.0), vertices=[(0.0, 0.0, 0.0)])
    with SurfaceForests(_write(tmp_path, [bare])) as forests:
        assert forests.mesh_count == 0
        assert not forests.in_forest(0.0, 0.0)


def test_a_triangle_past_its_vertices_is_refused(tmp_path: Path) -> None:
    broken = Node(
        origin=(0.0, 0.0),
        vertices=SQUARE.vertices,
        trees=[TreesMesh(base_index=[1, 2, 3], triangles=[(0, 1, 5)])],
    )
    with SurfaceForests(_write(tmp_path, [broken])) as forests, pytest.raises(SurfaceFormatError, match="TRI"):
        forests.in_forest(500.0, 500.0)


def test_a_base_index_past_the_node_vertices_is_refused(tmp_path: Path) -> None:
    broken = Node(
        origin=(0.0, 0.0),
        vertices=SQUARE.vertices,
        trees=[TreesMesh(base_index=[1, 2, 3, 9], triangles=[(0, 1, 2)])],
    )
    with SurfaceForests(_write(tmp_path, [broken])) as forests, pytest.raises(SurfaceFormatError, match="baseIndex"):
        forests.in_forest(500.0, 500.0)


def test_a_file_that_is_not_a_surface5_is_refused(tmp_path: Path) -> None:
    path = tmp_path / "Other.surface5"
    path.write_bytes(b"\0" * 256)
    with pytest.raises(SurfaceFormatError, match="Surface5File"):
        SurfaceForests(path)


def _install(tmp_path: Path, folder: str, stem: str, declared_id: str | None = None) -> Path:
    terrain = tmp_path / "DCS" / "Mods" / "terrains" / folder
    (terrain / "surface").mkdir(parents=True)
    (terrain / "surface" / f"{stem}.surface5").write_bytes(b"")
    if declared_id is not None:
        # The two lines of a real entry.lua that name the theatre (GermanyColdWar's, 2026-11-16).
        (terrain / "entry.lua").write_text(
            f'theatre =\n{{\n\t[\'id\'] = "{declared_id}";\n}}\nlocal self_ID = "{declared_id}";\n', encoding="utf-8"
        )
    return tmp_path / "DCS"


@pytest.mark.parametrize(
    ("theatre", "folder", "stem", "declared_id"),
    [
        ("Syria", "Syria", "Syria", "Syria"),
        ("GermanyCW", "GermanyColdWar", "GermanyColdWar", "GermanyCW"),  # only entry.lua says GermanyCW
        ("MarianaIslandsWWII", "MarianasWWII", "MarianasWWII", "MarianaIslandsWWII"),
        ("SinaiMap", "Sinai", "SinaiMap", None),  # no entry.lua: the file name
        ("Normandy", "Normandy", "Normandy1944s", None),  # no entry.lua: the folder name
        ("syria", "Syria", "Syria", "Syria"),
    ],
)
def test_the_surface_file_is_found_by_declared_id_folder_or_file_name(
    tmp_path: Path, theatre: str, folder: str, stem: str, declared_id: str | None
) -> None:
    dcs = _install(tmp_path, folder, stem, declared_id)
    assert find_surface_file(dcs, theatre) == dcs / "Mods" / "terrains" / folder / "surface" / f"{stem}.surface5"


@pytest.mark.parametrize("theatre", ["Caucasus", ""])
def test_a_theatre_not_installed_has_no_surface_file(tmp_path: Path, theatre: str) -> None:
    dcs = _install(tmp_path, "Syria", "Syria")  # no entry.lua: its declared id is unknown, not ""
    assert find_surface_file(dcs, theatre) is None


def test_the_install_comes_from_the_registry_when_not_given(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    dcs = _install(tmp_path, "Syria", "Syria")
    monkeypatch.setattr("veaf_libs.dcs_forests.registered_dcs_dirs", lambda: [tmp_path / "missing", dcs])
    assert surface_file_for_theatre("Syria") == find_surface_file(dcs, "Syria")


def test_no_install_found_says_where_it_looked(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("veaf_libs.dcs_forests.registered_dcs_dirs", list)
    with pytest.raises(FileNotFoundError, match="--dcs-dir"):
        surface_file_for_theatre("Syria")


def _forest_mission(tmp_path: Path) -> tuple[Path, Path]:
    """A Caucasus mission with one group in the square forest, one out of it, and a marker in it."""
    from mission_tools.miz_tools import create_miz  # noqa: PLC0415
    from veaf_libs.blank_mission import generate_blank_mission  # noqa: PLC0415
    from veaf_mission_mcp.add_group import add_group  # noqa: PLC0415

    dcs = _install(tmp_path, "Caucasus", "Caucasus")
    surface = dcs / "Mods" / "terrains" / "Caucasus" / "surface" / "Caucasus.surface5"
    surface.write_bytes(build_surface([SQUARE]))
    miz = create_miz(tmp_path / "m.miz", generate_blank_mission("Caucasus"))
    common = {"coalition": "red", "country_id": 0, "country_name": "Russia", "category": "vehicle"}
    add_group(
        miz,
        name="in-the-wood",
        position={"x": 10600, "y": 20700},
        units=[{"type": "BTR-80", "count": 2}],
        keep_position=True,
        **common,
    )
    add_group(
        miz,
        name="in-the-open",
        position={"x": 15000, "y": 20700},
        units=[{"type": "BTR-80", "count": 3}],
        keep_position=True,
        **common,
    )
    add_group(
        miz,
        name="marker",
        position={"x": 10600, "y": 20700},
        units=[{"type": "Soldier M4", "name": '#command="-sa10"'}],
        keep_position=True,
        **common,
    )
    return miz, dcs


def test_the_mission_check_lists_the_vehicles_in_a_forest(tmp_path: Path) -> None:
    from veaf_libs.dcs_forests import check_mission_forests  # noqa: PLC0415

    miz, dcs = _forest_mission(tmp_path)
    report = check_mission_forests(miz, dcs)
    assert report.theatre == "Caucasus"
    assert report.units_checked == 5
    assert report.groups == {"in-the-wood": 2}
    assert report.markers_skipped == 1
    assert report.to_dict()["units_in_forest"] == 2


def test_a_flat_triangle_covers_nothing(tmp_path: Path) -> None:
    """Three equal corners make every sign test zero: such a triangle must not claim its whole cell."""
    flat = Node(
        origin=(0.0, 0.0),
        vertices=[(100.0, 0.0, 100.0), (100.0, 0.0, 100.0), (100.0, 0.0, 100.0), (120.0, 0.0, 100.0)],
        trees=[TreesMesh(base_index=[0, 1, 2, 3], triangles=[(0, 1, 2), (0, 3, 3)])],
    )
    with SurfaceForests(_write(tmp_path, [flat])) as forests:
        assert not forests.in_forest(100.0, 100.0)
        assert not forests.in_forest(110.0, 100.0)


# A 400 m square clearing in the middle of SQUARE (local x 400..800, z 500..900), on the same node.
_CLEARING_VERTICES = [
    *SQUARE.vertices,
    (400.0, 5.0, 500.0),
    (800.0, 5.0, 500.0),
    (800.0, 5.0, 900.0),
    (400.0, 5.0, 900.0),
]


def _forest_and_clearing(**clearing: object) -> Node:
    overlay = TreesMesh(base_index=[5, 6, 7, 8], triangles=[(0, 1, 2), (0, 2, 3)], **clearing)  # type: ignore[arg-type]
    return Node(origin=SQUARE.origin, vertices=_CLEARING_VERTICES, trees=[*SQUARE.trees, overlay])


def test_an_overlay_drawn_above_the_forest_clears_it(tmp_path: Path) -> None:
    """Agana on Marianas WWII: the airfield (Runway, 103) is drawn over a forest texture (Forest, 49)."""
    node = _forest_and_clearing(shader=b"SplatmapUnique5.1", kind=b"Runway", priority=0x5D + 10, uvw_size=None)
    with SurfaceForests(_write(tmp_path, [node])) as forests:
        assert not forests.in_forest(10600.0, 20700.0)  # in the clearing
        assert forests.in_forest(10200.0, 20300.0)  # in the forest around it
        assert forests.mesh_count == 1


@pytest.mark.parametrize(
    "clearing",
    [
        {"kind": b"Field", "priority": 0x5D - 10},  # drawn below the forest: the trees win
        {"kind": b"Field", "priority": 0x5D},  # a tie: the forest is kept
        {"kind": b"Road", "priority": 0x5D + 10, "uvw_size": 12},  # offsets from the base vertices: not read
    ],
)
def test_an_overlay_that_does_not_cover_the_forest_leaves_it(tmp_path: Path, clearing: dict[str, object]) -> None:
    with SurfaceForests(_write(tmp_path, [_forest_and_clearing(**clearing)])) as forests:
        assert forests.in_forest(10600.0, 20700.0)


def test_a_higher_forest_over_a_field_is_still_a_forest(tmp_path: Path) -> None:
    """Two forests at a point: the highest one is compared with what lies above it, not the lowest."""
    node = _forest_and_clearing(kind=b"Field", priority=0x5D + 10)
    node.trees.append(
        TreesMesh(base_index=[5, 6, 7, 8], triangles=[(0, 1, 2), (0, 2, 3)], kind=b"Forest", priority=0x5D + 20)
    )
    with SurfaceForests(_write(tmp_path, [node])) as forests:
        assert forests.in_forest(10600.0, 20700.0)
