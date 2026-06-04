# Helper functions for THAS Task 5: AIS Traffic Density
# -----------------------------------------------------
# Helpers are intentionally small and explicit. They keep the main script tidy,
# reduce repeated code, and make API and geometry steps easier to debug.

create_project_dirs <- function(root = getwd()) {
  dirs <- file.path(
    root,
    c("01_data", "03_report", "03_report/graphs")
  )
  
  purrr::walk(
    dirs,
    dir.create,
    recursive = TRUE,
    showWarnings = FALSE
  )
  
  invisible(dirs)
}

postgrest_url <- function(base_url, table, params = list()) {
  # Build a URL with proper URL encoding and support for repeated query names,
  # e.g. msg_timestamp=gte... and msg_timestamp=lt... in one PostgREST request.
  base <- paste0(base_url, table)
  if (length(params) == 0) return(base)

  encode <- function(x) utils::URLencode(as.character(x), reserved = TRUE)

  query_parts <- purrr::imap(params, function(value, name) {
    paste0(encode(name), "=", encode(value))
  }) |>
    unlist(use.names = FALSE)

  paste0(base, "?", paste(query_parts, collapse = "&"))
}

api_get_page <- function(url, timeout_seconds = 180, verbose = TRUE) {
  response <- httr::GET(url, httr::timeout(timeout_seconds))
  body <- httr::content(response, as = "text", encoding = "UTF-8")

  if (httr::http_error(response)) {
    stop(
      "API request failed with HTTP ", httr::status_code(response), ".\n",
      "URL: ", url, "\n",
      "Response body: ", substr(body, 1, 1000),
      call. = FALSE
    )
  }

  if (identical(body, "[]") || nchar(body) == 0) {
    return(tibble::tibble())
  }

  jsonlite::fromJSON(body, flatten = TRUE) |>
    tibble::as_tibble()
}

api_get_paginated <- function(base_url, table, params = list(), page_size = 50000, max_pages = Inf) {
  # Uses limit/offset pagination so that each request stays small enough for the
  # shared THAS server. `params` should already contain all filters.
  offset <- 0
  page <- 1
  output <- list()

  repeat {
    page_params <- c(params, list(limit = page_size, offset = offset))
    page_url <- postgrest_url(base_url, table, page_params)

    message("Downloading page ", page, " from ", table, " ...")
    page_data <- api_get_page(page_url)
    output[[page]] <- page_data

    if (nrow(page_data) < page_size || page >= max_pages) break

    offset <- offset + page_size
    page <- page + 1
  }

  dplyr::bind_rows(output)
}

probe_table_columns <- function(base_url, table) {
  # A one-row query is cheap and reveals the actual column names. This prevents
  # HTTP 400 errors when a table differs slightly from ais_dynamic/ais_static.
  x <- api_get_page(postgrest_url(base_url, table, list(limit = 1)))
  names(x)
}

pick_first_existing <- function(columns, candidates, what) {
  hit <- candidates[tolower(candidates) %in% tolower(columns)][1]
  if (is.na(hit)) {
    stop("Could not find a usable ", what, " column. Available columns are: ",
         paste(columns, collapse = ", "), call. = FALSE)
  }
  columns[match(tolower(hit), tolower(columns))]
}

download_ais_germany_day <- function(base_url, analysis_date, page_size = 50000) {
  columns <- probe_table_columns(base_url, "ais_germany")

  time_col <- pick_first_existing(
    columns,
    c("msg_timestamp", "timestamp", "created_at", "position_updated_at", "datetime", "date_time"),
    "timestamp"
  )
  lat_col <- pick_first_existing(columns, c("latitude", "lat"), "latitude")
  lon_col <- pick_first_existing(columns, c("longitude", "lon", "lng"), "longitude")

  optional_cols <- intersect(
    c("mmsi", "speed", "course", "heading", "collection_type", "ship_type", "name", "flag"),
    columns
  )

  selected_cols <- unique(c(optional_cols, time_col, lat_col, lon_col))

  # Important fix: do not add latitude=not.is.null in the API query. Some
  # PostgREST configurations reject this filter depending on schema exposure.
  # We filter missing coordinates locally after the date-restricted download.
  params <- list(
    select = paste(selected_cols, collapse = ",")
  )
  params[[time_col]] <- c(
    paste0("gte.", analysis_date, "T00:00:00Z"),
    paste0("lt.", analysis_date + 1, "T00:00:00Z")
  )

  out <- api_get_paginated(
    base_url = base_url,
    table = "ais_germany",
    params = params,
    page_size = page_size
  ) |>
    janitor::clean_names()

  # Standardise column names for all later steps.
  time_clean <- janitor::make_clean_names(time_col)
  lat_clean <- janitor::make_clean_names(lat_col)
  lon_clean <- janitor::make_clean_names(lon_col)

  out |>
    dplyr::rename(
      msg_timestamp = dplyr::all_of(time_clean),
      latitude = dplyr::all_of(lat_clean),
      longitude = dplyr::all_of(lon_clean)
    ) |>
    dplyr::mutate(
      msg_timestamp = lubridate::ymd_hms(msg_timestamp, tz = "UTC", quiet = TRUE),
      dplyr::across(dplyr::any_of(c("latitude", "longitude", "speed")), as.numeric),
      row_id = dplyr::row_number()
    ) |>
    dplyr::filter(
      !is.na(latitude), !is.na(longitude),
      dplyr::between(latitude, 45, 56),
      dplyr::between(longitude, 4, 16)
    )
}

