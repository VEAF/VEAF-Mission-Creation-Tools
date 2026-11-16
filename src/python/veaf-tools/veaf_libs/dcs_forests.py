"""Where a DCS map has forests, read from its map files, without the game (FEAT-FOREST-CHECK).

DCS's scenery probe (``Disposition.getSimpleZones``, behind ``veaf-tools dcs clear-ground-check``) is
blind to some forests: on Syria it answered "clear" for the Akamas and Ceyhan ranges, both standing in
woods (``known-limitations.yaml``, ``disposition-blind-to-akamas-forest``). The F10 map draws those
forests, and so does this module, from the same data: the ``Trees`` meshes of
``Mods/terrains/<map>/surface/<map>.surface5``.

**The file, as measured on Syria (DCS 2.9, 2026-11-16).** ``landscape5::Surface5File``, not encrypted,
30 GB. The u64 at offset 8 is the size of the header and metadata, where the data pool starts. The
metadata lists nodes, each opened by a 4x4 float matrix: identity rotation, translation = the node's
origin in world coordinates. A node holds a ``Land`` mesh, overlay meshes (roads, fields, trees...),
and ends with its base vertex buffer ``Pbase`` (f32 x 3, relative to the origin). An overlay mesh is a
group of named arrays followed by its material; a named array is
``<u32 len><name><u16 type><u16 element size><u32 flag><u64 byte count><u48 offset into the pool>``.
A forest mesh has no vertex of its own: its ``baseIndex`` array indexes the node's ``Pbase``, and its
``TRI`` array indexes its ``baseIndex``. Its material, ``Simple5.1`` / ``Trees``, is followed by a
parameter count, two u32, two bytes and its bounding box (six f32, relative to the node origin).

**Axes.** World ``x`` is mission ``x`` (north), world ``z`` is mission ``y`` (east); ``y`` is height,
unused here. Checked against six places David knows in game, on Syria: the three in a wood are inside a
forest triangle, the three in the open are not.

The 36 million forest triangles of Syria are not read: the meshes are indexed by bounding box, and only
those around a point asked are loaded, once. The file is mapped, never read whole.
"""

from __future__ import annotations

import mmap
import re
import struct
import sys
from array import array
from dataclasses import dataclass
from pathlib import Path
from types import TracebackType

_MAGIC = b"landscape5::Surface5File"
_MAGIC_AT = 0x24
_POOL_START_AT = 0x08
_NODE_MATRIX = re.compile(re.escape(struct.pack("<12f", 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0)))
_TREES_MATERIAL = struct.pack("<I", 9) + b"Simple5.1" + struct.pack("<I", 5) + b"Trees"
_PBASE = struct.pack("<I", 5) + b"Pbase"
#: How far before a forest material its arrays are looked for. A group of arrays is a few hundred bytes.
_GROUP_WINDOW = 1024
#: Between the end of the ``TRI`` record and the material, measured: 8 bytes. The material table at the
#: end of the file names the same shader with no mesh before it; this is how it is told apart.
_TRI_TO_MATERIAL_MAX = 32
#: Side of the cells a loaded mesh's triangles are bucketed into, in metres.
_CELL = 256.0

_TERRAINS = Path("Mods") / "terrains"
_REGISTRY_KEYS = (r"Software\Eagle Dynamics\DCS World", r"Software\Eagle Dynamics\DCS World OpenBeta")


class SurfaceFormatError(ValueError):
    """The file is not a ``.surface5`` this reader understands: it refuses rather than answer "no forest"."""


@dataclass(frozen=True)
class _ArrayRef:
    """Where a named array's bytes are in the pool."""

    elem_size: int
    byte_count: int
    offset: int


@dataclass(frozen=True)
class _ForestMesh:
    """A forest mesh, located: its node's origin, its box in world coordinates, and its arrays."""

    origin_x: float
    origin_z: float
    min_x: float
    min_z: float
    max_x: float
    max_z: float
    triangles: _ArrayRef
    base_index: _ArrayRef
    vertices: _ArrayRef

    def holds(self, x: float, z: float) -> bool:
        """Whether the world point is inside the mesh's bounding box."""
        return self.min_x <= x <= self.max_x and self.min_z <= z <= self.max_z


