"""Generators for DCS-derived reference data committed in this repository.

Each *provider* in this package turns an upstream DCS data source into a
committed artifact (and optionally a documentation page). Providers are driven
by the ``veaf-build update-dcs-data`` command.

Provenance: most providers read the community ``Quaggles/dcs-lua-datamine``
dump at a *pinned* ref (see :mod:`veaf_build.dcs_data.datamine`) so generation
is reproducible and CI can detect stale artifacts.
"""
