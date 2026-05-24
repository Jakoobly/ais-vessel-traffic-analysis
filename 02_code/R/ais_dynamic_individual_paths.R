# THAS 2026 - Task 4.2: AIS dynamic individual paths
# Queries, processes, visualizes and analyses individual vessel tracks.
#
# Outputs:
# - 01_data/task4_mmsi_2579999.csv
# - 01_data/task4_mmsi_563040400.csv
# - 01_data/task4_mmsi_211430830.csv
# - 01_data/task4_detected_lock_events_211430830.csv
# - 03_report/graphs/task4_mmsi_2579999.html
# - 03_report/graphs/task4_mmsi_563040400.html
# - 03_report/graphs/task4_mmsi_211430830_locks.html
# - 03_report/task4_individual_paths_human.md
# - 03_report/task4_individual_paths_ai.json

source("02_code/R/functions/task4_helpers.R")
ensure_task4_dirs()

# -------------------------------------------------------------------------
# 4.2a - Inspect suspicious MMSI 2579999
# -------------------------------------------------------------------------
# This MMSI appears online as either a navigation aid / base station and is also
# mentioned in an AIS base-station manual as a default MMSI. That makes it a
# likely non-vessel or configuration/test artefact rather than a normal moving ship.

mmsi_2579999 <- query_vessel_track(
  mmsi = 2579999,
  start_time = "2021-01-01 00:00:00 UTC",
  end_time = "2024-12-31 23:59:59 UTC",
  limit = 50000
)

readr::write_csv(mmsi_2579999, "01_data/task4_mmsi_2579999.csv")
summary_2579999 <- summarise_track(mmsi_2579999)

if (nrow(mmsi_2579999) > 0) {
  map_2579999 <- make_track_map(
    mmsi_2579999,
    "Task 4.2a: MMSI 2579999 - suspicious AIS identity",
    show_clusters = TRUE
  )
  save_leaflet_map(map_2579999, "03_report/graphs/task4_mmsi_2579999.html")
}

# -------------------------------------------------------------------------
# 4.2b - Vessel MMSI 563040400
# -------------------------------------------------------------------------
# The broad time window below produced a coherent route in the checked run.
# It is still bounded by MMSI and time and therefore avoids unfiltered dynamic
# table queries.

mmsi_563040400 <- query_vessel_track(
  mmsi = 563040400,
  start_time = "2021-01-01 00:00:00 UTC",
  end_time = "2022-01-01 00:00:00 UTC",
  limit = 100000
)

readr::write_csv(mmsi_563040400, "01_data/task4_mmsi_563040400.csv")
summary_563040400 <- summarise_track(mmsi_563040400)

if (nrow(mmsi_563040400) > 0) {
  map_563040400 <- make_track_map(
    mmsi_563040400,
    "Task 4.2b: Track of MMSI 563040400",
    show_clusters = TRUE
  )
  save_leaflet_map(map_563040400, "03_report/graphs/task4_mmsi_563040400.html")
}

# -------------------------------------------------------------------------
# 4.2c-e - Vessel MMSI 211430830, Vienna to Linz, lock detection
# -------------------------------------------------------------------------

mmsi_211430830 <- query_vessel_track(
  mmsi = 211430830,
  start_time = "2021-01-17 00:00:00 UTC",
  end_time = "2021-01-20 00:00:00 UTC",
  limit = 200000
)

readr::write_csv(mmsi_211430830, "01_data/task4_mmsi_211430830.csv")
summary_211430830 <- summarise_track(mmsi_211430830)

lock_events_211430830 <- detect_ship_locks(
  mmsi_211430830,
  speed_threshold_kn = 1,
  max_time_gap_min = 30,
  max_step_distance_m = 600,
  min_duration_min = 8,
  min_observations = 3
)

readr::write_csv(lock_events_211430830, "01_data/task4_detected_lock_events_211430830.csv")

if (nrow(mmsi_211430830) > 0) {
  lock_map <- make_lock_map(
    mmsi_211430830,
    lock_events_211430830,
    "Task 4.2e: MMSI 211430830 route and detected lock passages"
  )
  save_leaflet_map(lock_map, "03_report/graphs/task4_mmsi_211430830_locks.html")
}

# -------------------------------------------------------------------------
# Report-ready summaries
# -------------------------------------------------------------------------

