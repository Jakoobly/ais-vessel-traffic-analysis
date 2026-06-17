# Task 4.1 Sample Dashboard

Created at: 2026-06-17 18:14:26.947005
Source file: `01_data/task_3/sample_intervals.csv`
Number of valid AIS observations used in the full map: 9877
Number of satellite-only observations: 1713

## Visualisation

The full AIS sample and the satellite-only subset were visualised with interactive leaflet maps. Vessel speed over ground is represented by a yellow-to-red colour scale. For visual readability, speeds above 40 knots were capped in the colour scale only; the original speed values remain visible in the point popups. Marker clusters are used to avoid rendering too many points at once. Important: cluster colours indicate the number of observations in the cluster, not vessel speed. The speed legend applies to individual points after zooming in.

## Comparison of full sample and satellite-only map

The satellite-only map contains 1713 observations, compared with 9877 observations in the full sample. The broad spatial pattern is similar because both maps are based on the same sampled day and interval strategy. However, the satellite-only subset is sparser and may emphasize offshore and remote areas more strongly, where terrestrial AIS receiver coverage is weaker or unavailable.

## Output files

- `03_report/graphs/sample_points_full.html`
- `03_report/graphs/sample_points_satellite.html`
- `03_report/task_4/task4_sample_dashboard_ai.json`
- `03_report/task_4/task4_sample_dashboard_human.md`
