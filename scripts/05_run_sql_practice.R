# NBA Digital Audience Intelligence Dashboard
# Script 05: Run SQL practice queries
#
# Purpose:
# - Connect to the SQLite database
# - Run basic SQL queries while learning SQL fundamentals

library(DBI)
library(RSQLite)

db_path <- "data/exports/nba_digital_audience.db"

con <- DBI::dbConnect(
  RSQLite::SQLite(),
  dbname = db_path
)

# Check available tables -------------------------------------------------

DBI::dbListTables(con)

# Query 1: Preview rows --------------------------------------------------

DBI::dbGetQuery(con, "
SELECT
    *
FROM stg_youtube_videos
LIMIT 10;
")

# Query 2: Most viewed videos --------------------------------------------

DBI::dbGetQuery(con, "
SELECT
    team,
    video_title,
    view_count,
    like_count_clean,
    comment_count_clean
FROM stg_youtube_videos
ORDER BY view_count DESC
LIMIT 20;
")

# Query 3: Team-level KPI summary ----------------------------------------

DBI::dbGetQuery(con, "
SELECT
    team,
    COUNT(*) AS total_videos,
    SUM(view_count) AS total_views,
    SUM(like_count_clean) AS total_likes,
    SUM(comment_count_clean) AS total_comments,
    SUM(engagement_count) AS total_engagements,
    ROUND(SUM(engagement_count) * 1.0 / SUM(view_count), 4) AS weighted_engagement_rate,
    ROUND(AVG(avg_comment_sentiment), 4) AS avg_comment_sentiment
FROM stg_youtube_videos
GROUP BY team
ORDER BY total_views DESC;
")

# Query 4: Content type performance --------------------------------------

DBI::dbGetQuery(con, "
SELECT
    content_type,
    COUNT(*) AS total_videos,
    SUM(view_count) AS total_views,
    SUM(engagement_count) AS total_engagements,
    ROUND(SUM(engagement_count) * 1.0 / SUM(view_count), 4) AS weighted_engagement_rate,
    ROUND(AVG(negative_comment_pct), 4) AS avg_negative_comment_pct
FROM stg_youtube_videos
GROUP BY content_type
ORDER BY total_views DESC;
")

# Query 5: Monitoring priority videos ------------------------------------

DBI::dbGetQuery(con, "
SELECT
    team,
    video_title,
    content_type,
    message_theme,
    view_count,
    ROUND(engagement_rate, 4) AS engagement_rate,
    ROUND(negative_comment_pct, 4) AS negative_comment_pct,
    monitoring_priority
FROM stg_youtube_videos
WHERE monitoring_priority != 'Standard'
ORDER BY view_count DESC;
")

DBI::dbDisconnect(con)
