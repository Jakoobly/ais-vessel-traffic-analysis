# ais_dynamic_sample_points.R
# Task 3.2 and 3.3: AIS dynamic sampling for THAS 2026
#
# Outputs:
# - 01_data/sample_intervals.csv
# - 01_data/sample_stratified.csv
# - 03_report/graphs/task3_ship_type_comparison.png
# - 03_report/graphs/task3_speed_comparison.png
# - 03_report/graphs/task3_collection_type_comparison.png
# - 03_report/task3_sampling_human.md
# - 03_report/task3_sampling_ai.json

library(tidyverse)
library(httr2)
library(jsonlite)
library(lubridate)

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

dir.create("01_data", recursive = TRUE, showWarnings = FALSE)
dir.create("03_report", recursive = TRUE, showWarnings = FALSE)
dir.create("03_report/graphs", recursive = TRUE, showWarnings = FALSE)

# -------------------------------------------------------------------------
# API helpers
# -------------------------------------------------------------------------

api_get <- function(path, query = list(), timeout_seconds = 120) {
  request(file.path(base_url, path)) |>
    req_url_query(!!!query) |>
    req_headers(Accept = "application/json") |>
    req_timeout(timeout_seconds) |>
    req_perform() |>
    resp_body_json(simplifyVector = TRUE) |>
    as_tibble()
}

safe_api_get <- function(path, query = list(), timeout_seconds = 120) {
  tryCatch(
    api_get(path, query, timeout_seconds),
    error = function(e) {
      message("API request failed: ", conditionMessage(e))
      tibble()
    }
  )
}

# Query one dynamic time interval with a strict limit.
query_dynamic_interval <- function(start_time, end_time, limit = 100) {
  safe_api_get(
    "ais_dynamic",
    list(
      select = "mmsi,msg_timestamp,latitude,longitude,speed,course,heading,collection_type",
      msg_timestamp = paste0("gte.", format(start_time, "%Y-%m-%dT%H:%M:%SZ")),
      msg_timestamp = paste0("lt.",  format(end_time,   "%Y-%m-%dT%H:%M:%SZ")),
      limit = limit
    )
  )
}

# IMPORTANT:
# httr2/R lists cannot contain the same name twice. Therefore, for queries
# requiring both gte and lt on msg_timestamp, we build the URL manually.
query_dynamic_interval_raw <- function(start_time, end_time, limit = 100, extra_query = NULL) {
  start_chr <- format(start_time, "%Y-%m-%dT%H:%M:%SZ")
  end_chr <- format(end_time, "%Y-%m-%dT%H:%M:%SZ")

  query_string <- paste0(
    "select=mmsi,msg_timestamp,latitude,longitude,speed,course,heading,collection_type",
    "&msg_timestamp=gte.", URLencode(start_chr, reserved = TRUE),
    "&msg_timestamp=lt.", URLencode(end_chr, reserved = TRUE),
    "&limit=", limit
  )

  if (!is.null(extra_query) && nzchar(extra_query)) {
    query_string <- paste(query_string, extra_query, sep = "&")
  }

  safe_api_get_raw("ais_dynamic", query_string)
}

