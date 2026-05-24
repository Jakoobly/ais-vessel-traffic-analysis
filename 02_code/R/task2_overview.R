# Task 2 - AIS API overview without PostgREST group-by aggregation
# Output:
#   03_report/task2_overview_ai.json
#   03_report/task2_overview_human.md
#
# Why this version?
# Your PostgREST endpoint supports aggregates in principle, but rejects grouped
# aggregate queries such as select=ship_type,count(). Therefore this script only
# downloads ais_static, which is small enough and explicitly one row per vessel,
# and computes grouped summaries locally in R. For ais_dynamic it still uses
# strict time filters / HEAD counts, so we do not overload the database.

library(tidyverse)
library(httr2)
library(jsonlite)

base_url <- "https://aidaho-edu.uni-hohenheim.de/aisdb"
out_dir <- "03_report"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

api_get <- function(path, query = list(), simplifyVector = TRUE) {
  request(file.path(base_url, path)) |>
    req_url_query(!!!query) |>
    req_headers(Accept = "application/json") |>
    req_timeout(180) |>
    req_perform() |>
    resp_body_json(simplifyVector = simplifyVector)
}

api_get_raw <- function(path, query_string, simplifyVector = TRUE) {
  request(paste0(base_url, "/", path, "?", query_string)) |>
    req_headers(Accept = "application/json") |>
    req_timeout(180) |>
    req_perform() |>
    resp_body_json(simplifyVector = simplifyVector)
}

api_count <- function(table, query = list(), count_mode = "exact") {
  req <- request(file.path(base_url, table)) |>
    req_url_query(!!!c(query, list(select = "*", limit = 1))) |>
    req_headers(Accept = "application/json", Prefer = paste0("count=", count_mode)) |>
    req_method("HEAD") |>
    req_timeout(180) |>
    req_perform()

  suppressWarnings(as.numeric(str_extract(resp_header(req, "content-range"), "(?<=/)\\d+$")))
}

api_count_raw <- function(table, query_string, count_mode = "exact") {
  req <- request(paste0(base_url, "/", table, "?", query_string)) |>
    req_headers(Accept = "application/json", Prefer = paste0("count=", count_mode)) |>
    req_method("HEAD") |>
    req_timeout(180) |>
    req_perform()

  suppressWarnings(as.numeric(str_extract(resp_header(req, "content-range"), "(?<=/)\\d+$")))
}

safe_api_count <- function(table, query = list()) {
  mode <- if_else(table %in% c("ais_dynamic", "ais_germany"), "planned", "exact")
  tryCatch(api_count(table, query = query, count_mode = mode), error = function(e) NA_real_)
}

# 2.2 available resources ----------------------------------------------------
resources_raw <- request(base_url) |>
  req_headers(Accept = "application/openapi+json") |>
  req_timeout(60) |>
  req_perform() |>
  resp_body_json(simplifyVector = TRUE)

resources <- names(resources_raw$paths) |>
  str_remove("^/") |>
  discard(~ .x == "") |>
  sort()

main_tables <- intersect(c("ais_static", "ais_dynamic", "ais_germany"), resources)

# Download only ais_static ----------------------------------------------------
# ais_static has one row per vessel/MMSI according to the assignment sheet.
# This is safe compared with ais_dynamic, which is huge.
ais_static <- api_get("ais_static", list(limit = 1000000)) |>
  as_tibble()

# 2.3b row counts and distinct vessels ---------------------------------------
row_counts <- tibble(table = main_tables) |>
  mutate(
    count_method = if_else(table %in% c("ais_dynamic", "ais_germany"), "planned / approximate HEAD count", "local exact count / HEAD count"),
    n_rows = case_when(
      table == "ais_static" ~ as.numeric(nrow(ais_static)),
      TRUE ~ map_dbl(table, safe_api_count)
    )
  )

distinct_vessels <- tibble(
  source = "ais_static",
  logic = "ais_static contains one row per MMSI; therefore distinct vessels are counted from non-missing mmsi values in ais_static",
  distinct_mmsi = n_distinct(na.omit(ais_static$mmsi))
)

# 2.3c + 2.3d grouped summaries locally --------------------------------------
ship_types <- ais_static |>
  count(ship_type, sort = TRUE, name = "n") |>
  slice_head(n = 30)

