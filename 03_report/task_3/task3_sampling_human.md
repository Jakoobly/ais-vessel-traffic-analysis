# Task 3 Sampling Summary

Created at: 2026-06-04 15:13:36.04243
Sampling day: 2024-01-24
Random seed: 1103276

## Task 3.2 Interval cluster sample

All possible 5-minute intervals for 2024-01-24 were generated. A fixed seed was used and 100 intervals were randomly selected. For each selected interval, at most 100 AIS observations were retrieved. The final sample contains 10000 observations and was saved as `01_data/task_3/sample_intervals.csv`.

The random seed is important because it makes the randomly selected intervals reproducible. This allows the sample to be regenerated for grading, debugging, and verification.

Possible biases of this cluster sampling approach:

- Temporal cluster bias: selected 5-minute intervals may overrepresent short periods with unusual traffic.
- Regional receiver bias: areas with better AIS receiver coverage may be overrepresented.
- Activity bias: vessels that transmit more frequently during the selected intervals have a higher chance of appearing.

A possible alternative is stratified sampling by ship type and hour of day. This reduces imbalance across important temporal and vessel-type groups.

## Task 3.3 Stratified sample

The second sample uses strata defined by combinations of `ship_type` and hour of day. Stratum sizes were estimated using server-side PostgREST aggregation by MMSI within each hour and then joined with `ais_static` to assign ship types. The target sample size of 10,000 observations was allocated proportionally to the stratum sizes. Very small non-empty strata received at least one observation. Remaining observations were assigned according to the largest fractional remainders.

The final stratified sample contains 10000 observations and was saved as `01_data/task_3/sample_stratified.csv`.

True reproducible random retrieval directly from the API was not assumed. Therefore, records were retrieved by hour and then sampled locally within each stratum using the fixed random seed. This is a transparent approximation and avoids unfiltered access to the large `ais_dynamic` table.

## Comparison

Three plots were created to compare the interval cluster sample and the stratified sample:

- `03_report/graphs/task3_ship_type_comparison.png`
- `03_report/graphs/task3_speed_comparison.png`
- `03_report/graphs/task3_collection_type_comparison.png`

The interval sample may show stronger short-term variation because all observations come from randomly selected 5-minute clusters. The stratified sample is expected to better preserve the distribution across ship types and hours of the day because it explicitly allocates observations according to these strata.
