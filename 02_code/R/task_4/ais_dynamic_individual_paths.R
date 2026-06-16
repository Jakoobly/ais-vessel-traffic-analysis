# THAS 2026 - Task 4.2: AIS dynamic individual paths
# Queries, processes, visualizes and analyses individual vessel tracks.
#
# Outputs:
#   01_data/task_4/task4_mmsi_2579999.csv
#   01_data/task_4/task4_mmsi_563040400.csv
#   01_data/task_4/task4_mmsi_211430830.csv
#   01_data/task_4/task4_detected_lock_events_211430830.csv
#   03_report/graphs/task4_mmsi_2579999.html
#   03_report/graphs/task4_mmsi_563040400.html
#   03_report/graphs/task4_mmsi_211430830_locks.html
#   03_report/task_4/task4_individual_paths_human.md
#   03_report/task_4/task4_individual_paths_ai.json

library(tidyverse)
library(readr)
library(jsonlite)
library(leaflet)
library(htmlwidgets)

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

# Helper functions for API queries, cleaning, summaries, leaflet maps and lock detection
source(file.path(root_dir, "02_code", "R", "functions", "task4_helpers.R"))

# -------------------------------------------------------------------------
# Output paths
# -------------------------------------------------------------------------

mmsi_2579999_csv <- file.path(data_dir, "task4_mmsi_2579999.csv")
mmsi_563040400_csv <- file.path(data_dir, "task4_mmsi_563040400.csv")
mmsi_211430830_csv <- file.path(data_dir, "task4_mmsi_211430830.csv")
lock_events_csv <- file.path(data_dir, "task4_detected_lock_events_211430830.csv")

map_2579999_html <- file.path(graph_dir, "task4_mmsi_2579999.html")
map_563040400_html <- file.path(graph_dir, "task4_mmsi_563040400.html")
lock_map_html <- file.path(graph_dir, "task4_mmsi_211430830_locks.html")

ai_summary_path <- file.path(report_dir, "task4_individual_paths_ai.json")
human_summary_path <- file.path(report_dir, "task4_individual_paths_human.md")

mmsi_2579999_csv_rel <- "01_data/task_4/task4_mmsi_2579999.csv"
mmsi_563040400_csv_rel <- "01_data/task_4/task4_mmsi_563040400.csv"
mmsi_211430830_csv_rel <- "01_data/task_4/task4_mmsi_211430830.csv"
lock_events_csv_rel <- "01_data/task_4/task4_detected_lock_events_211430830.csv"

map_2579999_html_rel <- "03_report/graphs/task4_mmsi_2579999.html"
map_563040400_html_rel <- "03_report/graphs/task4_mmsi_563040400.html"
lock_map_html_rel <- "03_report/graphs/task4_mmsi_211430830_locks.html"

ai_summary_path_rel <- "03_report/task_4/task4_individual_paths_ai.json"
human_summary_path_rel <- "03_report/task_4/task4_individual_paths_human.md"

# -------------------------------------------------------------------------
# 4.2a - Inspect suspicious MMSI 2579999
# -------------------------------------------------------------------------
# This MMSI appears online as either a navigation aid / base station and is also
# mentioned in an AIS base-station manual as a default MMSI. That makes it a
# likely non-vessel or configuration/test artefact rather than a normal moving ship.

mmsi_2579999_start <- "2021-01-01 00:00:00 UTC"
mmsi_2579999_end <- "2024-12-31 23:59:59 UTC"

mmsi_2579999 <- query_vessel_track(
  mmsi = 2579999,
  start_time = mmsi_2579999_start,
  end_time = mmsi_2579999_end,
  limit = 50000
)

write_csv(mmsi_2579999, mmsi_2579999_csv)
summary_2579999 <- summarise_track(mmsi_2579999)

if (nrow(mmsi_2579999) > 0) {
  map_2579999 <- make_track_map(
    mmsi_2579999,
    "Task 4.2: MMSI 2579999 - suspicious AIS identity",
    show_clusters = TRUE
  )
  
  save_leaflet_map(map_2579999, map_2579999_html)
}

# -------------------------------------------------------------------------
# 4.2b - Vessel MMSI 563040400
# -------------------------------------------------------------------------
# The broad time window below produced a coherent route in the checked run.
# It is still bounded by MMSI and time and therefore avoids unfiltered dynamic
# table queries.

mmsi_563040400_start <- "2021-01-01 00:00:00 UTC"
mmsi_563040400_end <- "2022-01-01 00:00:00 UTC"

