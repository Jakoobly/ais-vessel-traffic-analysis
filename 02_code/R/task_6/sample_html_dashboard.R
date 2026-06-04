# THAS 2026 - Task 6: Static HTML dashboard
#
# Creates a self-contained leaflet map from the Task 3.2 interval sample and
# writes it to the static document root used by the NGINX Docker container.
#
# Main output for Docker/NGINX:
# - assets/site-content/sample_points.html
#
# Additional documentation/report outputs:
# - 03_report/task_6/sample_points.html
# - 03_report/task_6/task6_static_dashboard_human.md
# - 03_report/task_6/task6_static_dashboard_ai.json

required_packages <- c(
  "tidyverse", "leaflet", "htmlwidgets", "sf", "janitor", "jsonlite"
)

purrr::walk(required_packages, function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("Please install missing package: ", pkg, call. = FALSE)
  }
})

suppressPackageStartupMessages({
  library(tidyverse)
  library(leaflet)
  library(htmlwidgets)
  library(sf)
  library(janitor)
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

static_dir <- file.path(root_dir, "assets", "site-content")
report_dir <- file.path(root_dir, "03_report", "task_6")
graph_dir <- file.path(root_dir, "03_report", "graphs")

static_html_path <- file.path(static_dir, "sample_points.html")
report_html_path <- file.path(report_dir, "sample_points.html")
graph_html_path <- file.path(graph_dir, "sample_points.html")
ai_summary_path <- file.path(report_dir, "task6_static_dashboard_ai.json")
human_summary_path <- file.path(report_dir, "task6_static_dashboard_human.md")

dir.create(static_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(graph_dir, recursive = TRUE, showWarnings = FALSE)

# -------------------------------------------------------------------------
# Helper functions from Task 4
# -------------------------------------------------------------------------

helper_file <- file.path(root_dir, "02_code", "R", "functions", "task4_helpers.R")

if (!file.exists(helper_file)) {
  stop("Could not find task4_helpers.R at 02_code/R/functions/task4_helpers.R", call. = FALSE)
}

source(helper_file)

# -------------------------------------------------------------------------
# Input data
# -------------------------------------------------------------------------

sample_path <- file.path(root_dir, "01_data", "task_3", "sample_intervals.csv")
fallback_candidates <- c(
  file.path(root_dir, "01_data", "task_3", "sample.csv"),
  file.path(root_dir, "01_data", "sample.csv")
)
fallback_path <- fallback_candidates[file.exists(fallback_candidates)][1]

if (file.exists(sample_path)) {
  sample_points <- readr::read_csv(sample_path, show_col_types = FALSE)
  sample_source <- "01_data/task_3/sample_intervals.csv"
} else if (!is.na(fallback_path)) {
  sample_points <- readr::read_csv(fallback_path, show_col_types = FALSE)
  sample_source <- stringr::str_remove(normalizePath(fallback_path, winslash = "/"), paste0("^", normalizePath(root_dir, winslash = "/"), "/"))
  warning("Task 3.2 sample_intervals.csv not found. Using fallback file: ", sample_source)
} else {
  stop(
    "Neither 01_data/task_3/sample_intervals.csv nor a fallback sample.csv exists. ",
    "Run Task 3.2 first or add the fallback sample.csv.",
    call. = FALSE
  )
}

required_columns <- c("longitude", "latitude", "speed")
missing_columns <- setdiff(required_columns, names(sample_points))

if (length(missing_columns) > 0) {
  stop(
    "Input sample file is missing required columns: ",
    paste(missing_columns, collapse = ", "),
    call. = FALSE
  )
}

# Reuse the data-cleaning logic from Task 4. The map only uses valid points with
# a non-missing speed because speed is shown through the colour scale.
sample_points <- sample_points |>
  clean_track_data() |>
  dplyr::filter(!is.na(speed))

if (nrow(sample_points) == 0) {
  stop("No valid sample points with non-missing speed available for the dashboard.", call. = FALSE)
}

# -------------------------------------------------------------------------
# Static leaflet map
# -------------------------------------------------------------------------

static_map <- make_sample_map(
  sample_points,
  "Task 6: Static AIS sample dashboard"
)

# The assignment text asks for a static dashboard and the deployment endpoint is
# /sample_points.html. Therefore the underscore file name is used for the actual
# hosted file.
htmlwidgets::saveWidget(
  static_map,
  file = static_html_path,
  selfcontained = TRUE
)

# Keep report/documentation copies as evidence for the report and repository.
file.copy(
  from = static_html_path,
  to = report_html_path,
  overwrite = TRUE
)

file.copy(
  from = static_html_path,
  to = graph_html_path,
  overwrite = TRUE
)

# -------------------------------------------------------------------------
# Report-ready summaries
# -------------------------------------------------------------------------

task6_summary <- list(
  metadata = list(
    created_at = as.character(Sys.time()),
    root_dir = root_dir,
    source_file = sample_source,
    n_points = nrow(sample_points)
  ),
  outputs = list(
    nginx_document_root_file = "assets/site-content/sample_points.html",
    report_copy = "03_report/task_6/sample_points.html",
    graph_copy = "03_report/graphs/sample_points.html",
    ai_summary = "03_report/task_6/task6_static_dashboard_ai.json",
    human_summary = "03_report/task_6/task6_static_dashboard_human.md",
    expected_local_url = "http://localhost/sample_points.html",
    expected_deployed_url = "https://<your-server>/sample_points.html"
  ),
  implementation_decisions = list(
    input_data = "The dashboard uses the Task 3.2 interval sample from 01_data/task_3/sample_intervals.csv. If this file is unavailable, a fallback sample.csv is used only as a backup.",
    docker_nginx = "The self-contained HTML file is written to assets/site-content/sample_points.html because this folder is mounted into the NGINX document root by docker-compose.yaml.",
    visualisation = "The leaflet map reuses the Task 4 helper logic. Vessel speed is represented by a capped colour scale and marker clustering is used to keep the dashboard responsive."
  )
)

jsonlite::write_json(
  task6_summary,
  path = ai_summary_path,
  pretty = TRUE,
  auto_unbox = TRUE,
  na = "null"
)

human_md <- c(
  "# Task 6 Static HTML Dashboard",
  "",
  paste0("- Created at: ", Sys.time()),
  paste0("- Source file: `", sample_source, "`"),
  paste0("- Number of valid AIS observations shown: ", nrow(sample_points)),
  "",
  "## Implementation notes",
  "",
  "- The Task 4.1 leaflet logic was reused to create a static AIS sample dashboard.",
  "- Vessel speed is shown with the same capped colour scale as in Task 4.1.",
  "- Marker clustering is used so that the map remains responsive in the browser.",
  "- The self-contained HTML file is written to `assets/site-content/sample_points.html`.",
  "- This folder is mounted into the NGINX document root by `docker-compose.yaml`, so the dashboard is served at `/sample_points.html`.",
  "",
  "## Output files",
  "",
  "- `assets/site-content/sample_points.html`",
  "- `03_report/task_6/sample_points.html`",
  "- `03_report/graphs/sample_points.html`",
  "- `03_report/task_6/task6_static_dashboard_ai.json`",
  "- `03_report/task_6/task6_static_dashboard_human.md`",
  "",
  "## Expected URLs",
  "",
  "- Local Docker test: `http://localhost/sample_points.html`",
  "- Server deployment: `https://<your-server>/sample_points.html`",
  "",
  "## Docker test commands",
  "",
  "```bash",
  "docker compose up -d",
  "docker compose ps",
  "docker compose logs nginx --tail=50",
  "docker compose down",
  "```"
)

readr::write_lines(human_md, human_summary_path)

message("Task 6 completed.")
message("Created: ", static_html_path)
message("Created: ", report_html_path)
message("Created: ", graph_html_path)
message("Created: ", human_summary_path)
message("Created: ", ai_summary_path)
