# THAS 2026 - Task 4.1: Sample dashboard
# Reads the interval sample from Task 3.2 and creates leaflet maps.
#
# Outputs:
# - 03_report/graphs/sample_points_full.html
# - 03_report/graphs/sample_points_satellite.html
# - 03_report/task4_sample_dashboard_human.md
# - 03_report/task4_sample_dashboard_ai.json

source("02_code/R/functions/task4_helpers.R")
ensure_task4_dirs()

speed_cap_kn <- 40
sample_path <- "01_data/sample_intervals.csv"
fallback_path <- "01_data/sample.csv"

if (file.exists(sample_path)) {
  sample_points <- readr::read_csv(sample_path, show_col_types = FALSE)
  sample_source <- sample_path
} else if (file.exists(fallback_path)) {
  sample_points <- readr::read_csv(fallback_path, show_col_types = FALSE)
  sample_source <- fallback_path
  warning("Task 3.2 sample_intervals.csv not found. Using fallback file 01_data/sample.csv.")
} else {
  stop("Neither 01_data/sample_intervals.csv nor 01_data/sample.csv exists. Run Task 3.2 first or add the fallback sample.csv.")
}

sample_points <- sample_points |>
  clean_track_data() |>
  filter(!is.na(speed))

satellite_points <- sample_points |>
  filter(str_to_lower(collection_type) == "satellite")

full_map <- make_sample_map(
  sample_points,
  "Task 4.1a: Full AIS sample (speed capped at 40 kn)"
)

satellite_map <- make_sample_map(
  satellite_points,
  "Task 4.1b: Satellite AIS sample (speed capped at 40 kn)"
)

# Save HTML maps. Screenshots are intentionally not forced because webshot2
# requires Chrome/Chromium, which is not guaranteed on every grading machine.
save_leaflet_map(
  full_map,
  "03_report/graphs/sample_points_full.html"
)

save_leaflet_map(
  satellite_map,
  "03_report/graphs/sample_points_satellite.html"
)

sample_summary <- list(
  metadata = list(
    created_at = as.character(Sys.time()),
    source_file = sample_source,
    speed_cap_for_visualisation_kn = speed_cap_kn
  ),
  full_sample = list(
    n_rows = nrow(sample_points),
    n_missing_speed_removed = sum(is.na(readr::read_csv(sample_source, show_col_types = FALSE)$speed)),
    speed_min_kn = min(sample_points$speed, na.rm = TRUE),
    speed_median_kn = median(sample_points$speed, na.rm = TRUE),
    speed_mean_kn = mean(sample_points$speed, na.rm = TRUE),
    speed_max_kn = max(sample_points$speed, na.rm = TRUE),
    n_speed_above_cap = sum(sample_points$speed > speed_cap_kn, na.rm = TRUE)
  ),
  satellite_sample = list(
    n_rows = nrow(satellite_points),
    share_of_full_sample = nrow(satellite_points) / nrow(sample_points)
  ),
  outputs = list(
    full_map = "03_report/graphs/sample_points_full.html",
    satellite_map = "03_report/graphs/sample_points_satellite.html"
  )
)

jsonlite::write_json(
  sample_summary,
  "03_report/task4_sample_dashboard_ai.json",
  pretty = TRUE,
  auto_unbox = TRUE
)

human_md <- c(
  "# Task 4.1 Sample Dashboard",
  "",
  paste0("Source file: `", sample_source, "`"),
  paste0("Number of valid AIS observations used in the full map: ", nrow(sample_points)),
  paste0("Number of satellite-only observations: ", nrow(satellite_points)),
  "",
  "## Visualisation",
  "",
  paste0(
    "The full AIS sample and the satellite-only subset were visualised with interactive leaflet maps. ",
    "Vessel speed over ground is represented by a yellow-to-red colour scale. ",
    "For visual readability, speeds above ", speed_cap_kn, " knots were capped in the colour scale only; ",
    "the original speed values remain visible in the point popups. ",
    "Marker clusters are used to avoid rendering too many points at once. ",
    "Important: cluster colours indicate the number of observations in the cluster, not vessel speed. ",
    "The speed legend applies to individual points after zooming in."
  ),
  "",
  "## Comparison of full sample and satellite-only map",
  "",
  paste0(
    "The satellite-only map contains ", nrow(satellite_points), " observations, compared with ",
    nrow(sample_points), " observations in the full sample. ",
    "The broad spatial pattern is similar because both maps are based on the same sampled day and interval strategy. ",
    "However, the satellite-only subset is sparser and may emphasize offshore and remote areas more strongly, ",
    "where terrestrial AIS receiver coverage is weaker or unavailable."
  ),
  "",
  "## Output files",
  "",
  "- `03_report/graphs/sample_points_full.html`",
  "- `03_report/graphs/sample_points_satellite.html`",
  "- `03_report/task4_sample_dashboard_ai.json`"
)

readr::write_lines(human_md, "03_report/task4_sample_dashboard_human.md")

message("Task 4.1 completed.")
message("Created: 03_report/graphs/sample_points_full.html")
message("Created: 03_report/graphs/sample_points_satellite.html")
message("Created: 03_report/task4_sample_dashboard_human.md")
message("Created: 03_report/task4_sample_dashboard_ai.json")
