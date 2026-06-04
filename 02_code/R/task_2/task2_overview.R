# Task 2 - AIS API overview with PostgREST aggregations
# Outputs:
#   01_data/task_2/task2_intermediate_results.csv
#   03_report/task_2/task2_overview_ai.json
#   03_report/task_2/task2_overview_human.md

library(tidyverse)
library(httr2)
library(jsonlite)

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
data_dir <- file.path(root_dir, "01_data", "task_2")
out_dir <- file.path(root_dir, "03_report", "task_2")

dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

base_url <- "https://aidaho-edu.uni-hohenheim.de/aisdb"

# -------------------------------------------------------------------------
# API helpers
# -------------------------------------------------------------------------

api_get <- function(path, query = list(), simplifyVector = TRUE, timeout = 180) {
  request(file.path(base_url, path)) |>
    req_url_query(!!!query) |>
    req_headers(Accept = "application/json") |>
    req_timeout(timeout) |>
    req_perform() |>
    resp_body_json(simplifyVector = simplifyVector)
}

api_get_raw <- function(path, query_string, simplifyVector = TRUE, timeout = 180) {
  request(paste0(base_url, "/", path, "?", query_string)) |>
    req_headers(Accept = "application/json") |>
    req_timeout(timeout) |>
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

# -------------------------------------------------------------------------
# 2.2 Available resources
# -------------------------------------------------------------------------

resources_raw <- request(base_url) |>
  req_headers(Accept = "application/openapi+json") |>
  req_timeout(60) |>
  req_perform() |>
  resp_body_json(simplifyVector = TRUE)

resources <- names(resources_raw$paths) |>
  str_remove("^/") |>
  discard(~ .x == "") |>
  discard(~ str_detect(.x, "^rpc/")) |>
  discard(~ .x == "spatial_ref_sys") |>
  sort()

main_tables <- intersect(c("ais_static", "ais_dynamic", "ais_germany"), resources)

message("Loading ais_static for full metadata overview...")

ais_static_full <- api_get(
  "ais_static",
  list(limit = 1000000),
  timeout = 300
) |>
  as_tibble()

# -------------------------------------------------------------------------
# 2.3b Row counts and distinct vessels
# -------------------------------------------------------------------------

row_counts <- tibble(table = main_tables) |>
  mutate(
    count_method = if_else(
      table %in% c("ais_dynamic", "ais_germany"),
      "planned / approximate HEAD count",
      "exact HEAD count"
    ),
    n_rows = map_dbl(table, safe_api_count)
  )

distinct_vessels <- tibble(
  source = "ais_static",
  logic = "ais_static contains one row per MMSI; therefore the exact HEAD row count is used as the number of distinct vessels",
  distinct_mmsi = api_count("ais_static", count_mode = "exact")
)

# -------------------------------------------------------------------------
# 2.3c + 2.3d Grouped summaries with PostgREST aggregations
# -------------------------------------------------------------------------

ship_types <- api_get(
  "ais_static",
  list(select = "ship_type,n:count()", limit = 1000000)
) |>
  as_tibble() |>
  mutate(n = as.numeric(n)) |>
  filter(!is.na(ship_type), ship_type != "") |>
  arrange(desc(n)) |>
  slice_head(n = 30)

flags_all <- api_get(
  "ais_static",
  list(select = "flag,n:count()", limit = 1000000)
) |>
  as_tibble() |>
  mutate(n = as.numeric(n)) |>
  arrange(desc(n))

flags <- flags_all |>
  slice_head(n = 30)

n_flags <- flags_all |>
  filter(!is.na(flag), flag != "") |>
  nrow()

most_common_flag <- flags |>
  slice(1)

# -------------------------------------------------------------------------
# 2.3e ais_static overview
# -------------------------------------------------------------------------

column_overview <- tibble(
  column = names(ais_static_full),
  guessed_r_type = map_chr(ais_static_full, ~ class(.x)[1]),
  n_non_missing = map_int(ais_static_full, ~ sum(!is.na(.x))),
  example_values = map_chr(
    ais_static_full,
    ~ paste(head(unique(na.omit(as.character(.x))), 5), collapse = ", ")
  )
)

numeric_columns <- names(select(ais_static_full, where(is.numeric)))
categorical_columns <- setdiff(names(ais_static_full), numeric_columns)

get_numeric_summary <- function(col) {
  select_query <- paste0(
    "n:", col, ".count(),",
    "min:", col, ".min(),",
    "max:", col, ".max(),",
    "avg:", col, ".avg()"
  )
  
  api_get("ais_static", list(select = select_query)) |>
    as_tibble() |>
    mutate(column = col, .before = 1) |>
    mutate(across(c(n, min, max, avg), as.numeric))
}

numeric_summary <- map_dfr(numeric_columns, get_numeric_summary) |>
  rename(n_non_missing = n)

get_top_values <- function(col) {
  api_get(
    "ais_static",
    list(select = paste0(col, ",n:count()"), limit = 1000000)
  ) |>
    as_tibble() |>
    rename(value = all_of(col)) |>
    mutate(
      column = col,
      value = as.character(value),
      n = as.numeric(n)
    ) |>
    filter(!is.na(value), value != "") |>
    arrange(desc(n)) |>
    slice_head(n = 5) |>
    select(column, value, n)
}

categorical_top_values <- map_dfr(categorical_columns, get_top_values)

# -------------------------------------------------------------------------
# 2.4 Filtered questions
# -------------------------------------------------------------------------

benelux_count <- api_count(
  "ais_static",
  list(flag = "in.(Belgium,Netherlands,Luxembourg,BE,NL,LU)"),
  count_mode = "exact"
)

german_cargo_count <- api_count(
  "ais_static",
  list(
    flag = "in.(Germany,DE)",
    ship_type = "ilike.*cargo*"
  ),
  count_mode = "exact"
)

german_cargo_long_count <- api_count(
  "ais_static",
  list(
    flag = "in.(Germany,DE)",
    ship_type = "ilike.*cargo*",
    length = "gt.150"
  ),
  count_mode = "exact"
)

express_count <- api_count(
  "ais_static",
  list(name = "ilike.*EXPRESS*"),
  count_mode = "exact"
)

first_5_min_qs <- paste0(
  "select=*",
  "&msg_timestamp=gte.2022-01-01T00:00:00Z",
  "&msg_timestamp=lt.2022-01-01T00:05:00Z"
)

first_5_min_count <- api_count_raw(
  "ais_dynamic",
  first_5_min_qs,
  count_mode = "exact"
)

first_5_min_vessels <- api_get_raw(
  "ais_dynamic",
  paste0(
    "select=mmsi,n:count()",
    "&msg_timestamp=gte.2022-01-01T00:00:00Z",
    "&msg_timestamp=lt.2022-01-01T00:05:00Z",
    "&limit=1000000"
  )
) |>
  as_tibble() |>
  nrow()

fast_vessels <- api_get_raw(
  "ais_dynamic",
  paste0(
    "select=mmsi,n:count()",
    "&msg_timestamp=gte.2021-05-04T14:00:00Z",
    "&msg_timestamp=lt.2021-05-04T14:30:00Z",
    "&speed=gt.12",
    "&limit=1000000"
  )
) |>
  as_tibble() |>
  mutate(n = as.numeric(n))

n_fast_vessels <- nrow(fast_vessels)

cargo_mmsi <- api_get(
  "ais_static",
  list(
    select = "mmsi",
    ship_type = "ilike.*cargo*",
    limit = 1000000
  )
) |>
  as_tibble() |>
  distinct(mmsi)

n_fast_cargo_vessels <- fast_vessels |>
  semi_join(cargo_mmsi, by = "mmsi") |>
  nrow()

limit_example <- api_get(
  "ais_static",
  list(select = "mmsi,name,flag,ship_type", limit = 5)
) |>
  as_tibble()

answer_summary <- tibble(
  metric = c(
    "benelux_ships",
    "german_cargo_ships",
    "german_cargo_longer_150m",
    "express_name_vessels",
    "dynamic_records_first_5_minutes_2022",
    "distinct_vessels_first_5_minutes_2022",
    "vessels_faster_than_12_knots",
    "cargo_vessels_faster_than_12_knots"
  ),
  value = c(
    benelux_count,
    german_cargo_count,
    german_cargo_long_count,
    express_count,
    first_5_min_count,
    first_5_min_vessels,
    n_fast_vessels,
    n_fast_cargo_vessels
  )
)

# -------------------------------------------------------------------------
# Save one combined intermediate CSV
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
  tibble(section = "available_resources", variable = "resource", value = resources),
  to_long_table(row_counts, "row_counts"),
  to_long_table(distinct_vessels, "distinct_vessels"),
  to_long_table(ship_types, "ship_type_counts_top30"),
  to_long_table(flags, "flag_counts_top30"),
  to_long_table(most_common_flag, "most_common_flag"),
  to_long_table(column_overview, "ais_static_column_overview"),
  to_long_table(numeric_summary, "ais_static_numeric_summary"),
  to_long_table(categorical_top_values, "ais_static_categorical_top_values"),
  to_long_table(answer_summary, "task2_answer_summary"),
  to_long_table(limit_example, "limit_example_ais_static")
)

