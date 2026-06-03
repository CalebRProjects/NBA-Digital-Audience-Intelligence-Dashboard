# NBA Digital Audience Intelligence Dashboard
# Script 01: Collect YouTube video metadata and statistics
#
# Purpose:
# - Read NBA team YouTube channel list
# - Search for official YouTube channels when needed
# - Pull recent video metadata
# - Pull video statistics
# - Save raw CSV files for downstream cleaning, sentiment, SQL, and Tableau

# Libraries --------------------------------------------------------------

library(tidyverse)
library(lubridate)
library(httr2)
library(jsonlite)
library(glue)
library(janitor)
library(stringr)

# YouTube API setup ------------------------------------------------------

api_key <- Sys.getenv("YOUTUBE_API_KEY")

if (api_key == "") {
  stop("YouTube API key not found. Add YOUTUBE_API_KEY to your .Renviron file.")
}

# File paths -------------------------------------------------------------

team_channels_path <- "data/raw/nba_team_youtube_channels.csv"

videos_base_raw_path <- "data/raw/youtube_videos_base_raw.csv"
videos_raw_path <- "data/raw/youtube_videos_raw.csv"
comments_raw_path <- "data/raw/youtube_comments_raw.csv"

# Load team channel reference -------------------------------------------

team_channels <- readr::read_csv(team_channels_path, show_col_types = FALSE) |>
  janitor::clean_names() |>
  filter(!is.na(channel_id))

glimpse(team_channels)

if (nrow(team_channels) == 0) {
  stop("No channel IDs found. Fill data/raw/nba_team_youtube_channels.csv before collecting videos.")
}

# Helper: search for YouTube channels -----------------------------------
# Use this manually if you need to find more channel IDs later.

search_youtube_channel <- function(query, api_key) {
  
  response <- request("https://www.googleapis.com/youtube/v3/search") |>
    req_url_query(
      part = "snippet",
      q = query,
      type = "channel",
      maxResults = 5,
      key = api_key
    ) |>
    req_perform() |>
    resp_body_json(simplifyVector = TRUE)
  
  if (length(response$items) == 0) {
    return(tibble())
  }
  
  tibble(
    channel_title = response$items$snippet$title,
    channel_id = response$items$id$channelId,
    channel_description = response$items$snippet$description
  )
}

# Helper: safely pull nested values -------------------------------------

pluck_chr_safe <- function(x) {
  if (is.null(x)) {
    return(NA_character_)
  }
  
  as.character(x)
}

pluck_num_safe <- function(x) {
  if (is.null(x)) {
    return(NA_real_)
  }
  
  as.numeric(x)
}

# Helper: get recent videos from a channel -------------------------------

get_channel_videos <- function(channel_id, api_key, published_after, max_results = 20) {
  
  response <- request("https://www.googleapis.com/youtube/v3/search") |>
    req_url_query(
      part = "snippet",
      channelId = channel_id,
      type = "video",
      order = "date",
      publishedAfter = published_after,
      maxResults = max_results,
      key = api_key
    ) |>
    req_perform() |>
    resp_body_json(simplifyVector = TRUE)
  
  if (length(response$items) == 0) {
    return(tibble())
  }
  
  tibble(
    video_id = response$items$id$videoId,
    published_at = response$items$snippet$publishedAt,
    channel_title = response$items$snippet$channelTitle,
    video_title = response$items$snippet$title,
    video_description = response$items$snippet$description
  )
}

# Pull recent videos -----------------------------------------------------

published_after <- as.character(Sys.Date() - 183)
published_after <- paste0(published_after, "T00:00:00Z")

videos_base <- team_channels |>
  mutate(
    video_data = map(
      channel_id,
      ~ get_channel_videos(
        channel_id = .x,
        api_key = api_key,
        published_after = published_after,
        max_results = 20
      )
    )
  ) |>
  select(
    team,
    team_abbreviation,
    conference,
    channel_name,
    channel_id,
    video_data
  ) |>
  tidyr::unnest(video_data)

glimpse(videos_base)

readr::write_csv(videos_base, videos_base_raw_path)

# Helper: get video statistics ------------------------------------------

get_video_stats <- function(video_ids, api_key) {
  
  video_id_string <- paste(video_ids, collapse = ",")
  
  response <- request("https://www.googleapis.com/youtube/v3/videos") |>
    req_url_query(
      part = "statistics,contentDetails",
      id = video_id_string,
      key = api_key
    ) |>
    req_perform() |>
    resp_body_json(simplifyVector = FALSE)
  
  if (length(response$items) == 0) {
    return(tibble())
  }
  
  map_dfr(response$items, function(item) {
    
    stats <- item$statistics
    details <- item$contentDetails
    
    tibble(
      video_id = pluck_chr_safe(item$id),
      view_count = pluck_num_safe(stats$viewCount),
      like_count = pluck_num_safe(stats$likeCount),
      comment_count = pluck_num_safe(stats$commentCount),
      duration = pluck_chr_safe(details$duration)
    )
  })
}

# Pull video statistics --------------------------------------------------

video_ids <- videos_base |>
  distinct(video_id) |>
  pull(video_id)

video_id_batches <- split(
  video_ids,
  ceiling(seq_along(video_ids) / 50)
)

video_stats <- map_dfr(
  video_id_batches,
  ~ get_video_stats(.x, api_key)
)

videos_raw <- videos_base |>
  left_join(video_stats, by = "video_id")

glimpse(videos_raw)

readr::write_csv(videos_raw, videos_raw_path)

# Quick QA checks --------------------------------------------------------

videos_raw |>
  summarise(
    total_videos = n(),
    teams = n_distinct(team),
    total_views = sum(view_count, na.rm = TRUE),
    total_likes = sum(like_count, na.rm = TRUE),
    total_comments = sum(comment_count, na.rm = TRUE),
    missing_view_count = sum(is.na(view_count)),
    missing_like_count = sum(is.na(like_count)),
    missing_comment_count = sum(is.na(comment_count))
  ) |>
  print()

videos_raw |>
  select(
    team,
    video_title,
    published_at,
    view_count,
    like_count,
    comment_count,
    duration
  ) |>
  arrange(desc(view_count)) |>
  print(n = 20)

# End --------------------------------------------------------------------