safe_api_get_raw <- function(path, query_string, timeout_seconds = 120) {
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

# -------------------------------------------------------------------------
# Static vessel metadata
# -------------------------------------------------------------------------
# ais_static is small compared with ais_dynamic and contains one row per MMSI.
# We load it once to attach ship_type to dynamic records and to create strata.

ais_static <- safe_api_get(
  "ais_static",
  list(select = "mmsi,ship_type,flag,name,length,width")
) |>
  mutate(ship_type = replace_na(ship_type, "Unknown"))

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
# Task 3.2a/b: Retrieve at most 100 observations from each selected interval
# -------------------------------------------------------------------------

message("Starting interval sample...")

interval_sample <- pmap_dfr(
  list(selected_intervals$interval_start, selected_intervals$interval_end),
  function(start_time, end_time) {
    message("Query interval: ", format(start_time, "%Y-%m-%d %H:%M:%S UTC"))

    query_dynamic_interval_raw(start_time, end_time, records_per_interval) |>
      mutate(
        sample_method = "interval_cluster",
        sample_interval_start = start_time,
        sample_interval_end = end_time
      )
  }
) |>
  slice_head(n = target_n) |>
  left_join(ais_static |> select(mmsi, ship_type), by = "mmsi")

write_csv(interval_sample, "01_data/sample_intervals.csv")

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
# Task 3.3a: Build strata counts by ship_type and hour of day
# -------------------------------------------------------------------------
# We avoid downloading a large day-long dynamic dataset. Instead, each hour is
# queried with a limit high enough for practical sampling. Then ship_type is joined
# from ais_static and counts are calculated locally.
#
# This is an approximation: if the API/database does not allow reproducible random
# ordering directly, the returned rows are treated as an API-limited approximation.

query_hour_dynamic <- function(day, hour, limit = 50000) {
  start_time <- ymd_hms(sprintf("%s %02d:00:00", day, hour), tz = "UTC")
  end_time <- start_time + hours(1)

  message("Query hour for strata: ", format(start_time, "%Y-%m-%d %H:%M:%S UTC"))

  query_dynamic_interval_raw(start_time, end_time, limit = limit) |>
    mutate(hour = hour(msg_timestamp))
}

message("Starting hourly queries for strata...")

day_dynamic_for_strata <- map_dfr(0:23, ~ query_hour_dynamic(sampling_day, .x, limit = 50000)) |>
  mutate(
    msg_timestamp = ymd_hms(msg_timestamp, tz = "UTC"),
    hour = hour(msg_timestamp)
  ) |>
  left_join(ais_static |> select(mmsi, ship_type), by = "mmsi") |>
  mutate(ship_type = replace_na(ship_type, "Unknown"))

strata_counts <- day_dynamic_for_strata |>
  count(ship_type, hour, name = "stratum_n") |>
  arrange(hour, desc(stratum_n))

# -------------------------------------------------------------------------
# Task 3.3b: Proportional allocation to total sample size 10,000
# -------------------------------------------------------------------------

allocate_stratified_sample <- function(strata_table, total_n = 10000) {
  allocated <- strata_table |>
    mutate(
      proportion = stratum_n / sum(stratum_n),
      raw_allocation = proportion * total_n,
      # Very small strata get at least 1 observation if they exist.
      n_alloc = pmax(1L, floor(raw_allocation))
    )

  # Adjust to exactly total_n by distributing remaining observations to
  # strata with the largest fractional remainders.
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
# We already queried hourly API extracts in Task 3.3a.
# Now we draw a reproducible local sample within each stratum.
# This avoids re-running the expensive API requests.

message("Drawing stratified sample locally from existing hourly API extracts...")

set.seed(seed_value)

# Safety checks: stop early with helpful messages
stopifnot(exists("day_dynamic_for_strata"))
stopifnot(exists("strata_allocation"))

if (!"n_alloc" %in% names(strata_allocation)) {
  stop("Column `n_alloc` is missing in `strata_allocation`. Please run Task 3.3b only.")
}

if (!all(c("ship_type", "hour") %in% names(day_dynamic_for_strata))) {
  stop("`day_dynamic_for_strata` must contain `ship_type` and `hour`.")
}

stratified_sample <- day_dynamic_for_strata |>
  mutate(
    msg_timestamp = as_datetime(msg_timestamp, tz = "UTC"),
    ship_type = replace_na(ship_type, "Unknown")
  ) |>
  inner_join(
    strata_allocation |> 
      select(ship_type, hour, n_alloc),
    by = c("ship_type", "hour")
  ) |>
  group_by(ship_type, hour) |>
  group_modify(\(.x, .y) {
    n_take <- min(unique(.x$n_alloc)[1], nrow(.x))
    slice_sample(.x, n = n_take, replace = FALSE)
  }) |>
  ungroup() |>
  mutate(
    sample_method = "stratified_ship_type_hour",
    collection_type = replace_na(collection_type, "Unknown")
  ) |>
  slice_head(n = target_n)

write_csv(stratified_sample, "01_data/sample_stratified.csv")

message("Created: 01_data/sample_stratified.csv")
message("Rows in stratified sample: ", nrow(stratified_sample))

# Make interval sample compatible for later bind_rows() in Task 3.3e
interval_sample <- interval_sample |>
  mutate(
    msg_timestamp = as_datetime(msg_timestamp, tz = "UTC"),
    ship_type = replace_na(ship_type, "Unknown"),
    collection_type = replace_na(collection_type, "Unknown")
  )

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
  "03_report/graphs/task3_ship_type_comparison.png",
  ship_type_plot,
  width = 9,
  height = 6,
  dpi = 300
)

speed_plot <- plot_data |>
  filter(!is.na(speed), speed >= 0, speed <= 40) |>
  ggplot(aes(x = speed, fill = sample)) +
  geom_histogram(position = "identity", alpha = 0.45, bins = 40) +
  labs(
    title = "Speed distribution by sample",
    x = "Speed over ground in knots",
    y = "Number of observations",
    fill = "Sample"
  ) +
  theme_minimal()

ggsave(
  "03_report/graphs/task3_speed_comparison.png",
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
  "03_report/graphs/task3_collection_type_comparison.png",
  collection_type_plot,
  width = 8,
  height = 5,
  dpi = 300
)

# -------------------------------------------------------------------------
# Task 3.3f: Text comparison and machine-readable output
# -------------------------------------------------------------------------

comparison_summary <- list(
  metadata = list(
    created_at = as.character(Sys.time()),
    base_url = base_url,
    sampling_day = as.character(sampling_day),
    seed = seed_value
  ),
  interval_sample = list(
    n_rows = nrow(interval_sample),
    n_intervals_selected = nrow(selected_intervals),
    max_records_per_interval = records_per_interval,
    output = "01_data/sample_intervals.csv"
  ),
  stratified_sample = list(
    n_rows = nrow(stratified_sample),
    n_strata = nrow(strata_allocation),
    stratification_variables = c("ship_type", "hour"),
    allocation_rule = "Proportional allocation with at least 1 observation for non-empty strata; remaining observations distributed by largest fractional remainder.",
    random_retrieval_note = "True reproducible random retrieval from the API was not assumed. Hourly API extracts were sampled locally with a fixed seed.",
    output = "01_data/sample_stratified.csv"
  ),
  cluster_sampling_discussion = cluster_sampling_discussion,
  plots = list(
    ship_type = "03_report/graphs/task3_ship_type_comparison.png",
    speed = "03_report/graphs/task3_speed_comparison.png",
    collection_type = "03_report/graphs/task3_collection_type_comparison.png"
  )
)

write_json(
  comparison_summary,
  "03_report/task3_sampling_ai.json",
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
    "The final sample contains ", nrow(interval_sample), " observations and was saved as `01_data/sample_intervals.csv`."
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
    "Stratum sizes were estimated from hourly API extracts for ", sampling_day, ". ",
    "The target sample size of 10,000 observations was allocated proportionally to the stratum sizes. ",
    "Very small non-empty strata received at least one observation. Remaining observations were assigned according to the largest fractional remainders."
  ),
  "",
  paste0("The final stratified sample contains ", nrow(stratified_sample), " observations and was saved as `01_data/sample_stratified.csv`."),
  "",
  "True reproducible random retrieval directly from the API was not assumed. Therefore, records were retrieved by hour and then sampled locally within each stratum using the fixed random seed. This is a transparent approximation.",
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

write_lines(human_md, "03_report/task3_sampling_human.md")

message("Done.")
message("Created: 01_data/sample_intervals.csv")
message("Created: 01_data/sample_stratified.csv")
message("Created: 03_report/task3_sampling_ai.json")
message("Created: 03_report/task3_sampling_human.md")
message("Created comparison plots in 03_report/graphs/")

# -------------------------------------------------------------------------
# Final cleanup for submission
# -------------------------------------------------------------------------

stratified_sample <- stratified_sample |>
  select(-n_alloc)

write_csv(
  stratified_sample,
  "01_data/sample_stratified.csv"
)

message("Cleaned final sample_stratified.csv (removed n_alloc)")