ordered_detection_logic <- c(
  "1. Sort all AIS observations by msg_timestamp.",
  "2. Mark an observation as a potential lock point if speed is below 1 knot.",
  "3. Start a new lock group if the previous low-speed point is more than 30 minutes away or more than 600 metres away.",
  "4. Summarise each consecutive low-speed group by start time, end time, duration, mean latitude/longitude and number of observations.",
  "5. Keep only groups with at least 3 observations and at least 8 minutes duration.",
  "6. Interpret the remaining groups as potential ship-lock passages."
)

interpretation_2579999 <- paste(
  "MMSI 2579999 should be treated with caution. Online vessel-tracking sources list it as a navigation aid or base station rather than a normal ship,",
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
  "The rule-based detector is transparent but imperfect. It may confuse anchoring, waiting, congestion, port stops or missing GPS movement with lock passages.",
  "It may miss locks if AIS messages are sparse, if the vessel moves slowly for less than the minimum duration, or if position noise spreads points beyond the distance threshold.",
  "Improvements could use known lock coordinates, river network constraints, heading changes, acceleration/deceleration patterns, or clustering methods such as DBSCAN on latitude, longitude, speed and time."
)

unsupervised_extension <- paste(
  "An unsupervised alternative could cluster low-speed AIS points in space and time without labelled training data.",
  "For example, DBSCAN or HDBSCAN could identify dense clusters of stationary points, and clusters located along the route with plausible duration could be interpreted as candidate lock events."
)

ai_summary <- list(
  metadata = list(created_at = as.character(Sys.time()), base_url = api_base_url),
  mmsi_2579999 = list(summary = summary_2579999, interpretation = interpretation_2579999),
  mmsi_563040400 = list(summary = summary_563040400, interpretation = interpretation_563040400),
  mmsi_211430830 = list(
    time_window = "2021-01-17 00:00:00 UTC to 2021-01-20 00:00:00 UTC",
    summary = summary_211430830,
    lock_events = lock_events_211430830,
    ship_lock_ais_pattern = interpretation_locks,
    detection_logic = ordered_detection_logic,
    thresholds = list(
      speed_threshold_kn = 1,
      max_time_gap_min = 30,
      max_step_distance_m = 600,
      min_duration_min = 8,
      min_observations = 3
    ),
    limitations = limitations,
    unsupervised_extension = unsupervised_extension
  ),
  outputs = list(
    mmsi_2579999_csv = "01_data/task4_mmsi_2579999.csv",
    mmsi_563040400_csv = "01_data/task4_mmsi_563040400.csv",
    mmsi_211430830_csv = "01_data/task4_mmsi_211430830.csv",
    lock_events_csv = "01_data/task4_detected_lock_events_211430830.csv",
    maps = c(
      "03_report/graphs/task4_mmsi_2579999.html",
      "03_report/graphs/task4_mmsi_563040400.html",
      "03_report/graphs/task4_mmsi_211430830_locks.html"
    )
  )
)

jsonlite::write_json(
  ai_summary,
  "03_report/task4_individual_paths_ai.json",
  pretty = TRUE,
  auto_unbox = TRUE
)

human_md <- c(
  "# Task 4.2 Individual Vessel Paths Summary",
  "",
  "## MMSI 2579999",
  "",
  interpretation_2579999,
  "",
  "## MMSI 563040400",
  "",
  interpretation_563040400,
  "",
  "## MMSI 211430830 and ship-lock detection",
  "",
  interpretation_locks,
  "",
  "### Detection thresholds",
  "",
  "- Speed threshold: below 1 knot. This marks points where the vessel is effectively stationary or manoeuvring very slowly.",
  "- Maximum time gap inside one event: 30 minutes. Longer gaps are separated because they may represent missing data or different waiting phases.",
  "- Maximum spatial step inside one event: 600 metres. This keeps one lock event spatially compact while allowing AIS/GPS noise and movement through the lock chamber.",
  "- Minimum duration: 8 minutes and at least 3 observations. This removes short noise bursts that are unlikely to represent a complete lock passage.",
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
  "- `01_data/task4_mmsi_2579999.csv`",
  "- `01_data/task4_mmsi_563040400.csv`",
  "- `01_data/task4_mmsi_211430830.csv`",
  "- `01_data/task4_detected_lock_events_211430830.csv`",
  "- `03_report/graphs/task4_mmsi_2579999.html`",
  "- `03_report/graphs/task4_mmsi_563040400.html`",
  "- `03_report/graphs/task4_mmsi_211430830_locks.html`"
)

readr::write_lines(human_md, "03_report/task4_individual_paths_human.md")

message("Task 4.2 done.")
message("Created individual path CSV files, detected lock table and leaflet HTML maps.")
