# 01 — Surface5 forest reader

Status: ✅ done

`veaf_libs/dcs_forests.py`, standard library only:

- find the `.surface5` file of a theatre in a DCS install (`Mods/terrains/<folder>/surface/*.surface5`, folder or file stem matching the theatre name), and the DCS install from the registry (`HKCU\Software\Eagle Dynamics\DCS World` and `DCS World OpenBeta`, value `Path`);
- index the `Trees` meshes of the file by world bounding box, through `mmap`, without reading the 30 GB;
- `in_forest(x, y)` for a mission point: load the triangles of the meshes whose box holds the point, once, and test the point against them.

A mesh whose arrays do not agree (a `TRI` index past its `baseIndex`, a `baseIndex` past the node's `Pbase`) raises: the reader refuses a file it does not understand rather than answering "no forest".

Tests on small binary fixtures built in the test, no map file.
