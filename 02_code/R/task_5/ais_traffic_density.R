# THAS Task 5: AIS Traffic Density

required_packages <- c(
  "tidyverse", "httr", "jsonlite", "glue", "sf",
  "rnaturalearth", "rnaturalearthdata", "h3jsr", "janitor", "scales"
)

purrr::walk(required_packages, function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("Please install missing package: ", pkg, call. = FALSE)
  }
})

suppressPackageStartupMessages({
  library(tidyverse)
  library(sf)
  library(glue)
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

data_dir <- file.path(root_dir, "01_data", "task_5")
report_dir <- file.path(root_dir, "03_report", "task_5")
graph_dir <- file.path(root_dir, "03_report", "graphs")

dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(graph_dir, recursive = TRUE, showWarnings = FALSE)

helper_file <- file.path(root_dir, "02_code", "R", "functions", "task5_helpers.R")

if (!file.exists(helper_file)) {
  stop("Could not find task5_helpers.R at 02_code/R/functions/task5_helpers.R", call. = FALSE)
}

source(helper_file)

set.seed(1103276)
sf::sf_use_s2(FALSE)

# -------------------------------------------------------------------------
# Settings
# -------------------------------------------------------------------------

base_url <- "https://aidaho-edu.uni-hohenheim.de/aisdb/"
h3_resolution <- 7
river_buffer_m <- 1500
analysis_date <- as.Date("2022-04-23")

german_rivers_rds_rel <- "01_data/task_5/task5_german_rivers.rds"
ais_germany_day_csv_rel <- "01_data/task_5/ais_germany_2022_04_23.csv"
river_h3_cells_csv_rel <- "01_data/task_5/task5_river_h3_cells.csv"
ais_classified_csv_rel <- "01_data/task_5/task5_ais_germany_2022_04_23_classified.csv"

river_share_csv_rel <- "01_data/task_5/task5_river_share.csv"
river_summary_csv_rel <- "01_data/task_5/task5_river_summary.csv"
rhine_density_csv_rel <- "01_data/task_5/task5_rhine_density.csv"

ai_summary_rel <- "03_report/task_5/task5_ai_summary.json"
human_summary_rel <- "03_report/task_5/task5_human_summary.md"

river_map_png_rel <- "03_report/graphs/task5_1b_german_rivers.png"
ship_type_plot_png_rel <- "03_report/graphs/task5_2e_ship_type_distribution.png"
rhine_density_png_rel <- "03_report/graphs/task5_2g_rhine_density.png"

# -------------------------------------------------------------------------
# 1. River geometries for Germany
# -------------------------------------------------------------------------

major_river_pattern <- regex(
  paste(
    c(
      "Rhine", "Rhein", "Elbe", "Danube", "Donau", "Weser", "Ems", "Oder",
      "Main", "Moselle", "Mosel", "Neckar", "Saale", "Spree", "Havel",
      "Isar", "Lech", "Inn", "Meuse"
    ),
    collapse = "|"
  ),
  ignore_case = TRUE
)

# Germany boundary for exact clipping.
# This object is used for the actual AIS matching data.
# Rivers outside Germany are removed, but border rivers remain on the border.
germany_sf <- rnaturalearth::ne_countries(
  scale = "medium",
  country = "Germany",
  returnclass = "sf"
) |>
  st_transform(4326) |>
  st_make_valid()

germany_boundary <- germany_sf |>
  st_union() |>
  st_make_valid()

german_rivers <- get_german_rivers(major_river_pattern) |>
  st_transform(4326) |>
  st_make_valid() |>
  mutate(
    river_name = case_when(
      river_name %in% c("Rhine", "Rhein") ~ "Rhine",
      river_name %in% c("Danube", "Donau") ~ "Danube",
      river_name %in% c("Mosel", "Moselle") ~ "Moselle",
      TRUE ~ river_name
    )
  ) |>
  filter(st_intersects(geometry, germany_boundary, sparse = FALSE)[, 1]) |>
  st_intersection(germany_boundary) |>
  st_collection_extract("LINESTRING") |>
  filter(!st_is_empty(geometry)) |>
  group_by(river_name) |>
  summarise(geometry = st_union(geometry), .groups = "drop") |>
  st_collection_extract("LINESTRING") |>
  filter(!st_is_empty(geometry))

readr::write_rds(
  german_rivers,
  file.path(root_dir, german_rivers_rds_rel)
)

major_legend_levels <- c(
  "Danube", "Elbe", "Ems", "Inn",
  "Main", "Meuse", "Moselle", "Oder",
  "Rhine", "Weser"
)

major_river_colors <- c(
  "Danube" = "#F8766D",
  "Elbe" = "#D89000",
  "Ems" = "#A3A500",
  "Inn" = "#39B600",
  "Main" = "#00BF7D",
  "Meuse" = "#00BFC4",
  "Moselle" = "#00B0F6",
  "Oder" = "#9590FF",
  "Rhine" = "#E76BF3",
  "Weser" = "#FF62BC"
)

# Plot rivers:
# Use the exactly clipped German river geometries for the map.
# This avoids foreign river snippets outside Germany.
german_rivers_plot <- german_rivers |>
  mutate(
    river_name_plot = if_else(
      river_name %in% major_legend_levels,
      river_name,
      NA_character_
    )
  )

# Visual supplement for the Rhine border section:
# Natural Earth places the Rhine centre line partly just outside the German polygon.
# Therefore, exact polygon clipping can remove parts of the western border Rhine.
# To keep the map visually close to common German river maps, we add only the
# German country border segments close to the raw Rhine geometry. This makes the
# Rhine visible on the border without showing foreign river snippets.
rhine_reference <- get_german_rivers(major_river_pattern) |>
  st_transform(4326) |>
  st_make_valid() |>
  mutate(
    river_name = case_when(
      river_name %in% c("Rhine", "Rhein") ~ "Rhine",
      river_name %in% c("Danube", "Donau") ~ "Danube",
      river_name %in% c("Mosel", "Moselle") ~ "Moselle",
      TRUE ~ river_name
    )
  ) |>
  filter(river_name == "Rhine") |>
  st_transform(3035) |>
  st_union() |>
  st_buffer(12000) |>
  st_transform(4326) |>
  st_make_valid()

germany_border_line <- st_sf(
  geometry = st_boundary(germany_boundary)
) |>
  st_set_crs(4326)

rhine_border_supplement <- suppressWarnings(
  st_intersection(germany_border_line, rhine_reference)
) |>
  st_collection_extract("LINESTRING") |>
  filter(!st_is_empty(geometry)) |>
  mutate(
    river_name = "Rhine",
    river_name_plot = "Rhine"
  )

german_rivers_plot <- bind_rows(
  german_rivers_plot,
  rhine_border_supplement
)

river_map <- ggplot() +
  geom_sf(
    data = germany_sf,
    fill = "grey95",
    color = "grey70",
    linewidth = 0.4
  ) +
  geom_sf(
    data = german_rivers_plot,
    aes(color = factor(river_name_plot, levels = major_legend_levels)),
    linewidth = 1,
    show.legend = TRUE,
    key_glyph = draw_key_path
  ) +
  scale_color_manual(
    values = major_river_colors,
    breaks = major_legend_levels,
    drop = FALSE,
    na.value = "grey80",
    na.translate = FALSE
  ) +
  coord_sf(
    xlim = c(5.5, 15.5),
    ylim = c(47, 55.2),
    expand = FALSE
  ) +
  labs(
    title = "German river geometries used for AIS matching",
    subtitle = "All retrieved rivers are plotted; the legend is restricted to major rivers for readability.",
    color = "Major river",
    x = NULL,
    y = NULL,
    caption = "Source: rnaturalearth / Natural Earth rivers_lake_centerlines."
  ) +
  theme_minimal(base_size = 13) +
  theme(
    legend.position = "right",
    panel.grid.minor = element_blank()
  )

ggsave(
  file.path(root_dir, river_map_png_rel),
  river_map,
  width = 10,
  height = 8,
  dpi = 300
)

# -------------------------------------------------------------------------
# 2. Download ais_germany data for one day
# -------------------------------------------------------------------------

ais_germany_day <- download_ais_germany_day(
  base_url = base_url,
  analysis_date = analysis_date,
  page_size = 50000
) |>
  add_static_ship_type_if_needed(base_url = base_url) |>
  normalise_collection_type()

readr::write_csv(
  ais_germany_day,
  file.path(root_dir, ais_germany_day_csv_rel)
)

# -------------------------------------------------------------------------
# 3. H3 indices for AIS points and rivers
# -------------------------------------------------------------------------

ais_sf <- ais_germany_day |>
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE)

ais_sf <- ais_sf |>
  mutate(h3_index = point_h3_index(ais_sf, resolution = h3_resolution))

river_cells <- river_h3_cells(
  rivers_sf = german_rivers,
  resolution = h3_resolution,
  buffer_m = river_buffer_m
)

readr::write_csv(
  river_cells,
  file.path(root_dir, river_h3_cells_csv_rel)
)

candidate_matches <- ais_sf |>
  inner_join(river_cells, by = "h3_index", relationship = "many-to-many")

river_assignment <- assign_nearest_river(
  ais_sf = ais_sf,
  candidate_matches = candidate_matches,
  rivers_sf = german_rivers
)

ais_classified <- ais_sf |>
  left_join(river_assignment, by = "row_id") |>
  mutate(
    on_river = replace_na(on_river, FALSE),
    river_name = if_else(on_river, river_name, NA_character_),
    location_group = if_else(on_river, "On selected German river", "Elsewhere")
  )

readr::write_csv(
  ais_classified |> st_drop_geometry(),
  file.path(root_dir, ais_classified_csv_rel)
)

# -------------------------------------------------------------------------
# 4. Percentage on rivers vs elsewhere
# -------------------------------------------------------------------------

river_share <- ais_classified |>
  st_drop_geometry() |>
  count(location_group, name = "n_records") |>
  mutate(percentage = n_records / sum(n_records) * 100) |>
  arrange(desc(n_records))

readr::write_csv(
  river_share,
  file.path(root_dir, river_share_csv_rel)
)

# -------------------------------------------------------------------------
# 5. Ship-type distribution: river vs elsewhere
# -------------------------------------------------------------------------

ship_type_distribution <- ais_classified |>
  st_drop_geometry() |>
  mutate(ship_type = fct_lump_n(ship_type, n = 10, other_level = "Other ship types")) |>
  count(location_group, ship_type, name = "n_records") |>
  group_by(location_group) |>
  mutate(share = n_records / sum(n_records)) |>
  ungroup()

ship_type_plot <- ggplot(
  ship_type_distribution,
  aes(x = fct_reorder(ship_type, share), y = share, fill = location_group)
) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  coord_flip() +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(
    title = "Ship-type distribution: selected rivers vs elsewhere",
    subtitle = "AIS Germany records on 2022-04-23",
    x = "Ship type",
    y = "Share within location group",
    fill = "Location group"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")

ggsave(
  file.path(root_dir, ship_type_plot_png_rel),
  ship_type_plot,
  width = 9,
  height = 6,
  dpi = 300
)

# -------------------------------------------------------------------------
# 6. Summary table by river
# -------------------------------------------------------------------------

river_summary <- ais_classified |>
  st_drop_geometry() |>
  filter(on_river) |>
  count(river_name, name = "n_records") |>
  arrange(desc(n_records))

readr::write_csv(
  river_summary,
  file.path(root_dir, river_summary_csv_rel)
)

# -------------------------------------------------------------------------
# 7. Rhine traffic-density plot
# -------------------------------------------------------------------------

rhine_geometry <- german_rivers |>
  filter(str_detect(river_name, regex("Rhine", ignore_case = TRUE))) |>
  summarise(geometry = st_union(geometry), .groups = "drop") |>
  st_transform(3035) |>
  st_line_merge() |>
  get_main_line()

if (nrow(rhine_geometry) == 0) {
  warning("No Rhine geometry found in Natural Earth data. Rhine density plot cannot be created.")
  rhine_density <- tibble()
} else {
  rhine_line <- rhine_geometry$geometry[[1]]
  
  rhine_points <- ais_classified |>
    filter(on_river, str_detect(river_name, regex("Rhine", ignore_case = TRUE))) |>
    st_transform(3035)
  
  distance_values_km <- suppressWarnings(
    distance_along_line_km(rhine_points, rhine_line)
  )
  
  if (length(distance_values_km) != nrow(rhine_points)) {
    stop(
      "Rhine distance calculation returned ",
      length(distance_values_km),
      " values for ",
      nrow(rhine_points),
      " Rhine points. Please check distance_along_line_km()."
    )
  }
  
  rhine_points <- rhine_points |>
    mutate(
      distance_km = distance_values_km,
      distance_bin_km = floor(distance_km / 10) * 10
    )
  
  rhine_density <- rhine_points |>
    st_drop_geometry() |>
    count(distance_bin_km, name = "n_records") |>
    mutate(
      bin_width_km = 10,
      density_records_per_10km = n_records / bin_width_km * 10
    ) |>
    arrange(distance_bin_km)
  
  readr::write_csv(
    rhine_density,
    file.path(root_dir, rhine_density_csv_rel)
  )
  
  rhine_density_plot <- ggplot(
    rhine_density,
    aes(x = distance_bin_km, y = density_records_per_10km)
  ) +
    geom_col(width = 9) +
    labs(
      title = "AIS traffic density along the Rhine",
      subtitle = "AIS records associated with the Rhine on 2022-04-23, aggregated into 10 km bins",
      x = "Approximate distance along Natural Earth Rhine geometry (km)",
      y = "AIS records per 10 km bin"
    ) +
    theme_minimal(base_size = 11)
  
  ggsave(
    file.path(root_dir, rhine_density_png_rel),
    rhine_density_plot,
    width = 9,
    height = 5,
    dpi = 300
  )
}

# -------------------------------------------------------------------------
# 8. Report-ready summaries
# -------------------------------------------------------------------------

task5_summary <- list(
  metadata = list(
    created_at = as.character(Sys.time()),
    api_base_url = base_url,
    root_dir = root_dir,
    data_dir = data_dir,
    report_dir = report_dir,
    graph_dir = graph_dir,
    analysis_date = as.character(analysis_date),
    h3_resolution = h3_resolution,
    river_buffer_m = river_buffer_m
  ),
  
  implementation_decisions = list(
    dynamic_table_strategy =
      "The ais_germany table is queried only for the required analysis date 2022-04-23. No unfiltered full-table download is performed.",
    river_selection =
      "Major German inland-waterway rivers are selected from Natural Earth by name pattern. Synonyms such as Rhine/Rhein, Danube/Donau and Mosel/Moselle are standardised and dissolved by river name to avoid duplicated geometries. River geometries used for matching are clipped exactly to Germany. For the map only, German border segments close to the raw Rhine geometry are added as a visual supplement so the Rhine remains visible on the border without showing foreign river snippets.",
    h3_matching =
      "H3 resolution 7 is used because it is required by the assignment and gives a practical compromise between spatial detail and computational cost.",
    river_buffer =
      "A 1500 m buffer is used because Natural Earth represents rivers as generalized centre lines, while AIS positions may deviate from the exact line because of river width, GPS noise, and geometry simplification.",
    tie_break_rule =
      "If an AIS point matches more than one river H3 cell, the nearest original river geometry is used.",
    rhine_density =
      "The Rhine density plot uses 10 km bins along the Natural Earth Rhine geometry. The x-axis should be interpreted as relative distance along the stored geometry. The final distance bin may be elevated because points near the end of the stored line accumulate in the last segment."
  ),
  
  outputs = list(
    german_rivers_rds = german_rivers_rds_rel,
    ais_germany_day_csv = ais_germany_day_csv_rel,
    river_h3_cells_csv = river_h3_cells_csv_rel,
    ais_classified_csv = ais_classified_csv_rel,
    river_share_csv = river_share_csv_rel,
    river_summary_csv = river_summary_csv_rel,
    rhine_density_csv = rhine_density_csv_rel,
    figures = c(
      river_map_png_rel,
      ship_type_plot_png_rel,
      rhine_density_png_rel
    ),
    ai_summary = ai_summary_rel,
    human_summary = human_summary_rel
  ),
  
  n_ais_records = nrow(ais_germany_day),
  n_rivers_used = nrow(german_rivers),
  major_rivers_used = sort(unique(river_summary$river_name)),
  river_share = river_share,
  river_summary = river_summary,
  ship_type_distribution = ship_type_distribution,
  rhine_density = rhine_density
)

jsonlite::write_json(
  task5_summary,
  path = file.path(root_dir, ai_summary_rel),
  pretty = TRUE,
  auto_unbox = TRUE,
  na = "null"
)

summary_lines <- c(
  "# Task 5 AIS Traffic Density Summary",
  "",
  glue("- Created at: {Sys.time()}"),
  glue("- Analysis date: {analysis_date}"),
  glue("- AIS records downloaded from ais_germany: {nrow(ais_germany_day)}"),
  glue("- H3 resolution: {h3_resolution}"),
  glue("- River buffer distance: {river_buffer_m} m"),
  "",
  "## Implementation notes",
  "",
  "- The `ais_germany` table was queried only for the required date, 2022-04-23.",
  "- Major German inland-waterway rivers were selected from Natural Earth. Duplicate names and synonyms were standardised, for example `Rhine`/`Rhein`, `Danube`/`Donau`, and `Mosel`/`Moselle`.",
  "- River geometries used for matching were clipped exactly to the German country polygon. This removes river parts outside Germany while keeping border rivers on the border.",
  "- For the exported map only, German border segments close to the raw Rhine geometry were added as a visual supplement. This makes the Rhine easier to see on the border without plotting foreign river snippets.",
  "- H3 converts point-in-river matching into a key-based join: AIS points and buffered river geometries receive comparable cell IDs.",
  "- H3 resolution 7 is used because it is required by the assignment and is a compromise between spatial detail and computational cost.",
  "- The 1500 m buffer is intentionally wider than the river centreline because Natural Earth provides generalized line geometries, not navigable river polygons.",
  "- If an AIS point matched more than one river, the nearest original river geometry was selected.",
  "- Points classified as elsewhere can include coastal/open-water AIS records, records near non-selected small rivers, and points outside the chosen buffer.",
  "- The Rhine distance plot uses the orientation of the Natural Earth Rhine line; therefore the x-axis should be interpreted as relative distance along that stored geometry.",
  "- The final Rhine distance bin may be elevated because points near the end of the stored Natural Earth Rhine geometry accumulate in the final segment.",
  "",
  "## Percentage on selected German rivers vs elsewhere",
  "",
  paste(capture.output(print(river_share, n = Inf)), collapse = "\n"),
  "",
  "## Records by river",
  "",
  paste(capture.output(print(river_summary, n = Inf)), collapse = "\n"),
  "",
  "## Output files",
  "",
  paste0("- `", german_rivers_rds_rel, "`"),
  paste0("- `", ais_germany_day_csv_rel, "`"),
  paste0("- `", river_h3_cells_csv_rel, "`"),
  paste0("- `", ais_classified_csv_rel, "`"),
  paste0("- `", river_share_csv_rel, "`"),
  paste0("- `", river_summary_csv_rel, "`"),
  paste0("- `", rhine_density_csv_rel, "`"),
  paste0("- `", river_map_png_rel, "`"),
  paste0("- `", ship_type_plot_png_rel, "`"),
  paste0("- `", rhine_density_png_rel, "`"),
  paste0("- `", ai_summary_rel, "`"),
  paste0("- `", human_summary_rel, "`")
)

write_markdown_summary(
  file.path(root_dir, human_summary_rel),
  summary_lines
)

message("Task 5 completed.")
message("Created data outputs in: ", data_dir)
message("Created report outputs in: ", report_dir)
message("Created graphs in: ", graph_dir)