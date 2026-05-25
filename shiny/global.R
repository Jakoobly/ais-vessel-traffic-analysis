library(shiny)
library(dplyr)
library(ggplot2)

DATA_FILE <- "01_data/task7_shiny_traffic_density.csv"

if (!file.exists(DATA_FILE)) {
  stop(
    "Prepared Shiny data file not found: ", DATA_FILE,
    "\nRun 02_code/R/task7_prepare_shiny_data.R first and mount 01_data into the Shiny container.",
    call. = FALSE
  )
}

traffic_density_data <- read.csv(DATA_FILE, stringsAsFactors = FALSE)

traffic_density_data <- traffic_density_data |>
  mutate(
    river_name = as.character(river_name),
    ship_type = as.character(ship_type),
    distance_bin_km = as.numeric(distance_bin_km),
    density_records_per_10km = as.numeric(density_records_per_10km),
    n_records = as.integer(n_records)
  )

available_rivers <- sort(unique(traffic_density_data$river_name))
available_ship_types <- sort(unique(traffic_density_data$ship_type))

default_ship_types <- available_ship_types[seq_len(min(5, length(available_ship_types)))]

filter_traffic <- function(data, river, ship_types) {
  data |>
    filter(river_name == river, ship_type %in% ship_types) |>
    group_by(river_name, distance_bin_km) |>
    summarise(
      n_records = sum(n_records),
      density_records_per_10km = sum(density_records_per_10km),
      .groups = "drop"
    ) |>
    arrange(distance_bin_km)
}

plot_traffic_density <- function(data, river, ship_types) {
  ggplot(data, aes(x = distance_bin_km, y = density_records_per_10km)) +
    geom_col(width = 9) +
    labs(
      title = paste("AIS traffic density along", river),
      subtitle = paste0(
        "AIS records on 2022-04-23; selected ship types: ",
        paste(ship_types, collapse = ", ")
      ),
      x = "Approximate distance along Natural Earth river geometry (km)",
      y = "AIS records per 10 km bin"
    ) +
    theme_minimal(base_size = 13)
}