mmsi_563040400 <- query_vessel_track(
  mmsi = 563040400,
  start_time = mmsi_563040400_start,
  end_time = mmsi_563040400_end,
  limit = 100000
)

write_csv(mmsi_563040400, mmsi_563040400_csv)
summary_563040400 <- summarise_track(mmsi_563040400)

if (nrow(mmsi_563040400) > 0) {
  map_563040400 <- make_track_map(
    mmsi_563040400,
    "Task 4.2: Track of MMSI 563040400",
    show_clusters = TRUE
  )
  
  save_leaflet_map(map_563040400, map_563040400_html)
}

# -------------------------------------------------------------------------
# 4.2c-e - Vessel MMSI 211430830, Vienna to Linz, lock detection
# -------------------------------------------------------------------------

mmsi_211430830_start <- "2021-01-17 00:00:00 UTC"
mmsi_211430830_end <- "2021-01-20 00:00:00 UTC"

mmsi_211430830 <- query_vessel_track(
  mmsi = 211430830,
  start_time = mmsi_211430830_start,
  end_time = mmsi_211430830_end,
  limit = 200000
)

write_csv(mmsi_211430830, mmsi_211430830_csv)
summary_211430830 <- summarise_track(mmsi_211430830)

lock_speed_threshold_kn <- 1
lock_max_time_gap_min <- 30
lock_max_step_distance_m <- 600
lock_min_duration_min <- 8
lock_min_observations <- 3

lock_events_211430830 <- detect_ship_locks(
  mmsi_211430830,
  speed_threshold_kn = lock_speed_threshold_kn,
  max_time_gap_min = lock_max_time_gap_min,
  max_step_distance_m = lock_max_step_distance_m,
  min_duration_min = lock_min_duration_min,
  min_observations = lock_min_observations
)

write_csv(lock_events_211430830, lock_events_csv)

if (nrow(mmsi_211430830) > 0) {
  
  lock_map_data <- mmsi_211430830 %>%
    filter(!is.na(latitude), !is.na(longitude)) %>%
    arrange(msg_timestamp) %>%
    mutate(
      speed_plot = if_else(is.na(speed), 0, speed),
      popup_text = paste0(
        "<b>Timestamp:</b> ", msg_timestamp, "<br>",
        "<b>Speed:</b> ", round(speed, 2), " kn<br>",
        "<b>Latitude:</b> ", round(latitude, 5), "<br>",
        "<b>Longitude:</b> ", round(longitude, 5)
      )
    )
  
  speed_pal <- colorNumeric(
    palette = "YlOrRd",
    domain = lock_map_data$speed_plot,
    na.color = "grey70"
  )
  
  lock_map <- leaflet(lock_map_data, options = leafletOptions(preferCanvas = TRUE)) %>%
    addProviderTiles(providers$CartoDB.Positron) %>%
    
    addPolylines(
      lng = ~longitude,
      lat = ~latitude,
      color = "grey40",
      weight = 2,
      opacity = 0.6,
      group = "Vessel route"
    ) %>%
    
    addCircleMarkers(
      lng = ~longitude,
      lat = ~latitude,
      radius = 3,
      stroke = FALSE,
      fillOpacity = 0.7,
      color = ~speed_pal(speed_plot),
      popup = ~popup_text,
      group = "AIS speed points"
    ) %>%
    
    addCircleMarkers(
      data = lock_events_211430830,
      lng = ~longitude,
      lat = ~latitude,
      radius = 8,
      color = "black",
      weight = 2,
      fillColor = "cyan",
      fillOpacity = 1,
      popup = ~paste0(
        "<b>Detected lock event</b><br>",
        "<b>Start:</b> ", start_time, "<br>",
        "<b>End:</b> ", end_time, "<br>",
        "<b>Duration:</b> ", round(duration_minutes, 1), " min<br>",
        "<b>Observations:</b> ", n_observations
      ),
      group = "Detected locks"
    ) %>%
    
    addLegend(
      position = "bottomright",
      pal = speed_pal,
      values = ~speed_plot,
      title = "Speed (kn)",
      opacity = 1
    ) %>%
    
    addLayersControl(
      overlayGroups = c("Vessel route", "AIS speed points", "Detected locks"),
      options = layersControlOptions(collapsed = FALSE)
    )
  
  save_leaflet_map(lock_map, lock_map_html)
}

# -------------------------------------------------------------------------
# Report-ready summaries
# -------------------------------------------------------------------------

