"""Dynamic-Slot warehouse wiring (DYNSLOT-WAREHOUSE).

Applies a ``warehouses.yaml`` config to a mission's ``warehouses`` table: enables
``dynamicSpawn`` on the selected airbases, sets fuel/munitions and aircraft stock,
and links each offered aircraft type to its dynamic-spawn template group via
``linkDynTempl`` (the group that provides the loadout/livery/radio/route).
"""

from .warehouses_injector_worker import WarehousesInjectorWorker, WarehousesResult, apply_warehouses

__all__ = ["WarehousesInjectorWorker", "WarehousesResult", "apply_warehouses"]
