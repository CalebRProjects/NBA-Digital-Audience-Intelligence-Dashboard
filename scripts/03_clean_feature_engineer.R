# NBA Digital Audience Intelligence Dashboard
# Script 03: Clean and feature engineer YouTube engagement data
#
# Purpose:
# - Combine video metadata, video statistics, and comment sentiment summaries
# - Create engagement KPIs
# - Add basic content classification
# - Export cleaned video-level dataset for SQL and Tableau

# Libraries --------------------------------------------------------------

library(tidyverse)
library(lubridate)
library(janitor)
library(stringr)

# File paths -------------------------------------------------------------

videos_raw_path <- "data/raw/youtube_videos_raw.csv"
video_sentiment_summary_path <- "data/processed/youtube_video_sentiment_summary.csv"

videos_clean_path <- "data/processed/youtube_videos_clean.csv"
tableau_export_path <- "data/exports/tableau_video_level_export.csv"

# Load data --------------------------------------------------------------

videos_raw <- readr::read_csv(videos_raw_path, show_col_types = FALSE) |>
  janitor::clean_names()

video_sentiment_summary <- readr::read_csv(video_sentiment_summary_path, show_col_types = FALSE) |>
  janitor::clean_names()

# Clean and engineer features -------------------------------------------

videos_clean <- videos_raw |>
  left_join(video_sentiment_summary, by = "video_id") |>
  mutate(
    published_at_datetime = ymd_hms(published_at),
    published_date = as_date(published_at_datetime),
    published_hour = hour(published_at_datetime),
    published_month = floor_date(published_date, unit = "month"),
    days_since_published = as.numeric(Sys.Date() - published_date),
    
    view_count = as.numeric(view_count),
    like_count = as.numeric(like_count),
    comment_count = as.numeric(comment_count),
    
    like_count_clean = replace_na(like_count, 0),
    comment_count_clean = replace_na(comment_count, 0),
    
    engagement_count = like_count_clean + comment_count_clean,
    engagement_rate = if_else(view_count > 0, engagement_count / view_count, NA_real_),
    likes_per_1k_views = if_else(view_count > 0, like_count_clean / view_count * 1000, NA_real_),
    comments_per_1k_views = if_else(view_count > 0, comment_count_clean / view_count * 1000, NA_real_),
    views_per_day = if_else(days_since_published > 0, view_count / days_since_published, view_count),
    
    positive_comment_pct = replace_na(positive_comment_pct, 0),
    neutral_comment_pct = replace_na(neutral_comment_pct, 0),
    negative_comment_pct = replace_na(negative_comment_pct, 0),
    avg_comment_sentiment = replace_na(avg_comment_sentiment, 0),
    comments_pulled = replace_na(comments_pulled, 0),
    
    video_title_clean = str_squish(str_to_lower(video_title)),
    video_description_clean = str_squish(str_to_lower(video_description)),
    
    content_type = case_when(
      str_detect(video_title_clean, "shorts|#shorts") |
        str_detect(duration, "^PT[0-9]+S$") ~ "Shorts",
      str_detect(video_title_clean, "highlight|best plays|recap|full season") ~ "Highlights/Recap",
      str_detect(video_title_clean, "interview|press conference|media availability") ~ "Interview/Press",
      str_detect(video_title_clean, "all-access|behind|practice|locker room|mic") ~ "Behind the Scenes",
      str_detect(video_title_clean, "hype|trailer|promo") ~ "Promo/Hype",
      TRUE ~ "Other"
    ),
    
    message_theme = case_when(
      str_detect(video_title_clean, "playoff|finals|ecf|round 1|series") ~ "Playoff Stakes",
      str_detect(video_title_clean, "steph|curry|lebron|luka|shai|jalen|tatum|jt|brunson") ~ "Star Player",
      str_detect(video_title_clean, "rookie|draft|55th pick") ~ "Rookie/Development",
      str_detect(video_title_clean, "coach|kerr|mazzulla|thibodeau") ~ "Coach/Leadership",
      str_detect(video_title_clean, "comeback|not done|greatness|hype") ~ "Team Identity",
      TRUE ~ "General Team Content"
    ),
    
    sentiment_bucket = case_when(
      avg_comment_sentiment > 0.15 ~ "Positive",
      avg_comment_sentiment < -0.15 ~ "Negative",
      TRUE ~ "Neutral"
    ),
    
    high_engagement_flag = engagement_rate >= quantile(engagement_rate, 0.75, na.rm = TRUE),
    high_negative_sentiment_flag = negative_comment_pct >= quantile(negative_comment_pct, 0.75, na.rm = TRUE),
    monitoring_priority = case_when(
      high_engagement_flag & high_negative_sentiment_flag ~ "High Engagement / High Negative Sentiment",
      high_engagement_flag ~ "High Engagement",
      high_negative_sentiment_flag ~ "High Negative Sentiment",
      TRUE ~ "Standard"
    )
  ) |>
  select(
    video_id,
    team,
    team_abbreviation,
    conference,
    channel_name,
    channel_id,
    channel_title,
    video_title,
    video_description,
    published_at,
    published_date,
    published_hour,
    published_month,
    duration,
    content_type,
    message_theme,
    view_count,
    like_count,
    comment_count,
    like_count_clean,
    comment_count_clean,
    engagement_count,
    engagement_rate,
    likes_per_1k_views,
    comments_per_1k_views,
    views_per_day,
    comments_pulled,
    avg_comment_sentiment,
    positive_comment_pct,
    neutral_comment_pct,
    negative_comment_pct,
    sentiment_bucket,
    monitoring_priority
  )

# Save outputs -----------------------------------------------------------

readr::write_csv(videos_clean, videos_clean_path)
readr::write_csv(videos_clean, tableau_export_path)

# QA checks --------------------------------------------------------------

videos_clean |>
  summarise(
    total_videos = n(),
    teams = n_distinct(team),
    total_views = sum(view_count, na.rm = TRUE),
    total_engagements = sum(engagement_count, na.rm = TRUE),
    avg_engagement_rate = mean(engagement_rate, na.rm = TRUE),
    avg_sentiment = mean(avg_comment_sentiment, na.rm = TRUE)
  ) |>
  print()

videos_clean |>
  count(content_type, sort = TRUE) |>
  print()

videos_clean |>
  count(message_theme, sort = TRUE) |>
  print()

videos_clean |>
  count(monitoring_priority, sort = TRUE) |>
  print()

videos_clean |>
  arrange(desc(views_per_day)) |>
  select(team, video_title, content_type, message_theme, view_count, views_per_day, engagement_rate, negative_comment_pct, monitoring_priority) |>
  print(n = 20)

# End --------------------------------------------------------------------