class _LoadedMesh:
    """A forest mesh's triangles in world ``x``/``z``, bucketed by cell for point queries."""

    def __init__(self, xs: list[float], zs: list[float], triangles: array) -> None:
        self.xs = xs
        self.zs = zs
        self.triangles = triangles
        self.cells: dict[tuple[int, int], list[int]] = {}
        for t in range(len(triangles) // 3):
            a, b, c = triangles[3 * t], triangles[3 * t + 1], triangles[3 * t + 2]
            x0, x1 = min(xs[a], xs[b], xs[c]), max(xs[a], xs[b], xs[c])
            z0, z1 = min(zs[a], zs[b], zs[c]), max(zs[a], zs[b], zs[c])
            for i in range(int(x0 // _CELL), int(x1 // _CELL) + 1):
                for j in range(int(z0 // _CELL), int(z1 // _CELL) + 1):
                    self.cells.setdefault((i, j), []).append(t)

    def contains(self, x: float, z: float) -> bool:
        """Whether the world point is inside (or on the edge of) one of the triangles."""
        xs, zs, tri = self.xs, self.zs, self.triangles
        for t in self.cells.get((int(x // _CELL), int(z // _CELL)), ()):
            a, b, c = tri[3 * t], tri[3 * t + 1], tri[3 * t + 2]
            d1 = (xs[b] - xs[a]) * (z - zs[a]) - (zs[b] - zs[a]) * (x - xs[a])
            d2 = (xs[c] - xs[b]) * (z - zs[b]) - (zs[c] - zs[b]) * (x - xs[b])
            d3 = (xs[a] - xs[c]) * (z - zs[c]) - (zs[a] - zs[c]) * (x - xs[c])
            if not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0)):
                return True
        return False


class SurfaceForests:
    """The forests of one map, read from its ``.surface5`` file.

    Use it as a context manager, or call :meth:`close`: the file stays mapped while it is open.
    """

    def __init__(self, path: Path) -> None:
        """Map the file and index its forest meshes.

        Args:
            path: The map's ``.surface5`` file.

        Raises:
            SurfaceFormatError: If the file is not a ``landscape5::Surface5File``, or its forest meshes
                cannot be located.
            OSError: If the file cannot be opened.
        """
        self.path = path
        self._file = path.open("rb")
        try:
            self._map = mmap.mmap(self._file.fileno(), 0, access=mmap.ACCESS_READ)
        except ValueError as e:  # an empty file cannot be mapped
            self._file.close()
            raise SurfaceFormatError(f"{path}: not a {_MAGIC.decode()} file") from e
        self._loaded: dict[int, _LoadedMesh] = {}
        try:
            self._pool = self._read_header()
            self._meshes = self._index_meshes()
        except BaseException:
            self.close()
            raise

    def __enter__(self) -> SurfaceForests:
        """Return the open reader."""
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        """Close the file."""
        self.close()

    def close(self) -> None:
        """Unmap and close the file."""
        if not self._map.closed:
            self._map.close()
        self._file.close()

    @property
    def mesh_count(self) -> int:
        """How many forest meshes the file holds."""
        return len(self._meshes)

    def in_forest(self, x: float, y: float) -> bool:
        """Whether a mission point stands in a forest.

        Args:
            x: Mission ``x`` (north).
            y: Mission ``y`` (east).

        Returns:
            True when the point is inside (or on the edge of) a forest triangle.

        Raises:
            SurfaceFormatError: If a forest mesh around the point holds indices past its vertices.
        """
        for number, mesh in enumerate(self._meshes):
            if mesh.holds(x, y) and self._load(number).contains(x, y):
                return True
        return False

    def _read_header(self) -> int:
        data = self._map
        if len(data) < _MAGIC_AT + len(_MAGIC) or data[_MAGIC_AT : _MAGIC_AT + len(_MAGIC)] != _MAGIC:
            raise SurfaceFormatError(f"{self.path}: not a {_MAGIC.decode()} file")
        (pool,) = struct.unpack_from("<Q", data, _POOL_START_AT)
        if not _MAGIC_AT + len(_MAGIC) <= pool <= len(data):
            raise SurfaceFormatError(f"{self.path}: data pool at {pool}, past the end of the file")
        return int(pool)

    def _index_meshes(self) -> list[_ForestMesh]:
        data, pool = self._map, self._pool
        nodes = [m.start() for m in _NODE_MATRIX.finditer(data, 0, pool)]
        meshes: list[_ForestMesh] = []
        node = -1
        at = data.find(_TREES_MATERIAL, 0, pool)
        while at >= 0:
            while node + 1 < len(nodes) and nodes[node + 1] < at:
                node += 1
            mesh = self._mesh_at(at, nodes, node)
            if mesh is not None:
                meshes.append(mesh)
            at = data.find(_TREES_MATERIAL, at + len(_TREES_MATERIAL), pool)
        return meshes

    def _mesh_at(self, at: int, nodes: list[int], node: int) -> _ForestMesh | None:
        """Locate the forest mesh whose material starts at *at*, or ``None`` for the material table."""
        data = self._map
        start = max(0, at - _GROUP_WINDOW)
        triangles = self._last_array(b"TRI", start, at)
        if triangles is None or at - triangles[1] > _TRI_TO_MATERIAL_MAX or node < 0:
            return None
        base_index = self._last_array(b"baseIndex", start, at)
        node_end = nodes[node + 1] if node + 1 < len(nodes) else self._pool
        pbase_at = data.find(_PBASE, at, node_end)
        if base_index is None or pbase_at < 0:
            raise SurfaceFormatError(f"{self.path}: forest mesh at {at} without its baseIndex or its node's Pbase")
        vertices = self._array_at(pbase_at, len(b"Pbase"))[0]
        origin_x, _origin_y, origin_z = struct.unpack_from("<3f", data, nodes[node] + 48)
        box_at = at + len(_TREES_MATERIAL) + 14
        lo_x, _lo_y, lo_z, hi_x, _hi_y, hi_z = struct.unpack_from("<6f", data, box_at)
        return _ForestMesh(
            origin_x,
            origin_z,
            origin_x + lo_x,
            origin_z + lo_z,
            origin_x + hi_x,
            origin_z + hi_z,
            triangles[0],
            base_index[0],
            vertices,
        )

    def _last_array(self, name: bytes, start: int, end: int) -> tuple[_ArrayRef, int] | None:
        """The last array named *name* in ``[start, end)``, with where its record ends."""
        at = self._map.rfind(struct.pack("<I", len(name)) + name, start, end)
        return None if at < 0 else self._array_at(at, len(name))

    def _array_at(self, at: int, name_length: int) -> tuple[_ArrayRef, int]:
        record = at + 4 + name_length
        _type, elem_size, _flag, byte_count = struct.unpack_from("<HHIQ", self._map, record)
        offset = int.from_bytes(self._map[record + 16 : record + 22], "little")
        if self._pool + offset + byte_count > len(self._map):
            raise SurfaceFormatError(f"{self.path}: array at {at} reaches past the end of the file")
        return _ArrayRef(elem_size, byte_count, offset), record + 22

    def _numbers(self, ref: _ArrayRef, code: str) -> array:
        values = array(code)
        start = self._pool + ref.offset
        values.frombytes(self._map[start : start + ref.byte_count])
        if sys.byteorder == "big":
            values.byteswap()
        return values

    def _load(self, number: int) -> _LoadedMesh:
        if number in self._loaded:
            return self._loaded[number]
        mesh = self._meshes[number]
        triangles = self._numbers(mesh.triangles, "I")
        base_index = self._numbers(mesh.base_index, "I")
        vertices = self._numbers(mesh.vertices, "f")
        if triangles and max(triangles) >= len(base_index):
            raise SurfaceFormatError(f"{self.path}: forest mesh {number}: a TRI index past its baseIndex")
        if base_index and max(base_index) >= len(vertices) // 3:
            raise SurfaceFormatError(f"{self.path}: forest mesh {number}: a baseIndex past its node's Pbase")
        xs = [mesh.origin_x + vertices[3 * i] for i in base_index]
        zs = [mesh.origin_z + vertices[3 * i + 2] for i in base_index]
        loaded = _LoadedMesh(xs, zs, triangles)
        self._loaded[number] = loaded
        return loaded


def find_surface_file(dcs_dir: Path, theatre: str) -> Path | None:
    """The ``.surface5`` file of a theatre in a DCS install.

    The theatre name a mission carries is the terrain's folder (``Syria``, ``Normandy``) or its file
    (``SinaiMap``, in folder ``Sinai``); both are tried, ignoring case.

    Args:
        dcs_dir: The DCS install (the folder holding ``Mods``).
        theatre: The mission's theatre.

    Returns:
        The file, or ``None`` when the theatre is not installed there.
    """
    wanted = theatre.casefold()
    terrains = dcs_dir / _TERRAINS
    if not terrains.is_dir():
        return None
    for folder in sorted(terrains.iterdir()):
        for surface in sorted((folder / "surface").glob("*.surface5")):
            if wanted in (folder.name.casefold(), surface.stem.casefold()):
                return surface
    return None


def registered_dcs_dirs() -> list[Path]:
    """The DCS installs the Windows registry knows (release first, then the old open beta).

    Returns:
        Their folders; empty off Windows or when DCS never registered one.
    """
    try:
        import winreg  # noqa: PLC0415  (Windows only)
    except ImportError:
        return []
    found: list[Path] = []
    for key_name in _REGISTRY_KEYS:
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, key_name) as key:
                found.append(Path(str(winreg.QueryValueEx(key, "Path")[0])))
        except OSError:
            continue
    return found


def surface_file_for_theatre(theatre: str, dcs_dir: Path | None = None) -> Path:
    """The ``.surface5`` file of a theatre, in the given DCS install or in those the registry knows.

    Args:
        theatre: The mission's theatre.
        dcs_dir: The DCS install; ``None`` to ask the registry.

    Returns:
        The file.

    Raises:
        FileNotFoundError: If no install holds the theatre, naming where it looked.
    """
    candidates = [dcs_dir] if dcs_dir is not None else registered_dcs_dirs()
    for candidate in candidates:
        found = find_surface_file(candidate, theatre)
        if found is not None:
            return found
    looked = ", ".join(str(candidate) for candidate in candidates) or "no DCS install in the registry"
    raise FileNotFoundError(
        f"no {theatre} map file (Mods/terrains/*/surface/*.surface5) found in: {looked}; "
        "give the DCS install folder with --dcs-dir"
    )
