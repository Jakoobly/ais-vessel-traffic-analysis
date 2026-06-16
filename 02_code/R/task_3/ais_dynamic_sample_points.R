# ais_dynamic_sample_points.R
# Task 3.2 and 3.3: AIS dynamic sampling for THAS 2026
#
# Outputs:
#   01_data/task_3/sample_intervals.csv
#   01_data/task_3/sample_stratified.csv
#   01_data/task_3/task3_sampling_intermediate_results.csv
#   03_report/task_3/graphs/task3_ship_type_comparison.png
#   03_report/task_3/graphs/task3_speed_comparison.png
#   03_report/task_3/graphs/task3_collection_type_comparison.png
#   03_report/task_3/task3_sampling_human.md
#   03_report/task_3/task3_sampling_ai.json

library(tidyverse)
library(httr2)
library(jsonlite)
library(lubridate)

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
data_dir <- file.path(root_dir, "01_data", "task_3")
report_dir <- file.path(root_dir, "03_report", "task_3")
graph_dir <- file.path(root_dir, "03_report", "graphs")

dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(graph_dir, recursive = TRUE, showWarnings = FALSE)

# -------------------------------------------------------------------------
# Settings
# -------------------------------------------------------------------------

base_url <- "https://aidaho-edu.uni-hohenheim.de/aisdb"
sampling_day <- as.Date("2024-01-24")
target_n <- 10000
interval_minutes <- 5
n_intervals <- 100
records_per_interval <- 100
seed_value <- 1103276

set.seed(seed_value)

# -------------------------------------------------------------------------
# API helpers
# -------------------------------------------------------------------------

safe_api_get_raw <- function(path, query_string, timeout_seconds = 180) {
  url <- paste0(base_url, "/", path, "?", query_string)
  
  tryCatch(
    request(url) |>
      req_headers(Accept = "application/json") |>
      req_timeout(timeout_seconds) |>
      req_perform() |>
      resp_body_json(simplifyVector = TRUE) |>
      as_tibble(),
    error = function(e) {
      message("API request failed: ", conditionMessage(e))
      tibble()
    }
  )
}

safe_api_get <- function(path, query = list(), timeout_seconds = 180) {
  tryCatch(
    request(file.path(base_url, path)) |>
      req_url_query(!!!query) |>
      req_headers(Accept = "application/json") |>
      req_timeout(timeout_seconds) |>
      req_perform() |>
      resp_body_json(simplifyVector = TRUE) |>
      as_tibble(),
    error = function(e) {
      message("API request failed: ", conditionMessage(e))
      tibble()
    }
  )
}

