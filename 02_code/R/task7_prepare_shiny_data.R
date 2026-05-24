# THAS Task 7: prepare data for the Shiny app
# ------------------------------------------------------------
# This script preprocesses the river traffic-density data used by the
# deployed Shiny app. The app then reads a prepared CSV instead of sending
# expensive API requests while users interact with it.

required_packages <- c("tidyverse", "sf", "here")
purrr::walk(required_packages, function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("Please install missing package: ", pkg, call. = FALSE)
  }
})

suppressPackageStartupMessages({
  library(tidyverse)
  library(sf)
  library(here)
})

# Robust helper sourcing from the required repository structure.
helper_file <- here::here("02_code", "R", "functions", "task5_helpers.R")
if (!file.exists(helper_file)) {
  stop("Could not find 02_code/R/functions/task5_helpers.R.", call. = FALSE)
}
source(helper_file)

input_points <- here::here("01_data", "task5_ais_germany_2022_04_23_classified.csv")
input_rivers <- here::here("01_data", "task5_german_rivers.rds")
output_file <- here::here("01_data", "task7_shiny_traffic_density.csv")

if (!file.exists(input_points)) {
  stop("Missing classified AIS file from Task 5: ", input_points, call. = FALSE)
}
if (!file.exists(input_rivers)) {
  stop("Missing river geometries from Task 5: ", input_rivers, call. = FALSE)
}

classified <- readr::read_csv(input_points, show_col_types = FALSE) |>
  filter(on_river, !is.na(river_name), !is.na(latitude), !is.na(longitude)) |>
  mutate(
    ship_type = if_else(is.na(ship_type) | ship_type == "", "Unknown", ship_type),
    river_name = as.character(river_name)
  )

german_rivers <- readr::read_rds(input_rivers)

# Calculates approximate along-river distance for one selected river.
# The line orientation is inherited from the Natural Earth geometry, as in Task 5.2(g).
calculate_river_density <- function(selected_river, bin_width_km = 10) {
  river_geometry <- german_rivers |>
    filter(river_name == selected_river) |>
    summarise(geometry = st_union(geometry), .groups = "drop") |>
    st_transform(3035) |>
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

readr::write_csv(traffic_density, output_file)

message("Wrote Shiny preprocessing output to: ", output_file)
message("Rows: ", nrow(traffic_density), "; rivers: ", dplyr::n_distinct(traffic_density$river_name))