add_static_ship_type_if_needed <- function(ais_data, base_url) {
  if ("ship_type" %in% names(ais_data)) {
    return(ais_data |>
             dplyr::mutate(ship_type = tidyr::replace_na(as.character(ship_type), "Unknown")))
  }

  if (!"mmsi" %in% names(ais_data)) {
    return(ais_data |> dplyr::mutate(ship_type = "Unknown"))
  }

  message("ais_germany has no ship_type column; joining ship_type from ais_static by mmsi ...")
  ais_static <- api_get_paginated(
    base_url = base_url,
    table = "ais_static",
    params = list(select = "mmsi,ship_type"),
    page_size = 50000
  ) |>
    janitor::clean_names() |>
    dplyr::mutate(ship_type = tidyr::replace_na(as.character(ship_type), "Unknown")) |>
    dplyr::distinct(mmsi, .keep_all = TRUE)

  ais_data |>
    dplyr::left_join(ais_static, by = "mmsi") |>
    dplyr::mutate(ship_type = tidyr::replace_na(as.character(ship_type), "Unknown"))
}

normalise_collection_type <- function(ais_data) {
  if ("collection_type" %in% names(ais_data)) {
    ais_data |>
      dplyr::mutate(collection_type = tidyr::replace_na(as.character(collection_type), "Unknown"))
  } else {
    ais_data |>
      dplyr::mutate(collection_type = "Unknown")
  }
}

get_german_rivers <- function(major_river_pattern) {
  germany <- rnaturalearth::ne_countries(
    country = "Germany",
    scale = "medium",
    returnclass = "sf"
  ) |>
    sf::st_transform(4326)

  rivers_raw <- rnaturalearth::ne_download(
    scale = 10,
    type = "rivers_lake_centerlines",
    category = "physical",
    returnclass = "sf"
  ) |>
    sf::st_transform(4326) |>
    sf::st_make_valid()

  river_name_col <- dplyr::case_when(
    "name" %in% names(rivers_raw) ~ "name",
    "name_en" %in% names(rivers_raw) ~ "name_en",
    TRUE ~ NA_character_
  )

  if (is.na(river_name_col)) {
    stop("The Natural Earth river data did not contain a usable river name column.", call. = FALSE)
  }

  rivers_raw |>
    dplyr::mutate(river_name = as.character(.data[[river_name_col]])) |>
    dplyr::filter(!is.na(river_name), river_name != "") |>
    dplyr::filter(lengths(sf::st_intersects(geometry, germany)) > 0) |>
    dplyr::filter(stringr::str_detect(river_name, major_river_pattern)) |>
    dplyr::group_by(river_name) |>
    dplyr::summarise(geometry = sf::st_union(geometry), .groups = "drop") |>
    sf::st_make_valid()
}

point_h3_index <- function(sf_points, resolution = 7) {
  result <- try(
    h3jsr::point_to_cell(sf_points, res = resolution, simple = TRUE),
    silent = TRUE
  )

  if (!inherits(result, "try-error")) {
    return(as.character(result))
  }

  coords <- sf::st_coordinates(sf_points)
  h3jsr::point_to_cell(
    data.frame(lng = coords[, "X"], lat = coords[, "Y"]),
    res = resolution,
    simple = TRUE
  ) |>
    as.character()
}

river_h3_cells <- function(rivers_sf, resolution = 7, buffer_m = 1500) {
  rivers_buffered <- rivers_sf |>
    sf::st_transform(3035) |>
    sf::st_buffer(buffer_m) |>
    sf::st_transform(4326) |>
    sf::st_make_valid()

  purrr::map2_dfr(
    rivers_buffered$river_name,
    rivers_buffered$geometry,
    function(river_name, geometry) {
      one_river <- sf::st_sf(river_name = river_name, geometry = sf::st_sfc(geometry, crs = 4326))

      cells <- h3jsr::polygon_to_cells(one_river, res = resolution, simple = TRUE) |>
        unlist(use.names = FALSE) |>
        as.character() |>
        unique()

      tibble::tibble(river_name = river_name, h3_index = cells)
    }
  ) |>
    dplyr::distinct(river_name, h3_index)
}