write_csv(
  intermediate_results,
  file.path(data_dir, "task2_intermediate_results.csv"),
  na = ""
)

# -------------------------------------------------------------------------
# Save report-ready outputs
# -------------------------------------------------------------------------

results <- list(
  metadata = list(
    created_at = as.character(Sys.time()),
    base_url = base_url,
    root_dir = root_dir,
    data_dir = data_dir,
    out_dir = out_dir
  ),
  
  implementation_decisions = list(
    aggregations =
      "PostgREST aggregations were used because the server now supports grouped summaries efficiently, for example select=ship_type,n:count(). This avoids unnecessary local grouping and improves reproducibility.",
    
    dynamic_table_strategy =
      "The very large ais_dynamic table was never downloaded completely. Only filtered time intervals, grouped aggregate queries, and HEAD counts were used to avoid excessive data transfer.",
    
    count_strategy =
      "Exact HEAD counts were used for smaller tables such as ais_static. Planned/approximate counts were used for very large tables such as ais_dynamic and ais_germany for performance reasons.",
    
    distinct_vessels_logic =
      "ais_static contains one row per MMSI. Therefore, the exact row count of ais_static equals the number of distinct vessels.",
    
    data_quality_note =
      "Some metadata fields contain implausible placeholder or outlier values, for example placeholder text such as @@@@@ or unusually large IMO values. These are treated as source-data quality issues and do not materially affect the task results."
  ),
  
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
      benelux = "PostgREST HEAD count on ais_static with flag=in.(Belgium,Netherlands,Luxembourg,BE,NL,LU)",
      german_cargo = "PostgREST HEAD count on ais_static with German flag and ship_type ilike *cargo*; length=gt.150 for long cargo ships",
      express = "PostgREST HEAD count on ais_static with name ilike *EXPRESS*",
      first_5_minutes_2022 = "ais_dynamic HEAD count filtered to 2022-01-01 00:00:00 <= msg_timestamp < 00:05:00 UTC; distinct vessels via grouped aggregate select=mmsi,n:count()",
      fast_vessels = "ais_dynamic grouped aggregate by mmsi for 2021-05-04 14:00-14:30 UTC with speed > 12; cargo status joined from ais_static",
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

write_json(
  results,
  file.path(out_dir, "task2_overview_ai.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  na = "null"
)

md <- c(
  "# Task 2 - AIS API Overview",
  "",
  paste0("Created at: ", results$metadata$created_at),
  "",
  "## Important implementation note",
  "This script uses the now-enabled PostgREST aggregate functions for grouped summaries such as `select=ship_type,n:count()`. The large `ais_dynamic` table is still only queried with strict time filters, HEAD counts, or grouped aggregate queries to avoid downloading large unfiltered datasets.",
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
  "## Data quality note",
  "Some AIS metadata contain implausible placeholder or outlier values (e.g., unusually large IMO values or placeholder-like text such as '@@@@@'). This indicates minor data quality issues in the source AIS metadata but does not materially affect the task results.",
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

message("Done. Wrote one intermediate file to:")
message("- ", file.path(data_dir, "task2_intermediate_results.csv"))
message("Done. Wrote report-ready files to:")
message("- ", file.path(out_dir, "task2_overview_ai.json"))
message("- ", file.path(out_dir, "task2_overview_human.md"))