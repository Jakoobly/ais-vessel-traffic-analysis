# Task 7 Shiny Data Preparation Summary

- Created at: 2026-06-04 17:32:44.071428
- Input AIS file: `01_data/task_5/task5_ais_germany_2022_04_23_classified.csv`
- Input river file: `01_data/task_5/task5_german_rivers.rds`
- Output file: `01_data/task_7/task7_shiny_traffic_density.csv`
- AI summary: `03_report/task_7/task7_ai_summary.json`
- Rows written: 415
- Rivers included: 7
- Ship types included: 7

## Rivers
Danube, Elbe, Ems, Main, Moselle, Rhine, Weser

## Ship types
Cargo, Other, Passenger Ship, Special Craft, Tanker, Unknown, Wing In Ground

## Notes
- The Shiny app reads this prepared CSV instead of sending expensive API requests during user interaction.
- Distances are calculated along the Natural Earth river geometry and aggregated into 10 km bins.
- The line orientation is inherited from the stored Natural Earth geometry.
- Missing or empty ship_type values are replaced with `Unknown`.
