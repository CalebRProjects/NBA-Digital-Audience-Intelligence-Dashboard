# NBA Digital Audience Intelligence Dashboard
# Script 02: Collect YouTube comments and apply sentiment analysis
#
# Purpose:
# - Read collected YouTube video metadata
# - Pull a sample of top-level comments for each video
# - Apply lexicon-based sentiment analysis
# - Save comment-level and video-level sentiment datasets

# Libraries --------------------------------------------------------------

library(tidyverse)
library(httr2)
library(jsonlite)
library(janitor)
library(stringr)
library(lubridate)
library(syuzhet)

# YouTube API setup ------------------------------------------------------

api_key <- Sys.getenv("YOUTUBE_API_KEY")

if (api_key == "") {
  stop("YouTube API key not found. Add YOUTUBE_API_KEY to your .Renviron file.")
}

# File paths -------------------------------------------------------------

videos_raw_path <- "data/raw/youtube_videos_raw.csv"
comments_raw_path <- "data/raw/youtube_comments_raw.csv"
comments_sentiment_path <- "data/processed/youtube_comments_sentiment.csv"
video_sentiment_summary_path <- "data/processed/youtube_video_sentiment_summary.csv"

# Load videos ------------------------------------------------------------

videos_raw <- readr::read_csv(videos_raw_path, show_col_types = FALSE) |>
  janitor::clean_names()

glimpse(videos_raw)

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

# Helper: get top-level comments for one video ---------------------------

get_video_comments <- function(video_id, api_key, max_results = 50) {
  
  response <- tryCatch(
    {
      request("https://www.googleapis.com/youtube/v3/commentThreads") |>
        req_url_query(
          part = "snippet",
          videoId = video_id,
          maxResults = max_results,
          order = "relevance",
          textFormat = "plainText",
          key = api_key
        ) |>
        req_perform() |>
        resp_body_json(simplifyVector = FALSE)
    },
    error = function(e) {
      return(NULL)
    }
  )
  
  if (is.null(response) || length(response$items) == 0) {
    return(tibble())
  }
  
  map_dfr(response$items, function(item) {
    
    top_comment <- item$snippet$topLevelComment
    comment_snippet <- top_comment$snippet
    
    tibble(
      video_id = video_id,
      comment_id = pluck_chr_safe(top_comment$id),
      comment_text = pluck_chr_safe(comment_snippet$textDisplay),
      comment_like_count = pluck_num_safe(comment_snippet$likeCount),
      comment_published_at = pluck_chr_safe(comment_snippet$publishedAt)
    )
  })
}

# Pull comments ----------------------------------------------------------

comment_video_ids <- videos_raw |>
  filter(!is.na(comment_count), comment_count > 0) |>
  distinct(video_id) |>
  pull(video_id)

comments_raw <- map_dfr(
  comment_video_ids,
  ~ get_video_comments(
    video_id = .x,
    api_key = api_key,
    max_results = 50
  )
)

comments_raw <- comments_raw |>
  left_join(
    videos_raw |>
      select(video_id, team, team_abbreviation, conference, channel_title, video_title, published_at),
    by = "video_id"
  )

glimpse(comments_raw)

readr::write_csv(comments_raw, comments_raw_path)

# Sentiment analysis -----------------------------------------------------

comments_sentiment <- comments_raw |>
  mutate(
    comment_text_clean = str_squish(comment_text),
    sentiment_score = syuzhet::get_sentiment(comment_text_clean, method = "syuzhet"),
    sentiment_label = case_when(
      sentiment_score > 0.15 ~ "Positive",
      sentiment_score < -0.15 ~ "Negative",
      TRUE ~ "Neutral"
    )
  )

glimpse(comments_sentiment)

readr::write_csv(comments_sentiment, comments_sentiment_path)

# Aggregate sentiment to video level ------------------------------------

video_sentiment_summary <- comments_sentiment |>
  group_by(video_id) |>
  summarise(
    comments_pulled = n(),
    avg_comment_sentiment = mean(sentiment_score, na.rm = TRUE),
    positive_comment_pct = mean(sentiment_label == "Positive", na.rm = TRUE),
    neutral_comment_pct = mean(sentiment_label == "Neutral", na.rm = TRUE),
    negative_comment_pct = mean(sentiment_label == "Negative", na.rm = TRUE),
    .groups = "drop"
  )

glimpse(video_sentiment_summary)

readr::write_csv(video_sentiment_summary, video_sentiment_summary_path)

# Quick QA checks --------------------------------------------------------

comments_sentiment |>
  count(sentiment_label, sort = TRUE) |>
  mutate(pct = n / sum(n)) |>
  print()

video_sentiment_summary |>
  arrange(desc(negative_comment_pct)) |>
  print(n = 20)

# End --------------------------------------------------------------------