# THAS Task 7: prepare data for the Shiny app
# ------------------------------------------------------------
# This script preprocesses the river traffic-density data used by the
# deployed Shiny app. The app then reads a prepared CSV instead of sending
# expensive API requests while users interact with it.

required_packages <- c("tidyverse", "sf", "jsonlite")

purrr::walk(required_packages, function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("Please install missing package: ", pkg, call. = FALSE)
  }
})

suppressPackageStartupMessages({
  library(tidyverse)
  library(sf)
  library(jsonlite)
})

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

data_task5_dir <- file.path(root_dir, "01_data", "task_5")
data_task7_dir <- file.path(root_dir, "01_data", "task_7")
report_task7_dir <- file.path(root_dir, "03_report", "task_7")

dir.create(data_task7_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(report_task7_dir, recursive = TRUE, showWarnings = FALSE)

helper_file <- file.path(root_dir, "02_code", "R", "functions", "task5_helpers.R")

if (!file.exists(helper_file)) {
  stop("Could not find task5_helpers.R at 02_code/R/functions/task5_helpers.R", call. = FALSE)
}

source(helper_file)

# -------------------------------------------------------------------------
# Input and output files
# -------------------------------------------------------------------------

input_points <- file.path(
  data_task5_dir,
  "task5_ais_germany_2022_04_23_classified.csv"
)

input_rivers <- file.path(
  data_task5_dir,
  "task5_german_rivers.rds"
)

output_file <- file.path(
  data_task7_dir,
  "task7_shiny_traffic_density.csv"
)

summary_file <- file.path(
  report_task7_dir,
  "task7_prepare_shiny_data_summary.md"
)

ai_summary_file <- file.path(
  report_task7_dir,
  "task7_ai_summary.json"
)

if (!file.exists(input_points)) {
  stop("Missing classified AIS file from Task 5: ", input_points, call. = FALSE)
}

if (!file.exists(input_rivers)) {
  stop("Missing river geometries from Task 5: ", input_rivers, call. = FALSE)
}

# -------------------------------------------------------------------------
# Read prepared Task 5 data
# -------------------------------------------------------------------------

classified <- readr::read_csv(input_points, show_col_types = FALSE) |>
  filter(
    on_river,
    !is.na(river_name),
    !is.na(latitude),
    !is.na(longitude)
  ) |>
  mutate(
    ship_type = if_else(is.na(ship_type) | ship_type == "", "Unknown", ship_type),
    river_name = as.character(river_name)
  )

german_rivers <- readr::read_rds(input_rivers)

# -------------------------------------------------------------------------
# Calculate traffic density for each river
# -------------------------------------------------------------------------

calculate_river_density <- function(selected_river, bin_width_km = 10) {
  river_geometry <- german_rivers |>
    filter(river_name == selected_river) |>
    st_transform(3035) |>
    summarise(geometry = st_combine(geometry), .groups = "drop") |>
    st_cast("MULTILINESTRING", warn = FALSE) |>
    st_line_merge() |>
    get_main_line()
  
  river_points <- classified |>
    filter(river_name == selected_river) |>
    st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE) |>
    st_transform(3035)
  
  if (nrow(river_geometry) == 0 || nrow(river_points) == 0) {
    return(tibble())
  }
  
  line <- river_geometry$geometry[[1]]
  
  river_points |>
    mutate(
      distance_km = distance_along_line_km(river_points, line),
      distance_bin_km = floor(distance_km / bin_width_km) * bin_width_km
    ) |>
    st_drop_geometry() |>
    count(river_name, ship_type, distance_bin_km, name = "n_records") |>
    mutate(
      bin_width_km = bin_width_km,
      density_records_per_10km = n_records / bin_width_km * 10
    ) |>
    arrange(river_name, ship_type, distance_bin_km)
}

river_names <- sort(unique(classified$river_name))

traffic_density <- purrr::map_dfr(river_names, calculate_river_density) |>
  mutate(
    river_name = as.character(river_name),
    ship_type = as.character(ship_type)
  )

