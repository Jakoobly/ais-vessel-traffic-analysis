# Helper functions for THAS Task 4: Vessel Behaviour
# These functions are sourced by:
# - 02_code/R/task_4/sample_dashboard.R
# - 02_code/R/task_4/ais_dynamic_individual_paths.R
#
# Design notes:
# - Dynamic AIS queries are always filtered by MMSI and/or time window.
# - Leaflet point maps use markerClusterOptions() to avoid rendering too many
#   points at once.
# - Vessel speed is capped at 40 kn only for visualisation. The original speed
#   remains unchanged in the data and popups.

required_packages <- c(
  "tidyverse", "httr2", "jsonlite", "lubridate", "leaflet",
  "htmlwidgets", "geosphere", "htmltools"
)

missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0) {
  stop(
    "Missing required packages: ", paste(missing_packages, collapse = ", "),
    ". Install them before running this script."
  )
}

library(tidyverse)
library(httr2)
library(jsonlite)
library(lubridate)
library(leaflet)
library(htmlwidgets)
library(geosphere)
library(htmltools)

api_base_url <- "https://aidaho-edu.uni-hohenheim.de/aisdb"

ensure_task4_dirs <- function() {
  dir.create("01_data", recursive = TRUE, showWarnings = FALSE)
  dir.create("02_code/R/functions", recursive = TRUE, showWarnings = FALSE)
  dir.create("03_report", recursive = TRUE, showWarnings = FALSE)
  dir.create("03_report/graphs", recursive = TRUE, showWarnings = FALSE)
}

safe_api_get_raw <- function(path, query_string, timeout_seconds = 120, max_retries = 2) {
  url <- paste0(api_base_url, "/", path, "?", query_string)

  for (attempt in seq_len(max_retries + 1)) {
    result <- tryCatch(
      request(url) |>
        req_headers(Accept = "application/json") |>
        req_timeout(timeout_seconds) |>
        req_perform() |>
        resp_body_json(simplifyVector = TRUE) |>
        as_tibble(),
      error = function(e) e
    )

    if (!inherits(result, "error")) {
      return(result)
    }

    message("API request failed, attempt ", attempt, ": ", conditionMessage(result))

    if (attempt <= max_retries) {
      Sys.sleep(2)
    }
  }

  tibble()
}

