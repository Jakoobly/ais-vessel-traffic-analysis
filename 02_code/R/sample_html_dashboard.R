# THAS 2026 - Task 6: Static HTML dashboard
#
# Creates a leaflet map from the Task 3.2 interval sample and writes it to the
# static document root used by the NGINX Docker container.
#
# Main output for Docker/NGINX:
# - assets/site-content/sample_points.html
#
# Additional report copy:
# - 03_report/graphs/sample_points.html

source("02_code/R/functions/task4_helpers.R")
ensure_task4_dirs()
dir.create("assets/site-content", recursive = TRUE, showWarnings = FALSE)

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
  dplyr::filter(!is.na(speed))

if (nrow(sample_points) == 0) {
  stop("No valid sample points with non-missing speed available for the dashboard.")
}

static_map <- make_sample_map(
  sample_points,
  "Task 6: Static AIS sample dashboard"
)

# The assignment text asks for a file named sample points.html, but the target
# URL is /sample_points.html. The underscore version is used so the browser URL
# exactly matches the required endpoint.
htmlwidgets::saveWidget(
  static_map,
  file = "assets/site-content/sample_points.html",
  selfcontained = TRUE
)

# Keep a copy in 03_report/graphs so every figure/dashboard used in the report
# is also stored in the report output folder.
file.copy(
  from = "assets/site-content/sample_points.html",
  to = "03_report/graphs/sample_points.html",
  overwrite = TRUE
)

task6_summary <- list(
  metadata = list(
    created_at = as.character(Sys.time()),
    source_file = sample_source,
    n_points = nrow(sample_points)
  ),
  output = list(
    nginx_document_root_file = "assets/site-content/sample_points.html",
    report_copy = "03_report/graphs/sample_points.html",
    expected_url = "https://<your-server>/sample_points.html"
  ),
  note = "The HTML file is self-contained and is served by NGINX from assets/site-content via Docker Compose."
)

jsonlite::write_json(
  task6_summary,
  "03_report/task6_static_dashboard_ai.json",
  pretty = TRUE,
  auto_unbox = TRUE
)

human_md <- c(
  "# Task 6 Static HTML Dashboard",
  "",
  paste0("Source file: `", sample_source, "`"),
  paste0("Number of valid AIS observations shown: ", nrow(sample_points)),
  "",
  "The Task 4.1 leaflet logic was reused to create a static AIS sample dashboard. Vessel speed is shown with the same capped colour scale as in Task 4.1, and marker clustering is used to keep the map responsive.",
  "",
  "The self-contained HTML file is written to `assets/site-content/sample_points.html`. This folder is mounted into the NGINX document root by `docker-compose.yaml`, so the dashboard is served at `/sample_points.html`.",
  "",
  "Expected deployed URL: `https://<your-server>/sample_points.html`",
  "",
  "Docker test commands:",
  "",
  "```bash",
  "docker compose up -d",
  "docker compose ps",
  "docker compose logs nginx",
  "docker compose down",
  "```"
)

readr::write_lines(human_md, "03_report/task6_static_dashboard_human.md")

message("Task 6 completed.")
message("Created: assets/site-content/sample_points.html")
message("Created: 03_report/graphs/sample_points.html")
message("Created: 03_report/task6_static_dashboard_human.md")
message("Created: 03_report/task6_static_dashboard_ai.json")
