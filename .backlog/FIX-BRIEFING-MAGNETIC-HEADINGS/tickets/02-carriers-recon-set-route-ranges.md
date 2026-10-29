# 02 — Carriers, recon photos, set_route and ranges

Status: ✅ done

Asked by David after ticket 01 (2026-10-29), in the same PR.

## Done when

- A grid heading is turned true by the meridian convergence and magnetic by the declination, measured against GeographicLib (`test_a_grid_heading_is_turned_by_the_meridian_convergence`).
- The campaign deck gives the carrier's course magnetic (`test_the_carrier_course_is_magnetic`), and the recon caption and banner give the camera's heading magnetic, the rose's north true (`test_the_caption_says_what_the_sidecar_gives`, `test_the_banner_heading_is_magnetic_and_the_rose_true`).
- `set_route`'s legs are magnetic (`test_the_plan_and_its_points_are_written_on_the_ground`).
- The ranges are the geodesic's within 2 cm (`test_the_distance_is_the_geodesic_one`), the grid's overstated one is no longer printed (`test_a_target_says_where_it_stands_from_the_bullseye_magnetic`), and the known limitation `briefing-ranges-on-the-grid` is gone.