query_vessel_track <- function(mmsi,
                               start_time = NULL,
                               end_time = NULL,
                               limit = 100000,
                               select_cols = "mmsi,msg_timestamp,latitude,longitude,speed,course,heading,collection_type") {
  query_parts <- c(
    paste0("select=", select_cols),
    paste0("mmsi=eq.", mmsi),
    "order=msg_timestamp.asc",
    paste0("limit=", limit)
  )

  if (!is.null(start_time)) {
    start_chr <- format(as_datetime(start_time, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ")
    query_parts <- c(query_parts, paste0("msg_timestamp=gte.", URLencode(start_chr, reserved = TRUE)))
  }

  if (!is.null(end_time)) {
    end_chr <- format(as_datetime(end_time, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ")
    query_parts <- c(query_parts, paste0("msg_timestamp=lt.", URLencode(end_chr, reserved = TRUE)))
  }

  safe_api_get_raw("ais_dynamic", paste(query_parts, collapse = "&")) |>
    clean_track_data()
}

query_vessel_window <- function(mmsi,
                                start_time,
                                end_time,
                                limit = 100000,
                                select_cols = "mmsi,msg_timestamp,latitude,longitude,speed,course,heading,collection_type") {
  query_vessel_track(
    mmsi = mmsi,
    start_time = start_time,
    end_time = end_time,
    limit = limit,
    select_cols = select_cols
  )
}

clean_track_data <- function(track_data) {
  if (nrow(track_data) == 0) {
    return(track_data)
  }

  track_data |>
    mutate(
      msg_timestamp = as_datetime(msg_timestamp, tz = "UTC"),
      latitude = as.numeric(latitude),
      longitude = as.numeric(longitude),
      speed = as.numeric(speed),
      collection_type = replace_na(as.character(collection_type), "Unknown")
    ) |>
    filter(
      !is.na(msg_timestamp),
      !is.na(latitude),
      !is.na(longitude),
      between(latitude, -90, 90),
      between(longitude, -180, 180)
    ) |>
    arrange(msg_timestamp)
}

safe_min <- function(x) {
  if (all(is.na(x))) NA_real_ else min(x, na.rm = TRUE)
}

safe_max <- function(x) {
  if (all(is.na(x))) NA_real_ else max(x, na.rm = TRUE)
}

safe_median <- function(x) {
  if (all(is.na(x))) NA_real_ else median(x, na.rm = TRUE)
}

summarise_track <- function(track_data) {
  track_data <- clean_track_data(track_data)

  if (nrow(track_data) == 0) {
    return(tibble())
  }

  track_data |>
    summarise(
      n_observations = n(),
      start_time = min(msg_timestamp, na.rm = TRUE),
      end_time = max(msg_timestamp, na.rm = TRUE),
      duration_hours = as.numeric(difftime(end_time, start_time, units = "hours")),
      min_latitude = min(latitude, na.rm = TRUE),
      max_latitude = max(latitude, na.rm = TRUE),
      min_longitude = min(longitude, na.rm = TRUE),
      max_longitude = max(longitude, na.rm = TRUE),
      median_speed_kn = safe_median(speed),
      max_speed_kn = safe_max(speed),
      n_collection_types = n_distinct(collection_type)
    )
}

make_speed_palette <- function() {
  leaflet::colorNumeric(
    palette = "YlOrRd",
    domain = c(0, 40),
    na.color = "#808080"
  )
}

add_popup_text <- function(data) {
  data |>
    mutate(
      speed_plot = pmin(speed, 40),
      popup_text = paste0(
        "<b>MMSI:</b> ", mmsi,
        "<br><b>Time:</b> ", msg_timestamp,
        "<br><b>Speed:</b> ", round(speed, 2), " kn",
        "<br><b>Collection:</b> ", collection_type,
        "<br><b>Lat/Lon:</b> ", round(latitude, 5), ", ", round(longitude, 5)
      )
    )
}

make_sample_map <- function(sample_data,
                            map_title = "AIS sample points") {
  
  sample_data <- sample_data |>
    clean_track_data() |>
    add_popup_text()
  
  if (nrow(sample_data) == 0) {
    stop("No valid sample points available for the map.")
  }
  
  speed_pal <- make_speed_palette()
  
  leaflet(
    sample_data,
    options = leafletOptions(
      zoomControl = TRUE,
      minZoom = 1,
      worldCopyJump = TRUE
    )
  ) |>
    
    # Clean map style
    addProviderTiles(providers$CartoDB.Positron) |>
    
    # NEW: start slightly zoomed in
    # still shows the full world but closer
    setView(
      lng = 8,
      lat = 18,
      zoom = 3
    ) |>
    
    addCircleMarkers(
      lng = ~longitude,
      lat = ~latitude,
      radius = 4,
      stroke = FALSE,
      fillOpacity = 0.75,
      color = ~speed_pal(speed_plot),
      popup = ~popup_text,
      clusterOptions = markerClusterOptions(
        spiderfyOnMaxZoom = TRUE,
        showCoverageOnHover = FALSE,
        zoomToBoundsOnClick = TRUE
      )
    ) |>
    
    addLegend(
      position = "bottomright",
      pal = speed_pal,
      values = c(0, 40),
      title = "Speed over ground<br>(kn, capped at 40)",
      opacity = 0.9
    ) |>
    
    addControl(
      html = htmltools::tags$div(
        style = paste(
          "background: rgba(255,255,255,0.95);",
          "padding: 10px 14px;",
          "border-radius: 10px;",
          "box-shadow: 0 2px 10px rgba(0,0,0,0.15);",
          "font-weight: bold;",
          "font-family: Arial, sans-serif;"
        ),
        map_title
      ),
      position = "topright"
    )
}

save_leaflet_map <- function(map_object, html_path, screenshot_path = NULL) {
  # selfcontained = FALSE avoids a hard dependency on pandoc and is robust in RStudio.
  htmlwidgets::saveWidget(map_object, html_path, selfcontained = FALSE)

  if (!is.null(screenshot_path) && requireNamespace("webshot2", quietly = TRUE)) {
    tryCatch(
      webshot2::webshot(html_path, screenshot_path, vwidth = 1400, vheight = 900, delay = 2),
      error = function(e) {
        message("Screenshot skipped: ", conditionMessage(e))
      }
    )
  } else if (!is.null(screenshot_path)) {
    message("Optional package webshot2 not installed. HTML map was saved, screenshot skipped: ", screenshot_path)
  }
}

make_track_map <- function(track_data, title = "Vessel track", show_clusters = TRUE) {
  track_data <- track_data |>
    clean_track_data() |>
    add_popup_text()

  if (nrow(track_data) == 0) {
    stop("No valid track data available for the map.")
  }

  speed_pal <- make_speed_palette()
  cluster_arg <- if (show_clusters) markerClusterOptions() else NULL

  leaflet(track_data) |>
    addProviderTiles(providers$CartoDB.Positron) |>
    addPolylines(
      lng = ~longitude,
      lat = ~latitude,
      color = "#2C3E50",
      weight = 2,
      opacity = 0.8,
      group = "Vessel route"
    ) |>
    addCircleMarkers(
      lng = ~longitude,
      lat = ~latitude,
      radius = 4,
      stroke = FALSE,
      fillOpacity = 0.75,
      color = ~speed_pal(speed_plot),
      popup = ~popup_text,
      group = "AIS observations",
      clusterOptions = cluster_arg
    ) |>
    addLegend(
      position = "bottomright",
      pal = speed_pal,
      values = c(0, 40),
      title = "Speed over ground<br>(kn, capped at 40)",
      opacity = 0.9
    ) |>
    addControl(
      html = htmltools::tags$div(
        style = "background: rgba(255,255,255,0.9); padding: 8px; border-radius: 4px; font-weight: bold;",
        title
      ),
      position = "topright"
    ) |>
    addLayersControl(
      overlayGroups = c("Vessel route", "AIS observations"),
      options = layersControlOptions(collapsed = FALSE)
    )
}

add_movement_metrics <- function(track_data) {
  track_data |>
    arrange(msg_timestamp) |>
    mutate(
      prev_latitude = lag(latitude),
      prev_longitude = lag(longitude),
      prev_time = lag(msg_timestamp),
      time_gap_min = as.numeric(difftime(msg_timestamp, prev_time, units = "mins")),
      step_distance_m = geosphere::distHaversine(
        cbind(prev_longitude, prev_latitude),
        cbind(longitude, latitude)
      ),
      step_distance_m = if_else(
        is.na(prev_longitude) | is.na(prev_latitude),
        NA_real_,
        step_distance_m
      )
    )
}

detect_ship_locks <- function(track_data,
                              speed_threshold_kn = 1,
                              max_time_gap_min = 30,
                              max_step_distance_m = 600,
                              min_duration_min = 8,
                              min_observations = 3) {
  prepared <- track_data |>
    clean_track_data() |>
    add_movement_metrics() |>
    mutate(
      low_speed = !is.na(speed) & speed < speed_threshold_kn,
      starts_new_group = low_speed & (
        row_number() == 1 |
          !lag(low_speed, default = FALSE) |
          is.na(time_gap_min) |
          time_gap_min > max_time_gap_min |
          is.na(step_distance_m) |
          step_distance_m > max_step_distance_m
      ),
      lock_group = cumsum(replace_na(starts_new_group, FALSE)),
      lock_group = if_else(low_speed, lock_group, NA_integer_)
    )

  lock_points <- prepared |>
    filter(low_speed, !is.na(lock_group))

  if (nrow(lock_points) == 0) {
    return(tibble(
      lock_id = integer(),
      start_time = as.POSIXct(character(), tz = "UTC"),
      end_time = as.POSIXct(character(), tz = "UTC"),
      duration_minutes = numeric(),
      latitude = numeric(),
      longitude = numeric(),
      n_observations = integer(),
      median_speed_kn = numeric()
    ))
  }

  lock_points |>
    group_by(lock_group) |>
    summarise(
      start_time = min(msg_timestamp),
      end_time = max(msg_timestamp),
      duration_minutes = as.numeric(difftime(end_time, start_time, units = "mins")),
      latitude = mean(latitude, na.rm = TRUE),
      longitude = mean(longitude, na.rm = TRUE),
      n_observations = n(),
      median_speed_kn = median(speed, na.rm = TRUE),
      .groups = "drop"
    ) |>
    filter(
      duration_minutes >= min_duration_min,
      n_observations >= min_observations
    ) |>
    arrange(start_time) |>
    mutate(lock_id = row_number(), .before = 1)
}

make_lock_map <- function(track_data, lock_events, title = "Trajectory and detected lock events") {
  track_data <- track_data |>
    clean_track_data() |>
    add_popup_text()

  if (nrow(track_data) == 0) {
    stop("No valid track data available for the lock map.")
  }

  speed_pal <- make_speed_palette()

  lock_popup <- if (nrow(lock_events) > 0) {
    paste0(
      "<b>Detected lock event ", lock_events$lock_id, "</b>",
      "<br><b>Start:</b> ", lock_events$start_time,
      "<br><b>End:</b> ", lock_events$end_time,
      "<br><b>Duration:</b> ", round(lock_events$duration_minutes, 1), " min",
      "<br><b>Observations:</b> ", lock_events$n_observations
    )
  } else {
    character(0)
  }

  map <- leaflet(track_data) |>
    addProviderTiles(providers$CartoDB.Positron) |>
    addPolylines(
      lng = ~longitude,
      lat = ~latitude,
      color = "#2C3E50",
      weight = 3,
      opacity = 0.8,
      group = "Vessel route"
    ) |>
    addCircleMarkers(
      lng = ~longitude,
      lat = ~latitude,
      radius = 3,
      stroke = FALSE,
      fillOpacity = 0.45,
      color = ~speed_pal(speed_plot),
      popup = ~popup_text,
      group = "AIS observations",
      clusterOptions = markerClusterOptions()
    ) |>
    addLegend(
      position = "bottomright",
      pal = speed_pal,
      values = c(0, 40),
      title = "Speed over ground<br>(kn, capped at 40)",
      opacity = 0.9
    ) |>
    addControl(
      html = htmltools::tags$div(
        style = "background: rgba(255,255,255,0.9); padding: 8px; border-radius: 4px; font-weight: bold;",
        title
      ),
      position = "topright"
    )

  if (nrow(lock_events) > 0) {
    map <- map |>
      addCircleMarkers(
        data = lock_events,
        lng = ~longitude,
        lat = ~latitude,
        radius = 14,
        stroke = TRUE,
        weight = 3,
        color = "#D7263D",
        fillColor = "#D7263D",
        fillOpacity = 1,
        popup = lock_popup,
        group = "Detected lock passages"
      )
  }

  map |>
    addLayersControl(
      overlayGroups = c("Vessel route", "AIS observations", "Detected lock passages"),
      options = layersControlOptions(collapsed = FALSE)
    )
}