format_api_time <- function(x) {
  format(as_datetime(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ")
}

query_dynamic_interval_raw <- function(start_time, end_time, limit = 100, select_cols = NULL, extra_query = NULL) {
  if (is.null(select_cols)) {
    select_cols <- "mmsi,msg_timestamp,latitude,longitude,speed,course,heading,collection_type"
  }
  
  query_string <- paste0(
    "select=", select_cols,
    "&msg_timestamp=gte.", URLencode(format_api_time(start_time), reserved = TRUE),
    "&msg_timestamp=lt.", URLencode(format_api_time(end_time), reserved = TRUE),
    "&limit=", limit
  )
  
  if (!is.null(extra_query) && nzchar(extra_query)) {
    query_string <- paste(query_string, extra_query, sep = "&")
  }
  
  safe_api_get_raw("ais_dynamic", query_string)
}

# -------------------------------------------------------------------------
# Static vessel metadata
# -------------------------------------------------------------------------
# ais_static is comparatively small and contains one row per MMSI.
# It is loaded once to attach ship_type information to dynamic records.

message("Loading ais_static metadata...")

ais_static <- safe_api_get(
  "ais_static",
  list(select = "mmsi,ship_type,flag,name,length,width", limit = 1000000),
  timeout_seconds = 300
) |>
  mutate(ship_type = replace_na(ship_type, "Unknown")) |>
  distinct(mmsi, .keep_all = TRUE)

# -------------------------------------------------------------------------
# Task 3.2a: Generate all 5-minute intervals for 2024-01-24
# -------------------------------------------------------------------------

make_intervals <- function(day, minutes = 5) {
  start <- ymd_hms(paste(day, "00:00:00"), tz = "UTC")
  
  tibble(
    interval_start = seq(
      from = start,
      to = start + days(1) - minutes(minutes),
      by = paste(minutes, "mins")
    )
  ) |>
    mutate(interval_end = interval_start + minutes(minutes))
}

interval_frame <- make_intervals(sampling_day, interval_minutes)

selected_intervals <- interval_frame |>
  slice_sample(n = n_intervals)

# -------------------------------------------------------------------------
# Task 3.2a/b: Retrieve interval cluster sample
# -------------------------------------------------------------------------

message("Starting interval cluster sample...")

interval_sample <- pmap_dfr(
  list(selected_intervals$interval_start, selected_intervals$interval_end),
  function(start_time, end_time) {
    message("Query interval: ", format(start_time, "%Y-%m-%d %H:%M:%S UTC"))
    
    query_dynamic_interval_raw(
      start_time = start_time,
      end_time = end_time,
      limit = records_per_interval
    ) |>
      mutate(
        sample_method = "interval_cluster",
        sample_interval_start = start_time,
        sample_interval_end = end_time
      )
  }
) |>
  slice_head(n = target_n) |>
  left_join(ais_static |> select(mmsi, ship_type), by = "mmsi") |>
  mutate(
    msg_timestamp = as_datetime(msg_timestamp, tz = "UTC"),
    ship_type = replace_na(ship_type, "Unknown"),
    collection_type = replace_na(collection_type, "Unknown")
  )

write_csv(interval_sample, file.path(data_dir, "sample_intervals.csv"))

# -------------------------------------------------------------------------
# Task 3.2c: Bias discussion for report
# -------------------------------------------------------------------------

cluster_sampling_discussion <- list(
  strategy = paste(
    "The sampling frame consists of all 5-minute intervals on 2024-01-24.",
    "A random seed was set and 100 intervals were randomly selected.",
    "For each selected interval, at most 100 AIS observations were queried.",
    "The procedure stops at 10,000 observations."
  ),
  why_seed_matters = paste(
    "Setting a random seed makes the random selection of intervals reproducible.",
    "This allows the same sample to be regenerated for checking, grading, and debugging."
  ),
  possible_biases = c(
    "Temporal cluster bias: selected 5-minute intervals may overrepresent short periods with unusually high or low traffic.",
    "Regional receiver bias: AIS observations available in those intervals may overrepresent regions with better receiver coverage.",
    "Vessel activity bias: vessels that transmit more frequently during selected intervals are more likely to appear in the sample."
  ),
  alternative_strategy = paste(
    "A stratified sample by ship_type and hour of day can reduce temporal and vessel-type imbalance.",
    "This is implemented below by allocating the total sample size proportionally to strata counts."
  )
)

# -------------------------------------------------------------------------
# Task 3.3a: Server-side stratum counts by ship_type and hour
# -------------------------------------------------------------------------
# ais_dynamic does not contain ship_type directly. Therefore, each hour is first
# aggregated server-side by MMSI using PostgREST count(). The much smaller
# MMSI-hour result is joined locally with ais_static, and counts are then summed
# by ship_type and hour. This avoids downloading all dynamic records for the day.

query_hour_mmsi_counts <- function(day, hour_value) {
  start_time <- ymd_hms(sprintf("%s %02d:00:00", day, hour_value), tz = "UTC")
  end_time <- start_time + hours(1)
  
  message("Query server-side MMSI counts for hour: ", format(start_time, "%Y-%m-%d %H:%M:%S UTC"))
  
  query_dynamic_interval_raw(
    start_time = start_time,
    end_time = end_time,
    limit = 1000000,
    select_cols = "mmsi,n:count()"
  ) |>
    mutate(
      hour = hour_value,
      n = as.numeric(n)
    )
}

message("Starting server-side hourly aggregation for strata...")

hourly_mmsi_counts <- map_dfr(0:23, ~ query_hour_mmsi_counts(sampling_day, .x))

strata_counts <- hourly_mmsi_counts |>
  left_join(ais_static |> select(mmsi, ship_type), by = "mmsi") |>
  mutate(ship_type = replace_na(ship_type, "Unknown")) |>
  group_by(ship_type, hour) |>
  summarise(stratum_n = sum(n, na.rm = TRUE), .groups = "drop") |>
  arrange(hour, desc(stratum_n))

# -------------------------------------------------------------------------
# Task 3.3b: Proportional allocation to total sample size 10,000
# -------------------------------------------------------------------------

allocate_stratified_sample <- function(strata_table, total_n = 10000) {
  allocated <- strata_table |>
    mutate(
      proportion = stratum_n / sum(stratum_n),
      raw_allocation = proportion * total_n,
      n_alloc = pmax(1L, floor(raw_allocation))
    )
  
  difference <- total_n - sum(allocated$n_alloc)
  
  if (difference > 0) {
    allocated <- allocated |>
      mutate(remainder = raw_allocation - floor(raw_allocation)) |>
      arrange(desc(remainder)) |>
      mutate(n_alloc = n_alloc + if_else(row_number() <= difference, 1L, 0L)) |>
      arrange(hour, ship_type) |>
      select(-remainder)
  }
  
  if (difference < 0) {
    allocated <- allocated |>
      arrange(n_alloc, raw_allocation) |>
      mutate(
        removable = pmax(0L, n_alloc - 1L),
        remove_n = pmin(removable, abs(difference)),
        cum_remove = cumsum(remove_n),
        remove_final = pmax(0L, pmin(remove_n, abs(difference) - lag(cum_remove, default = 0L))),
        n_alloc = n_alloc - remove_final
      ) |>
      arrange(hour, ship_type) |>
      select(-removable, -remove_n, -cum_remove, -remove_final)
  }
  
  allocated
}

strata_allocation <- allocate_stratified_sample(strata_counts, target_n)

# -------------------------------------------------------------------------
# Task 3.3c/d: Draw stratified sample
# -------------------------------------------------------------------------
# True reproducible random retrieval directly from the API is not assumed.
# Therefore, hourly extracts are retrieved with a strict limit and the final
# random draw happens locally within ship_type-hour strata using the fixed seed.
# This keeps the procedure transparent and reproducible.

query_hour_dynamic_extract <- function(day, hour_value, limit = 60000) {
  start_time <- ymd_hms(sprintf("%s %02d:00:00", day, hour_value), tz = "UTC")
  end_time <- start_time + hours(1)
  
  message("Query hourly dynamic extract for sampling: ", format(start_time, "%Y-%m-%d %H:%M:%S UTC"))
  
  query_dynamic_interval_raw(
    start_time = start_time,
    end_time = end_time,
    limit = limit
  ) |>
    mutate(
      msg_timestamp = as_datetime(msg_timestamp, tz = "UTC"),
      hour = hour(msg_timestamp)
    )
}

message("Starting hourly extracts for stratified sampling...")

hourly_extracts <- map_dfr(0:23, ~ query_hour_dynamic_extract(sampling_day, .x, limit = 60000)) |>
  left_join(ais_static |> select(mmsi, ship_type), by = "mmsi") |>
  mutate(
    ship_type = replace_na(ship_type, "Unknown"),
    collection_type = replace_na(collection_type, "Unknown")
  )

message("Drawing local stratified sample from hourly extracts...")

set.seed(seed_value)

stratified_sample_initial <- hourly_extracts |>
  inner_join(
    strata_allocation |> select(ship_type, hour, n_alloc),
    by = c("ship_type", "hour")
  ) |>
  group_by(ship_type, hour) |>
  group_modify(\(.x, .y) {
    n_take <- min(unique(.x$n_alloc)[1], nrow(.x))
    slice_sample(.x, n = n_take, replace = FALSE)
  }) |>
  ungroup() |>
  mutate(sample_method = "stratified_ship_type_hour") |>
  select(-n_alloc)

# Fill up to target_n if some strata contain fewer available observations
# than allocated. This keeps the final sample size at 10,000 while still using
# the same filtered hourly extract and fixed random seed.
if (nrow(stratified_sample_initial) < target_n) {
  missing_n <- target_n - nrow(stratified_sample_initial)
  
  remaining_rows <- hourly_extracts |>
    anti_join(
      stratified_sample_initial |> select(mmsi, msg_timestamp),
      by = c("mmsi", "msg_timestamp")
    )
  
  additional_rows <- remaining_rows |>
    slice_sample(
      n = min(missing_n, nrow(remaining_rows)),
      replace = FALSE
    ) |>
    mutate(sample_method = "stratified_ship_type_hour_fillup")
  
  stratified_sample <- bind_rows(
    stratified_sample_initial,
    additional_rows
  )
} else {
  stratified_sample <- stratified_sample_initial
}

stratified_sample <- stratified_sample |>
  slice_head(n = target_n)

write_csv(stratified_sample, file.path(data_dir, "sample_stratified.csv"))

# -------------------------------------------------------------------------
# Task 3.3e: Comparison plots
# -------------------------------------------------------------------------

plot_data <- bind_rows(
  interval_sample |> mutate(sample = "Interval cluster sample"),
  stratified_sample |> mutate(sample = "Stratified sample")
) |>
  mutate(
    ship_type = replace_na(ship_type, "Unknown"),
    collection_type = replace_na(collection_type, "Unknown")
  )

ship_type_plot <- plot_data |>
  count(sample, ship_type) |>
  group_by(sample) |>
  mutate(share = n / sum(n)) |>
  ungroup() |>
  group_by(ship_type) |>
  mutate(total = sum(n)) |>
  ungroup() |>
  slice_max(total, n = 12) |>
  ggplot(aes(x = reorder(ship_type, share), y = share, fill = sample)) +
  geom_col(position = "dodge") +
  coord_flip() +
  labs(
    title = "Ship type distribution by sample",
    x = "Ship type",
    y = "Share of observations",
    fill = "Sample"
  ) +
  theme_minimal()

ggsave(
  file.path(graph_dir, "task3_ship_type_comparison.png"),
  ship_type_plot,
  width = 9,
  height = 6,
  dpi = 300
)

speed_plot <- plot_data |>
  filter(!is.na(speed), speed >= 0, speed <= 40) |>
  ggplot(aes(x = speed, color = sample, fill = sample)) +
  geom_density(alpha = 0.25, linewidth = 1, adjust = 1.2) +
  labs(
    title = "Speed distribution by sample",
    x = "Speed over ground in knots",
    y = "Density",
    color = "Sample",
    fill = "Sample"
  ) +
  theme_minimal()

ggsave(
  file.path(graph_dir, "task3_speed_comparison.png"),
  speed_plot,
  width = 9,
  height = 6,
  dpi = 300
)

collection_type_plot <- plot_data |>
  count(sample, collection_type) |>
  group_by(sample) |>
  mutate(share = n / sum(n)) |>
  ungroup() |>
  ggplot(aes(x = collection_type, y = share, fill = sample)) +
  geom_col(position = "dodge") +
  labs(
    title = "Collection type distribution by sample",
    x = "Collection type",
    y = "Share of observations",
    fill = "Sample"
  ) +
  theme_minimal()

ggsave(
  file.path(graph_dir, "task3_collection_type_comparison.png"),
  collection_type_plot,
  width = 8,
  height = 5,
  dpi = 300
)

# -------------------------------------------------------------------------
# Intermediate results
# -------------------------------------------------------------------------

to_long_table <- function(df, section) {
  df |>
    mutate(across(everything(), as.character)) |>
    pivot_longer(
      cols = everything(),
      names_to = "variable",
      values_to = "value"
    ) |>
    mutate(section = section, .before = 1)
}

intermediate_results <- bind_rows(
  to_long_table(selected_intervals, "selected_intervals"),
  to_long_table(strata_counts, "strata_counts"),
  to_long_table(strata_allocation, "strata_allocation"),
  tibble(
    section = "sample_sizes",
    variable = c("interval_sample_rows", "stratified_sample_rows"),
    value = c(as.character(nrow(interval_sample)), as.character(nrow(stratified_sample)))
  )
)

write_csv(
  intermediate_results,
  file.path(data_dir, "task3_sampling_intermediate_results.csv"),
  na = ""
)

# -------------------------------------------------------------------------
# Task 3.3f: Text comparison and machine-readable output
# -------------------------------------------------------------------------

comparison_summary <- list(
  metadata = list(
    created_at = as.character(Sys.time()),
    base_url = base_url,
    sampling_day = as.character(sampling_day),
    seed = seed_value,
    root_dir = root_dir,
    data_dir = data_dir,
    report_dir = report_dir,
    graph_dir = graph_dir
  ),
  implementation_decisions = list(
    interval_sampling = "All 5-minute intervals of the sampling day were generated. A fixed seed was used to randomly select 100 intervals. Up to 100 AIS records were retrieved per selected interval.",
    stratification = "The stratified sample uses ship_type and hour of day as strata.",
    server_side_aggregation = "Stratum counts were built using server-side PostgREST aggregation by MMSI within each hour. The resulting MMSI counts were joined with ais_static and summed by ship_type and hour.",
    dynamic_table_strategy = "The full ais_dynamic table was never downloaded. Dynamic queries were restricted by time interval and limit, or used grouped aggregate counts.",
    random_retrieval_note = "True reproducible random retrieval directly from the API was not assumed. Hourly extracts were sampled locally with a fixed seed as a transparent approximation.",
    allocation_rule = "The target sample size of 10,000 observations was allocated proportionally to stratum counts. Non-empty strata received at least one observation, and remaining observations were assigned by largest fractional remainder."
  ),
  interval_sample = list(
    n_rows = nrow(interval_sample),
    n_intervals_selected = nrow(selected_intervals),
    max_records_per_interval = records_per_interval,
    output = file.path(data_dir, "sample_intervals.csv")
  ),
  stratified_sample = list(
    n_rows = nrow(stratified_sample),
    n_strata = nrow(strata_allocation),
    stratification_variables = c("ship_type", "hour"),
    output = file.path(data_dir, "sample_stratified.csv")
  ),
  cluster_sampling_discussion = cluster_sampling_discussion,
  plots = list(
    ship_type = file.path(graph_dir, "task3_ship_type_comparison.png"),
    speed = file.path(graph_dir, "task3_speed_comparison.png"),
    collection_type = file.path(graph_dir, "task3_collection_type_comparison.png")
  )
)

write_json(
  comparison_summary,
  file.path(report_dir, "task3_sampling_ai.json"),
  pretty = TRUE,
  auto_unbox = TRUE
)

human_md <- c(
  "# Task 3 Sampling Summary",
  "",
  paste0("Created at: ", comparison_summary$metadata$created_at),
  paste0("Sampling day: ", sampling_day),
  paste0("Random seed: ", seed_value),
  "",
  "## Task 3.2 Interval cluster sample",
  "",
  paste0(
    "All possible 5-minute intervals for ", sampling_day,
    " were generated. A fixed seed was used and 100 intervals were randomly selected. ",
    "For each selected interval, at most 100 AIS observations were retrieved. ",
    "The final sample contains ", nrow(interval_sample), " observations and was saved as `01_data/task_3/sample_intervals.csv`."
  ),
  "",
  "The random seed is important because it makes the randomly selected intervals reproducible. This allows the sample to be regenerated for grading, debugging, and verification.",
  "",
  "Possible biases of this cluster sampling approach:",
  "",
  "- Temporal cluster bias: selected 5-minute intervals may overrepresent short periods with unusual traffic.",
  "- Regional receiver bias: areas with better AIS receiver coverage may be overrepresented.",
  "- Activity bias: vessels that transmit more frequently during the selected intervals have a higher chance of appearing.",
  "",
  "A possible alternative is stratified sampling by ship type and hour of day. This reduces imbalance across important temporal and vessel-type groups.",
  "",
  "## Task 3.3 Stratified sample",
  "",
  paste0(
    "The second sample uses strata defined by combinations of `ship_type` and hour of day. ",
    "Stratum sizes were estimated using server-side PostgREST aggregation by MMSI within each hour and then joined with `ais_static` to assign ship types. ",
    "The target sample size of 10,000 observations was allocated proportionally to the stratum sizes. ",
    "Very small non-empty strata received at least one observation. Remaining observations were assigned according to the largest fractional remainders."
  ),
  "",
  paste0("The final stratified sample contains ", nrow(stratified_sample), " observations and was saved as `01_data/task_3/sample_stratified.csv`."),
  "",
  "True reproducible random retrieval directly from the API was not assumed. Therefore, records were retrieved by hour and then sampled locally within each stratum using the fixed random seed. This is a transparent approximation and avoids unfiltered access to the large `ais_dynamic` table.",
  "",
  "## Comparison",
  "",
  "Three plots were created to compare the interval cluster sample and the stratified sample:",
  "",
  "- `03_report/graphs/task3_ship_type_comparison.png`",
  "- `03_report/graphs/task3_speed_comparison.png`",
  "- `03_report/graphs/task3_collection_type_comparison.png`",
  "",
  "The interval sample may show stronger short-term variation because all observations come from randomly selected 5-minute clusters. The stratified sample is expected to better preserve the distribution across ship types and hours of the day because it explicitly allocates observations according to these strata."
)

write_lines(human_md, file.path(report_dir, "task3_sampling_human.md"))

message("Done.")
message("Created: ", file.path(data_dir, "sample_intervals.csv"))
message("Created: ", file.path(data_dir, "sample_stratified.csv"))
message("Created: ", file.path(data_dir, "task3_sampling_intermediate_results.csv"))
message("Created: ", file.path(report_dir, "task3_sampling_ai.json"))
message("Created: ", file.path(report_dir, "task3_sampling_human.md"))
message("Created comparison plots in: ", graph_dir)