ordered_detection_logic <- c(
  "1. Sort all AIS observations by `msg_timestamp`.",
  "2. Mark an observation as a potential lock point if speed is below 1 knot.",
  "3. Start a new lock group if the previous low-speed point is more than 30 minutes away or more than 600 metres away.",
  "4. Summarise each consecutive low-speed group by start time, end time, duration, mean latitude/longitude and number of observations.",
  "5. Keep only groups with at least 3 observations and at least 8 minutes duration.",
  "6. Interpret the remaining groups as potential ship-lock passages."
)

interpretation_2579999 <- paste(
  "MMSI 2579999 should be treated with caution.",
  "Online vessel-tracking sources list it as a navigation aid or base station rather than a normal ship,",
  "and an AIS base-station manual mentions 2579999 as a default MMSI that should be changed after setup.",
  "The generated map shows geographically inconsistent positions and implausible jumps across continents.",
  "Therefore, repeated positions for this identifier likely reflect a station, navigation aid, default configuration, or test/setup artefact instead of a single moving vessel."
)

interpretation_563040400 <- paste(
  "The AIS observations of MMSI 563040400 form a coherent and geographically plausible vessel track near the port area of Constanța in the Black Sea.",
  "The vessel follows a connected route with denser observations and lower speeds near the harbour area, suggesting manoeuvring or waiting behaviour.",
  "Movement further offshore appears more continuous and faster, which is consistent with normal vessel navigation."
)

interpretation_locks <- paste(
  "In AIS data, a ship lock typically appears as a local cluster of observations at nearly the same coordinates with very low speed.",
  "The vessel may spend several minutes or longer in the same area while waiting, entering, being raised or lowered, and leaving the lock.",
  "Compared with normal cruising segments, the observation density per location is higher and the trajectory shows a pause or bottleneck-like compression around the lock position."
)

limitations <- paste(
  "The rule-based detector is transparent but imperfect.",
  "It may confuse anchoring, waiting, congestion, port stops or missing GPS movement with lock passages.",
  "It may miss locks if AIS messages are sparse, if the vessel moves slowly for less than the minimum duration, or if position noise spreads points beyond the distance threshold.",
  "Improvements could use known lock coordinates, river network constraints, heading changes, acceleration/deceleration patterns, or clustering methods such as DBSCAN on latitude, longitude, speed and time."
)

unsupervised_extension <- paste(
  "An unsupervised alternative could cluster low-speed AIS points in space and time without labelled training data.",
  "For example, DBSCAN or HDBSCAN could identify dense clusters of stationary points, and clusters located along the route with plausible duration could be interpreted as candidate lock events."
)

ai_summary <- list(
  metadata = list(
    created_at = as.character(Sys.time()),
    base_url = api_base_url,
    root_dir = root_dir,
    data_dir = data_dir,
    report_dir = report_dir,
    graph_dir = graph_dir
  ),
  
  implementation_decisions = list(
    path_structure =
      "Task-specific CSV files are stored in 01_data/task_4. Task-specific text and JSON summaries are stored in 03_report/task_4. Interactive HTML maps are stored in 03_report/graphs because they are report figures/visualisations.",
    dynamic_table_strategy =
      "The large ais_dynamic table is never queried without filters. Every vessel track query is restricted by MMSI, time window and limit.",
    suspicious_mmsi_strategy =
      "MMSI 2579999 is analysed separately because it is likely not a normal moving ship but a navigation aid, base station, default configuration or test artefact.",
    lock_detection_strategy =
      "Ship-lock events are detected with transparent rule-based thresholds on low speed, time continuity, spatial compactness, minimum duration and minimum observations.",
    unsupervised_note =
      "An unsupervised alternative such as DBSCAN/HDBSCAN is discussed as a possible improvement but not required for the final rule-based implementation."
  ),
  
  mmsi_2579999 = list(
    mmsi = 2579999,
    time_window = paste(mmsi_2579999_start, "to", mmsi_2579999_end),
    summary = summary_2579999,
    interpretation = interpretation_2579999
  ),
  
  mmsi_563040400 = list(
    mmsi = 563040400,
    time_window = paste(mmsi_563040400_start, "to", mmsi_563040400_end),
    summary = summary_563040400,
    interpretation = interpretation_563040400
  ),
  
  mmsi_211430830 = list(
    mmsi = 211430830,
    time_window = paste(mmsi_211430830_start, "to", mmsi_211430830_end),
    summary = summary_211430830,
    lock_events = lock_events_211430830,
    n_detected_lock_events = nrow(lock_events_211430830),
    ship_lock_ais_pattern = interpretation_locks,
    detection_logic = ordered_detection_logic,
    thresholds = list(
      speed_threshold_kn = lock_speed_threshold_kn,
      max_time_gap_min = lock_max_time_gap_min,
      max_step_distance_m = lock_max_step_distance_m,
      min_duration_min = lock_min_duration_min,
      min_observations = lock_min_observations
    ),
    limitations = limitations,
    unsupervised_extension = unsupervised_extension
  ),
  
  outputs = list(
    mmsi_2579999_csv = mmsi_2579999_csv_rel,
    mmsi_563040400_csv = mmsi_563040400_csv_rel,
    mmsi_211430830_csv = mmsi_211430830_csv_rel,
    lock_events_csv = lock_events_csv_rel,
    maps = c(
      map_2579999_html_rel,
      map_563040400_html_rel,
      lock_map_html_rel
    ),
    ai_summary = ai_summary_path_rel,
    human_summary = human_summary_path_rel
  )
)

