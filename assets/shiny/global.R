library(shiny)
library(dplyr)
library(ggplot2)
library(scales)

DATA_FILE <- "data/task7_shiny_traffic_density.csv"

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
  ) |>
  filter(
    !is.na(river_name),
    !is.na(ship_type),
    !is.na(distance_bin_km),
    !is.na(density_records_per_10km),
    !is.na(n_records)
  )

available_rivers <- sort(unique(traffic_density_data$river_name))
available_ship_types <- sort(unique(traffic_density_data$ship_type))

default_ship_types <- available_ship_types[seq_len(min(5, length(available_ship_types)))]

total_records <- sum(traffic_density_data$n_records, na.rm = TRUE)
total_rivers <- length(available_rivers)
total_ship_types <- length(available_ship_types)

format_big_number <- function(x) {
  scales::comma(x, accuracy = 1)
}

filter_traffic <- function(data, river, ship_types) {
  data |>
    filter(river_name == river, ship_type %in% ship_types) |>
    group_by(river_name, distance_bin_km) |>
    summarise(
      n_records = sum(n_records, na.rm = TRUE),
      density_records_per_10km = sum(density_records_per_10km, na.rm = TRUE),
      .groups = "drop"
    ) |>
    arrange(distance_bin_km)
}

plot_traffic_density <- function(data, river, ship_types) {
  ggplot(data, aes(x = distance_bin_km, y = density_records_per_10km)) +
    geom_col(width = 8.5, fill = "#2f80ed", alpha = 0.92) +
    geom_smooth(
      aes(y = density_records_per_10km),
      method = "loess",
      formula = y ~ x,
      se = FALSE,
      linewidth = 0.9,
      color = "#12b886"
    ) +
    scale_y_continuous(labels = scales::comma) +
    labs(
      title = paste("AIS traffic density along", river),
      subtitle = paste0(
        "2022-04-23 · selected ship types: ",
        paste(ship_types, collapse = ", ")
      ),
      x = "Approximate distance along river geometry (km)",
      y = "AIS records per 10 km bin"
    ) +
    theme_minimal(base_size = 14) +
    theme(
      plot.title = element_text(face = "bold", size = 19, color = "#172033"),
      plot.subtitle = element_text(size = 11, color = "#5f6f89", margin = margin(b = 14)),
      axis.title = element_text(face = "bold", color = "#172033"),
      axis.text = element_text(color = "#5f6f89"),
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_line(color = "#e8eef7"),
      plot.background = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA)
    )
}
