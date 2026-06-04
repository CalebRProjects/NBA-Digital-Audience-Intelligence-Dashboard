# NBA Digital Audience Intelligence Dashboard
# Script 04: Build SQLite database
#
# Purpose:
# - Load cleaned YouTube video-level dataset
# - Create a local SQLite database
# - Write cleaned dataset into a staging table for SQL practice

library(tidyverse)
library(DBI)
library(RSQLite)
library(janitor)

videos_clean_path <- "data/processed/youtube_videos_clean.csv"
db_path <- "data/exports/nba_digital_audience.db"

videos_clean <- readr::read_csv(videos_clean_path, show_col_types = FALSE) |>
  janitor::clean_names()

glimpse(videos_clean)

con <- DBI::dbConnect(
  RSQLite::SQLite(),
  dbname = db_path
)

DBI::dbWriteTable(
  con,
  name = "stg_youtube_videos",
  value = videos_clean,
  overwrite = TRUE
)

print(DBI::dbListTables(con))

print(DBI::dbGetQuery(
  con,
  "SELECT COUNT(*) AS total_rows FROM stg_youtube_videos;"
))

DBI::dbDisconnect(con)