write_json(
  ai_summary,
  ai_summary_path,
  pretty = TRUE,
  auto_unbox = TRUE
)

human_md <- c(
  "# Task 4.2 Individual Vessel Paths Summary",
  "",
  paste0("Created at: ", ai_summary$metadata$created_at),
  "",
  "## Implementation notes",
  "",
  "The large `ais_dynamic` table was never queried without filters. All track queries were restricted by MMSI, time window and limit. CSV outputs are stored in `01_data/task_4`, task-specific summaries in `03_report/task_4`, and interactive map outputs in `03_report/graphs`.",
  "",
  "## MMSI 2579999",
  "",
  interpretation_2579999,
  "",
  paste0("Output map: `", map_2579999_html_rel, "`"),
  "",
  "## MMSI 563040400",
  "",
  interpretation_563040400,
  "",
  paste0("Output map: `", map_563040400_html_rel, "`"),
  "",
  "## MMSI 211430830 and ship-lock detection",
  "",
  interpretation_locks,
  "",
  paste0("Detected lock-event candidates: ", nrow(lock_events_211430830)),
  "",
  paste0("Output map: `", lock_map_html_rel, "`"),
  "",
  "### Detection thresholds",
  "",
  paste0("- Speed threshold: below ", lock_speed_threshold_kn, " knot. This marks points where the vessel is effectively stationary or manoeuvring very slowly."),
  paste0("- Maximum time gap inside one event: ", lock_max_time_gap_min, " minutes. Longer gaps are separated because they may represent missing data or different waiting phases."),
  paste0("- Maximum spatial step inside one event: ", lock_max_step_distance_m, " metres. This keeps one lock event spatially compact while allowing AIS/GPS noise and movement through the lock chamber."),
  paste0("- Minimum duration: ", lock_min_duration_min, " minutes and at least ", lock_min_observations, " observations. This removes short noise bursts that are unlikely to represent a complete lock passage."),
  "",
  "### Ordered detection logic",
  "",
  ordered_detection_logic,
  "",
  "### Limitations and improvement ideas",
  "",
  limitations,
  "",
  "### Optional unsupervised idea",
  "",
  unsupervised_extension,
  "",
  "## Outputs",
  "",
  paste0("- `", mmsi_2579999_csv_rel, "`"),
  paste0("- `", mmsi_563040400_csv_rel, "`"),
  paste0("- `", mmsi_211430830_csv_rel, "`"),
  paste0("- `", lock_events_csv_rel, "`"),
  paste0("- `", map_2579999_html_rel, "`"),
  paste0("- `", map_563040400_html_rel, "`"),
  paste0("- `", lock_map_html_rel, "`"),
  paste0("- `", ai_summary_path_rel, "`"),
  paste0("- `", human_summary_path_rel, "`")
)

write_lines(human_md, human_summary_path)

message("Task 4.2 completed.")
message("Created: ", mmsi_2579999_csv_rel)
message("Created: ", mmsi_563040400_csv_rel)
message("Created: ", mmsi_211430830_csv_rel)
message("Created: ", lock_events_csv_rel)
message("Created: ", map_2579999_html_rel)
message("Created: ", map_563040400_html_rel)
message("Created: ", lock_map_html_rel)
message("Created: ", ai_summary_path_rel)
message("Created: ", human_summary_path_rel)