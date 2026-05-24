# Task 5 AIS Traffic Density Summary

- Created at: 2026-05-24 14:50:23.754799
- Analysis date: 2022-04-23
- AIS records downloaded from ais_germany: 497990
- H3 resolution: 7
- River buffer distance: 1500 m
- River assignment rule: H3 match first; if multiple rivers match, choose the nearest original river geometry.

## Percentage on selected German rivers vs elsewhere
# A tibble: 2 × 3
  location_group           n_records percentage
  <chr>                        <int>      <dbl>
1 On selected German river    258110       51.8
2 Elsewhere                   239880       48.2

## Records by river
# A tibble: 7 × 2
  river_name n_records
  <chr>          <int>
1 Rhine         117007
2 Elbe           95019
3 Weser          32932
4 Main            5424
5 Donau           3526
6 Mosel           2944
7 Ems             1258

## Report-ready interpretation notes
- H3 converts point-in-river matching into a key-based join: AIS points and buffered rivers receive comparable cell IDs.
- The 1500 m buffer is intentionally wider than the river centreline because Natural Earth provides generalized line geometries, not navigable river polygons.
- H3 resolution 7 is the required resolution and represents a compromise between spatial detail and computational cost.
- Points classified as elsewhere can include coastal/open-water AIS records, records near non-selected small rivers, and points outside the chosen buffer.
- The Rhine distance plot uses the orientation of the Natural Earth Rhine line; therefore the x-axis should be interpreted as relative distance along that stored geometry.
