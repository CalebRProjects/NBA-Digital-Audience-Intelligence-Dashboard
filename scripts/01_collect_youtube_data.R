# NBA Digital Audience Intelligence Dashboard
# Script 01: Collect YouTube video and comment data
#
# Purpose:
# - Read NBA team YouTube channel list
# - Pull recent video metadata
# - Pull sample comments per video
# - Save raw CSV files for downstream cleaning and analysis

library(tidyverse)
library(lubridate)

# File paths -------------------------------------------------------------

team_channels_path <- "data/raw/nba_team_youtube_channels.csv"

videos_raw_path <- "data/raw/youtube_videos_raw.csv"
comments_raw_path <- "data/raw/youtube_comments_raw.csv"

# Load team channel reference -------------------------------------------

team_channels <- readr::read_csv(team_channels_path, show_col_types = FALSE)

glimpse(team_channels)