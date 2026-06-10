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


# Project settings -------------------------------------------------------

PLAYOFF_START_DATE <- as.Date("2026-04-18")
END_DATE <- Sys.Date()

MAX_VIDEOS_PER_TEAM <- 20
SEARCH_RESULTS_PER_TEAM <- 100

# Load team channel reference -------------------------------------------

team_channels <- tibble::tribble(
  ~team, ~team_abbreviation, ~conference, ~seed, ~channel_id,
  "Detroit Pistons", "DET", "East", 1, "UCtcSBo9EzOtXHxiPhU6RN8A",
  "Orlando Magic", "ORL", "East", 8, "UCxHFH-yfbhUrsWY4prPx3oQ",
  "Boston Celtics", "BOS", "East", 2, "UCMfT9dr6xC_RIWoA9hI0meQ",
  "Philadelphia 76ers", "PHI", "East", 7, "UC5qJUyng_ezl0TVjVJFqtfQ",
  "New York Knicks", "NYK", "East", 3, "UC0hb8f0OXHEzDrJDUq-YVVw",
  "Atlanta Hawks", "ATL", "East", 6, "UCpfcwELvR1wtcRJ0UxNXHYw",
  "Cleveland Cavaliers", "CLE", "East", 4, "UCOdS-I1sYkKWhtTjMUWP_TA",
  "Toronto Raptors", "TOR", "East", 5, "UCYBFE432C2AmNRDGEXE4uVg",
  "Oklahoma City Thunder", "OKC", "West", 1, "UCpXdQhy6kb5CTD8hKlmOL3w",
  "Phoenix Suns", "PHX", "West", 8, "UCLxlWVVHz2a8SdCfxzVXzQw",
  "San Antonio Spurs", "SAS", "West", 2, "UCEZHE-0CoHqeL1LGFa2EmQw",
  "Portland Trail Blazers", "POR", "West", 7, "UCXk66yyzXo7-2M1BMqLhltQ",
  "Denver Nuggets", "DEN", "West", 3, "UCl8hzdP5wVlhuzNG3WCJa1w",
  "Minnesota Timberwolves", "MIN", "West", 6, "UCXWDN5NKVFgnPt25CMh98Cg",
  "Los Angeles Lakers", "LAL", "West", 4, "UC8CSt-oVqy8pUAoKSApTxQw",
  "Houston Rockets", "HOU", "West", 5, "UCVD7l69MVGFq_wzQvbk9HbQ"
) |>
  dplyr::mutate(channel_name = team)

validate_channel <- function(channel_id) {
  resp <- httr2::request("https://www.googleapis.com/youtube/v3/channels") |>
    httr2::req_url_query(
      part = "snippet,statistics",
      id = channel_id,
      key = api_key
    ) |>
    httr2::req_perform() |>
    httr2::resp_body_json(simplifyVector = TRUE)
  
  if (length(resp$items) == 0) {
    return(tibble::tibble(
      checked_channel_id = channel_id,
      channel_title = NA_character_,
      subscriber_count = NA_real_,
      valid_channel = FALSE
    ))
  }
  
  tibble::tibble(
    checked_channel_id = channel_id,
    channel_title = resp$items$snippet$title,
    subscriber_count = as.numeric(resp$items$statistics$subscriberCount),
    valid_channel = TRUE
  )
}

channel_check <- team_channels |>
  dplyr::mutate(channel_info = purrr::map(channel_id, validate_channel)) |>
  tidyr::unnest(channel_info)

channel_check |>
  dplyr::select(
    team,
    team_abbreviation,
    channel_id,
    channel_title,
    subscriber_count,
    valid_channel
  ) |>
  print(n = 20)

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

# Helper: get uploads playlist for a channel -----------------------------

get_uploads_playlist_id <- function(channel_id, api_key) {
  
  response <- httr2::request("https://www.googleapis.com/youtube/v3/channels") |>
    httr2::req_url_query(
      part = "contentDetails",
      id = channel_id,
      key = api_key
    ) |>
    httr2::req_perform() |>
    httr2::resp_body_json(simplifyVector = FALSE)
  
  if (length(response$items) == 0) {
    return(NA_character_)
  }
  
  response$items[[1]]$contentDetails$relatedPlaylists$uploads
}

# Helper: get recent uploads from a channel ------------------------------

get_channel_videos <- function(channel_id, api_key, max_results = 100) {
  
  uploads_playlist_id <- get_uploads_playlist_id(channel_id, api_key)
  
  if (is.na(uploads_playlist_id)) {
    return(tibble())
  }
  
  all_items <- list()
  next_page_token <- NULL
  results_collected <- 0
  
  repeat {
    
    response <- httr2::request("https://www.googleapis.com/youtube/v3/playlistItems") |>
      httr2::req_url_query(
        part = "snippet,contentDetails",
        playlistId = uploads_playlist_id,
        maxResults = min(50, max_results - results_collected),
        pageToken = next_page_token,
        key = api_key
      ) |>
      httr2::req_perform() |>
      httr2::resp_body_json(simplifyVector = FALSE)
    
    if (length(response$items) == 0) {
      break
    }
    
    all_items[[length(all_items) + 1]] <- purrr::map_dfr(response$items, function(item) {
      tibble(
        video_id = item$contentDetails$videoId,
        published_at = item$contentDetails$videoPublishedAt,
        channel_title = item$snippet$channelTitle,
        video_title = item$snippet$title,
        video_description = item$snippet$description
      )
    })
    
    results_collected <- results_collected + length(response$items)
    next_page_token <- response$nextPageToken
    
    if (is.null(next_page_token) || results_collected >= max_results) {
      break
    }
    
    Sys.sleep(0.1)
  }
  
  dplyr::bind_rows(all_items)
}

# Pull recent videos -----------------------------------------------------

published_after <- paste0(PLAYOFF_START_DATE, "T00:00:00Z")

videos_base <- team_channels |>
  mutate(
    video_data = map(
      channel_id,
      ~ get_channel_videos(
        channel_id = .x,
        api_key = api_key,
        max_results = SEARCH_RESULTS_PER_TEAM
      )
    )
  ) |>
  select(
    team,
    team_abbreviation,
    conference,
    channel_id,
    video_data
  ) |>
  tidyr::unnest(video_data) |>
  mutate(
    published_at_datetime = lubridate::ymd_hms(published_at),
    published_date = lubridate::as_date(published_at_datetime)
  ) |>
  filter(
    published_date >= PLAYOFF_START_DATE,
    published_date <= END_DATE
  ) |>
  group_by(team) |>
  arrange(desc(published_at_datetime), .by_group = TRUE) |>
  slice_head(n = MAX_VIDEOS_PER_TEAM) |>
  ungroup() |>
  select(
    team,
    team_abbreviation,
    conference,
    channel_id,
    video_id,
    published_at,
    channel_title,
    video_title,
    video_description
  )

glimpse(videos_base)

videos_base |>
  count(team, name = "videos_collected") |>
  arrange(team) |>
  print(n = 20)

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