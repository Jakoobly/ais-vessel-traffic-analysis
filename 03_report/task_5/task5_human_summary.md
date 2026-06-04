# Task 5 AIS Traffic Density Summary

- Created at: 2026-06-04 17:28:02.693776
- Analysis date: 2022-04-23
- AIS records downloaded from ais_germany: 497990
- H3 resolution: 7
- River buffer distance: 1500 m

## Implementation notes

- The `ais_germany` table was queried only for the required date, 2022-04-23.
- Major German inland-waterway rivers were selected from Natural Earth. Duplicate names and synonyms were standardised, for example `Rhine`/`Rhein`, `Danube`/`Donau`, and `Mosel`/`Moselle`.
- River geometries used for matching were clipped exactly to the German country polygon. This removes river parts outside Germany while keeping border rivers on the border.
- For the exported map only, German border segments close to the raw Rhine geometry were added as a visual supplement. This makes the Rhine easier to see on the border without plotting foreign river snippets.
- H3 converts point-in-river matching into a key-based join: AIS points and buffered river geometries receive comparable cell IDs.
- H3 resolution 7 is used because it is required by the assignment and is a compromise between spatial detail and computational cost.
- The 1500 m buffer is intentionally wider than the river centreline because Natural Earth provides generalized line geometries, not navigable river polygons.
- If an AIS point matched more than one river, the nearest original river geometry was selected.
- Points classified as elsewhere can include coastal/open-water AIS records, records near non-selected small rivers, and points outside the chosen buffer.
- The Rhine distance plot uses the orientation of the Natural Earth Rhine line; therefore the x-axis should be interpreted as relative distance along that stored geometry.
- The final Rhine distance bin may be elevated because points near the end of the stored Natural Earth Rhine geometry accumulate in the final segment.

## Percentage on selected German rivers vs elsewhere

# A tibble: 2 × 3
  location_group           n_records percentage
  <chr>                        <int>      <dbl>
1 On selected German river    258108       51.8
2 Elsewhere                   239882       48.2

## Records by river

# A tibble: 7 × 2
  river_name n_records
  <chr>          <int>
1 Rhine         117007
2 Elbe           95019
3 Weser          32932
4 Main            5424
5 Danube          3526
6 Moselle         2942
7 Ems             1258

## Output files

- `01_data/task_5/task5_german_rivers.rds`
- `01_data/task_5/ais_germany_2022_04_23.csv`
- `01_data/task_5/task5_river_h3_cells.csv`
- `01_data/task_5/task5_ais_germany_2022_04_23_classified.csv`
- `01_data/task_5/task5_river_share.csv`
- `01_data/task_5/task5_river_summary.csv`
- `01_data/task_5/task5_rhine_density.csv`
- `03_report/graphs/task5_1b_german_rivers.png`
- `03_report/graphs/task5_2e_ship_type_distribution.png`
- `03_report/graphs/task5_2g_rhine_density.png`
- `03_report/task_5/task5_ai_summary.json`
- `03_report/task_5/task5_human_summary.md`