# -------------------------------------------------------------------------
# Save Shiny preprocessing output
# -------------------------------------------------------------------------

readr::write_csv(traffic_density, output_file)

# -------------------------------------------------------------------------
# AI-readable summary output
# -------------------------------------------------------------------------

task7_summary <- list(
  metadata = list(
    created_at = as.character(Sys.time()),
    root_dir = root_dir,
    input_points = file.path(
      "01_data",
      "task_5",
      "task5_ais_germany_2022_04_23_classified.csv"
    ),
    input_rivers = file.path(
      "01_data",
      "task_5",
      "task5_german_rivers.rds"
    ),
    output_file = file.path(
      "01_data",
      "task_7",
      "task7_shiny_traffic_density.csv"
    ),
    human_summary = file.path(
      "03_report",
      "task_7",
      "task7_prepare_shiny_data_summary.md"
    ),
    ai_summary = file.path(
      "03_report",
      "task_7",
      "task7_ai_summary.json"
    )
  ),
  
  preprocessing_settings = list(
    bin_width_km = 10,
    crs_distance_calculation = 3035,
    method =
      "Distances are calculated along Natural Earth river centre lines and aggregated into 10 km bins.",
    river_selection =
      "Only AIS points classified as on selected German rivers in Task 5 are included.",
    ship_type_handling =
      "Missing or empty ship_type values are replaced with 'Unknown'."
  ),
  
  output_statistics = list(
    rows_written = nrow(traffic_density),
    rivers_included = dplyr::n_distinct(traffic_density$river_name),
    ship_types_included = dplyr::n_distinct(traffic_density$ship_type),
    river_names = sort(unique(traffic_density$river_name)),
    ship_types = sort(unique(traffic_density$ship_type))
  )
)

jsonlite::write_json(
  task7_summary,
  path = ai_summary_file,
  pretty = TRUE,
  auto_unbox = TRUE,
  na = "null"
)

# -------------------------------------------------------------------------
# Human-readable summary output
# -------------------------------------------------------------------------

summary_lines <- c(
  "# Task 7 Shiny Data Preparation Summary",
  "",
  paste0("- Created at: ", Sys.time()),
  paste0("- Input AIS file: `", file.path("01_data", "task_5", "task5_ais_germany_2022_04_23_classified.csv"), "`"),
  paste0("- Input river file: `", file.path("01_data", "task_5", "task5_german_rivers.rds"), "`"),
  paste0("- Output file: `", file.path("01_data", "task_7", "task7_shiny_traffic_density.csv"), "`"),
  paste0("- AI summary: `", file.path("03_report", "task_7", "task7_ai_summary.json"), "`"),
  paste0("- Rows written: ", nrow(traffic_density)),
  paste0("- Rivers included: ", dplyr::n_distinct(traffic_density$river_name)),
  paste0("- Ship types included: ", dplyr::n_distinct(traffic_density$ship_type)),
  "",
  "## Rivers",
  paste(sort(unique(traffic_density$river_name)), collapse = ", "),
  "",
  "## Ship types",
  paste(sort(unique(traffic_density$ship_type)), collapse = ", "),
  "",
  "## Notes",
  "- The Shiny app reads this prepared CSV instead of sending expensive API requests during user interaction.",
  "- Distances are calculated along the Natural Earth river geometry and aggregated into 10 km bins.",
  "- The line orientation is inherited from the stored Natural Earth geometry.",
  "- Missing or empty ship_type values are replaced with `Unknown`."
)

writeLines(summary_lines, summary_file)

# -------------------------------------------------------------------------
# Console messages
# -------------------------------------------------------------------------

message("Task 7 preprocessing completed.")
message("Wrote Shiny preprocessing output to: ", output_file)
message("Wrote human summary to: ", summary_file)
message("Wrote AI summary to: ", ai_summary_file)
message("Rows: ", nrow(traffic_density), "; rivers: ", dplyr::n_distinct(traffic_density$river_name))