flags <- ais_static |>
  count(flag, sort = TRUE, name = "n") |>
  slice_head(n = 30)

n_flags <- ais_static |>
  filter(!is.na(flag), flag != "") |>
  summarise(n = n_distinct(flag)) |>
  pull(n)

most_common_flag <- flags |> slice(1)

# 2.3e ais_static overview ----------------------------------------------------
column_overview <- tibble(
  column = names(ais_static),
  guessed_r_type = map_chr(ais_static, ~ class(.x)[1]),
  n_non_missing = map_int(ais_static, ~ sum(!is.na(.x))),
  example_values = map_chr(ais_static, ~ paste(head(unique(na.omit(as.character(.x))), 5), collapse = ", "))
)

numeric_summary <- ais_static |>
  select(where(is.numeric)) |>
  pivot_longer(everything(), names_to = "column", values_to = "value") |>
  group_by(column) |>
  summarise(
    n_non_missing = sum(!is.na(value)),
    min = suppressWarnings(min(value, na.rm = TRUE)),
    max = suppressWarnings(max(value, na.rm = TRUE)),
    avg = mean(value, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(across(c(min, max, avg), ~ if_else(is.infinite(.x), NA_real_, .x)))

categorical_top_values <- ais_static |>
  select(where(~ !is.numeric(.x))) |>
  pivot_longer(everything(), names_to = "column", values_to = "value") |>
  filter(!is.na(value), value != "") |>
  count(column, value, sort = TRUE, name = "n") |>
  group_by(column) |>
  slice_head(n = 5) |>
  ungroup()

# 2.4 filtered questions ------------------------------------------------------
# Adjust the flag spelling here if your output shows different names.
benelux_flags <- c("Belgium", "Netherlands", "Luxembourg", "BE", "NL", "LU")
benelux_count <- ais_static |>
  filter(flag %in% benelux_flags) |>
  summarise(n = n_distinct(mmsi)) |>
  pull(n)

german_cargo <- ais_static |>
  filter(str_detect(coalesce(flag, ""), regex("^Germany$|^DE$", ignore_case = TRUE)),
         str_detect(coalesce(ship_type, ""), regex("cargo", ignore_case = TRUE)))

german_cargo_count <- n_distinct(german_cargo$mmsi)
german_cargo_long_count <- german_cargo |>
  filter(!is.na(length), length > 150) |>
  summarise(n = n_distinct(mmsi)) |>
  pull(n)

express_count <- ais_static |>
  filter(str_detect(coalesce(name, ""), regex("EXPRESS", ignore_case = TRUE))) |>
  summarise(n = n_distinct(mmsi)) |>
  pull(n)

# Dynamic table: always use tight time filters.
first_5_min_qs <- "select=*&msg_timestamp=gte.2022-01-01T00:00:00Z&msg_timestamp=lt.2022-01-01T00:05:00Z"
first_5_min_count <- api_count_raw("ais_dynamic", first_5_min_qs, count_mode = "exact")

first_5_min_mmsi <- api_get_raw(
  "ais_dynamic",
  "select=mmsi&msg_timestamp=gte.2022-01-01T00:00:00Z&msg_timestamp=lt.2022-01-01T00:05:00Z&limit=1000000"
) |>
  as_tibble()
first_5_min_vessels <- n_distinct(first_5_min_mmsi$mmsi)

fast_records <- api_get_raw(
  "ais_dynamic",
  "select=mmsi&msg_timestamp=gte.2021-05-04T14:00:00Z&msg_timestamp=lt.2021-05-04T14:30:00Z&speed=gt.12&limit=1000000"
) |>
  as_tibble()

fast_vessels <- fast_records |> distinct(mmsi)
n_fast_vessels <- nrow(fast_vessels)

cargo_mmsi <- ais_static |>
  filter(str_detect(coalesce(ship_type, ""), regex("cargo", ignore_case = TRUE))) |>
  distinct(mmsi)

n_fast_cargo_vessels <- fast_vessels |>
  semi_join(cargo_mmsi, by = "mmsi") |>
  nrow()

limit_example <- api_get("ais_static", list(select = "mmsi,name,flag,ship_type", limit = 5)) |>
  as_tibble()

# Save outputs ----------------------------------------------------------------
results <- list(
  metadata = list(created_at = as.character(Sys.time()), base_url = base_url),
  task2_2_available_resources = resources,
  task2_3 = list(
    row_counts = row_counts,
    distinct_vessels = distinct_vessels,
    top_ship_types = ship_types,
    flags = flags,
    n_distinct_flags = n_flags,
    most_common_flag = most_common_flag,
    ais_static_column_overview = column_overview,
    ais_static_numeric_summary = numeric_summary,
    ais_static_categorical_top_values = categorical_top_values
  ),
  task2_4 = list(
    query_logic = list(
      benelux = "Local filtering on ais_static: flag in Belgium, Netherlands, Luxembourg, BE, NL, LU",
      german_cargo = "Local filtering on ais_static: German flag and ship_type contains cargo; length > 150 for long cargo ships",
      express = "Local filtering on ais_static: vessel name contains EXPRESS",
      first_5_minutes_2022 = "ais_dynamic HEAD count and mmsi query filtered to 2022-01-01 00:00:00 <= msg_timestamp < 00:05:00 UTC",
      fast_vessels = "ais_dynamic queried for 2021-05-04 14:00-14:30 UTC with speed > 12; cargo status joined locally from ais_static",
      limit = "PostgREST parameter limit=n returns at most n records"
    ),
    answers = list(
      benelux_ships = benelux_count,
      german_cargo_ships = german_cargo_count,
      german_cargo_longer_150m = german_cargo_long_count,
      express_name_vessels = express_count,
      dynamic_records_first_5_minutes_2022 = first_5_min_count,
      distinct_vessels_first_5_minutes_2022 = first_5_min_vessels,
      vessels_faster_than_12_knots = n_fast_vessels,
      cargo_vessels_faster_than_12_knots = n_fast_cargo_vessels,
      limit_example = limit_example
    )
  )
)

write_json(results, file.path(out_dir, "task2_overview_ai.json"), pretty = TRUE, auto_unbox = TRUE, na = "null")

md <- c(
  "# Task 2 - AIS API Overview",
  "",
  paste0("Created at: ", results$metadata$created_at),
  "",
  "## Important implementation note",
  "Grouped PostgREST aggregate queries were rejected by the server with HTTP 400 in this environment. Therefore, this script computes grouped summaries locally from `ais_static`, which is safe because it contains one row per vessel. The large `ais_dynamic` table is only queried with strict time filters or HEAD counts.",
  "",
  "## Available API resources",
  paste0("- ", resources),
  "",
  "## Row counts",
  capture.output(print(row_counts)),
  "",
  "## Distinct vessels",
  capture.output(print(distinct_vessels)),
  "",
  "## Most frequent ship types",
  capture.output(print(ship_types, n = 30)),
  "",
  "## Most frequent flags",
  capture.output(print(flags, n = 30)),
  paste0("Distinct flags in ais_static: ", n_flags),
  "",
  "## ais_static columns",
  capture.output(print(column_overview, n = Inf)),
  "",
  "## Numeric summaries for ais_static",
  capture.output(print(numeric_summary, n = Inf)),
  "",
  "## Categorical top values for ais_static",
  capture.output(print(categorical_top_values, n = Inf)),
  "",
  "## Task 2.4 answers",
  paste0("- Benelux ships: ", benelux_count),
  paste0("- German cargo ships: ", german_cargo_count),
  paste0("- German cargo ships longer than 150 m: ", german_cargo_long_count),
  paste0("- Vessels with EXPRESS in name: ", express_count),
  paste0("- Dynamic AIS records in first five minutes of 2022: ", first_5_min_count),
  paste0("- Distinct vessels in first five minutes of 2022: ", first_5_min_vessels),
  paste0("- Vessels faster than 12 knots in the 30-minute interval: ", n_fast_vessels),
  paste0("- Of these, cargo vessels: ", n_fast_cargo_vessels),
  "- Limit example: GET /ais_static?select=mmsi,name,flag,ship_type&limit=5"
)

write_lines(md, file.path(out_dir, "task2_overview_human.md"))

message("Done. Wrote:")
message("- ", file.path(out_dir, "task2_overview_ai.json"))
message("- ", file.path(out_dir, "task2_overview_human.md"))
