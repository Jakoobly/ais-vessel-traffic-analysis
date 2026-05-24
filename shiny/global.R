library(shiny)
library(dplyr)
library(ggplot2)
library(httr)
library(jsonlite)

# -------------------------------------------------------
# TODO: replace with your own PostgREST endpoint
# -------------------------------------------------------
API_URL <- "https://FIXME/aisdb"

# -------------------------------------------------------
# TODO: create these files and uncomment the source() calls
# -------------------------------------------------------
# source("fetch_traffic.R")
# source("plot_traffic.R")