assign_nearest_river <- function(ais_sf, candidate_matches, rivers_sf) {
  # Fast assignment rule for Task 5.2(c):
  # 1) H3 identifies candidate river cells.
  # 2) AIS points with one candidate are assigned directly.
  # 3) AIS points with multiple candidates are assigned to the nearest original
  #    river geometry using sf::st_nearest_feature(). This is much faster than
  #    calculating a full distance matrix row by row.

  candidate_tbl <- candidate_matches |>
    sf::st_drop_geometry() |>
    dplyr::distinct(row_id, river_name)

  matched_ids <- candidate_tbl |>
    dplyr::distinct(row_id)

  unmatched <- ais_sf |>
    sf::st_drop_geometry() |>
    dplyr::distinct(row_id) |>
    dplyr::anti_join(matched_ids, by = "row_id") |>
    dplyr::mutate(on_river = FALSE, river_name = NA_character_)

  if (nrow(candidate_tbl) == 0) {
    return(unmatched)
  }

  match_counts <- candidate_tbl |>
    dplyr::count(row_id, name = "n_candidate_rivers")

  single_matches <- candidate_tbl |>
    dplyr::left_join(match_counts, by = "row_id") |>
    dplyr::filter(n_candidate_rivers == 1) |>
    dplyr::transmute(row_id, on_river = TRUE, river_name)

  ambiguous_ids <- match_counts |>
    dplyr::filter(n_candidate_rivers > 1) |>
    dplyr::pull(row_id)

  if (length(ambiguous_ids) == 0) {
    return(dplyr::bind_rows(single_matches, unmatched) |>
             dplyr::distinct(row_id, .keep_all = TRUE))
  }

  message("Resolving ", length(ambiguous_ids),
          " AIS records with multiple river matches using fast nearest-feature rule ...")

  # Use each ambiguous AIS point only once. `st_nearest_feature()` is vectorised
  # and returns the nearest river geometry without building a full n x m matrix.
  ambiguous_points <- ais_sf |>
    dplyr::filter(row_id %in% ambiguous_ids) |>
    dplyr::select(row_id) |>
    sf::st_transform(3035)

  rivers_projected <- rivers_sf |>
    dplyr::select(river_name) |>
    sf::st_transform(3035)

  nearest_idx <- sf::st_nearest_feature(ambiguous_points, rivers_projected)

  ambiguous_assignment <- tibble::tibble(
    row_id = ambiguous_points$row_id,
    on_river = TRUE,
    river_name = rivers_projected$river_name[nearest_idx]
  )

  dplyr::bind_rows(single_matches, ambiguous_assignment, unmatched) |>
    dplyr::distinct(row_id, .keep_all = TRUE)
}

get_main_line <- function(line_sf) {
  line_sf |>
    sf::st_cast("LINESTRING", warn = FALSE) |>
    dplyr::mutate(length_m = as.numeric(sf::st_length(geometry))) |>
    dplyr::slice_max(length_m, n = 1, with_ties = FALSE)
}

# Approximate projection of points onto a LINESTRING without relying on lwgeom.
# For each point, this finds the nearest line segment and returns the cumulative
# distance from the first line coordinate to the projected point. This is a
# transparent approximation and is sufficient for 10 km traffic-density bins.
distance_along_line_km <- function(points_sf, line_geometry) {
  if (nrow(points_sf) == 0) return(numeric(0))

  line_coords <- sf::st_coordinates(line_geometry)[, c("X", "Y"), drop = FALSE]
  if (nrow(line_coords) < 2) {
    stop("Rhine geometry has too few coordinates to calculate along-line distances.", call. = FALSE)
  }

  point_coords <- sf::st_coordinates(points_sf)[, c("X", "Y"), drop = FALSE]

  seg_start <- line_coords[-nrow(line_coords), , drop = FALSE]
  seg_end <- line_coords[-1, , drop = FALSE]
  seg_vec <- seg_end - seg_start
  seg_len2 <- rowSums(seg_vec^2)
  seg_len <- sqrt(seg_len2)
  cum_len <- c(0, cumsum(seg_len))

  purrr::map_dbl(seq_len(nrow(point_coords)), function(i) {
    p <- point_coords[i, ]
    rel <- sweep(seg_start, 2, p, FUN = "-")

    # projection parameter t on each segment, clamped to [0, 1]
    t <- rowSums(sweep(seg_start, 2, p, FUN = "-") * seg_vec) / seg_len2
    # Equivalent direction correction: use (p - start) dot vec.
    t <- rowSums(sweep(matrix(p, nrow = nrow(seg_start), ncol = 2, byrow = TRUE), 2, seg_start, FUN = "-") * seg_vec) / seg_len2
    t <- pmin(1, pmax(0, t))

    proj <- seg_start + seg_vec * t
    d2 <- rowSums((proj - matrix(p, nrow = nrow(proj), ncol = 2, byrow = TRUE))^2)
    best <- which.min(d2)

    (cum_len[best] + t[best] * seg_len[best]) / 1000
  })
}

write_markdown_summary <- function(path, lines) {
  readr::write_lines(lines, path)
  invisible(path)
}
