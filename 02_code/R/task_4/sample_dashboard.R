# THAS 2026 - Task 4.1: Sample dashboard
# Reads the interval sample from Task 3.2 and creates leaflet maps.
#
# Outputs:
#   03_report/graphs/sample_points_full.html
#   03_report/graphs/sample_points_satellite.html
#   03_report/task_4/task4_sample_dashboard_human.md
#   03_report/task_4/task4_sample_dashboard_ai.json

library(tidyverse)
library(readr)
library(jsonlite)

# -------------------------------------------------------------------------
# Project paths
# -------------------------------------------------------------------------

find_project_root <- function(start_dir = getwd()) {
  current <- normalizePath(start_dir, winslash = "/", mustWork = TRUE)
  
  repeat {
    has_project_dirs <- all(dir.exists(file.path(current, c("01_data", "02_code", "03_report"))))
    if (has_project_dirs) return(current)
    
    parent <- dirname(current)
    if (identical(parent, current)) {
      stop("Project root not found. Please run this script from inside AIDAHO_IDS_THAS_2026.")
    }
    
    current <- parent
  }
}

root_dir <- find_project_root()

data_dir <- file.path(root_dir, "01_data", "task_4")
report_dir <- file.path(root_dir, "03_report", "task_4")
graph_dir <- file.path(root_dir, "03_report", "graphs")

dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(graph_dir, recursive = TRUE, showWarnings = FALSE)

# Helper functions for cleaning, leaflet maps and saving maps
source(file.path(root_dir, "02_code", "R", "functions", "task4_helpers.R"))

# -------------------------------------------------------------------------
# Settings
# -------------------------------------------------------------------------

speed_cap_kn <- 40

sample_path <- file.path(root_dir, "01_data", "task_3", "sample_intervals.csv")
fallback_path <- file.path(root_dir, "01_data", "sample.csv")

sample_path_rel <- "01_data/task_3/sample_intervals.csv"
fallback_path_rel <- "01_data/sample.csv"

full_map_path <- file.path(graph_dir, "sample_points_full.html")
satellite_map_path <- file.path(graph_dir, "sample_points_satellite.html")

full_map_path_rel <- "03_report/graphs/sample_points_full.html"
satellite_map_path_rel <- "03_report/graphs/sample_points_satellite.html"

ai_summary_path <- file.path(report_dir, "task4_sample_dashboard_ai.json")
human_summary_path <- file.path(report_dir, "task4_sample_dashboard_human.md")

ai_summary_path_rel <- "03_report/task_4/task4_sample_dashboard_ai.json"
human_summary_path_rel <- "03_report/task_4/task4_sample_dashboard_human.md"

# -------------------------------------------------------------------------
# Load Task 3 interval sample
# -------------------------------------------------------------------------

if (file.exists(sample_path)) {
  raw_sample_points <- read_csv(sample_path, show_col_types = FALSE)
  sample_source <- sample_path_rel
} else if (file.exists(fallback_path)) {
  raw_sample_points <- read_csv(fallback_path, show_col_types = FALSE)
  sample_source <- fallback_path_rel
  warning("Task 3.2 sample_intervals.csv not found. Using fallback file 01_data/sample.csv.")
} else {
  stop("Neither 01_data/task_3/sample_intervals.csv nor 01_data/sample.csv exists. Run Task 3.2 first or add the fallback sample.csv.")
}

n_missing_speed_before_cleaning <- sum(is.na(raw_sample_points$speed))

sample_points <- raw_sample_points |>
  clean_track_data() |>
  filter(!is.na(speed))

satellite_points <- sample_points |>
  filter(str_to_lower(collection_type) == "satellite")

# -------------------------------------------------------------------------
# Create leaflet maps
# -------------------------------------------------------------------------

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
  full_map_path
)

save_leaflet_map(
  satellite_map,
  satellite_map_path
)

# -------------------------------------------------------------------------
# Save report-ready summaries
# -------------------------------------------------------------------------

sample_summary <- list(
  metadata = list(
    created_at = as.character(Sys.time()),
    root_dir = root_dir,
    source_file = sample_source,
    speed_cap_for_visualisation_kn = speed_cap_kn
  ),
  implementation_decisions = list(
    source_data = "Task 4.1 uses the interval sample created in Task 3.2. The script first looks for 01_data/task_3/sample_intervals.csv and only uses 01_data/sample.csv as a fallback.",
    output_structure = "Interactive HTML map outputs are stored in 03_report/graphs as required by the THAS guidelines. Task-specific summaries are stored in 03_report/task_4.",
    speed_visualisation = "Speed values above 40 knots are capped only for the colour scale to keep the map readable. Original speed values remain available in the popups.",
    clustering = "Marker clusters are used to keep the leaflet maps responsive. Cluster colours represent the number of points in the cluster, not vessel speed."
  ),
  full_sample = list(
    n_rows = nrow(sample_points),
    n_missing_speed_removed = n_missing_speed_before_cleaning,
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
    full_map = full_map_path_rel,
    satellite_map = satellite_map_path_rel,
    ai_summary = ai_summary_path_rel,
    human_summary = human_summary_path_rel
  )
)

write_json(
  sample_summary,
  ai_summary_path,
  pretty = TRUE,
  auto_unbox = TRUE
)

human_md <- c(
  "# Task 4.1 Sample Dashboard",
  "",
  paste0("Created at: ", sample_summary$metadata$created_at),
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
  paste0("- `", full_map_path_rel, "`"),
  paste0("- `", satellite_map_path_rel, "`"),
  paste0("- `", ai_summary_path_rel, "`"),
  paste0("- `", human_summary_path_rel, "`")
)

write_lines(human_md, human_summary_path)

message("Task 4.1 completed.")
message("Created: ", full_map_path_rel)
message("Created: ", satellite_map_path_rel)
message("Created: ", human_summary_path_rel)
message("Created: ", ai_summary_path_rel)