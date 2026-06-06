# NBA Digital Audience Intelligence Dashboard
# Script 06: Run analysis SQL queries
#
# Purpose:
# - Connect to the local SQLite database
# - Run selected analysis queries from the SQL workflow

library(DBI)
library(RSQLite)

db_path <- "data/exports/nba_digital_audience.db"

con <- DBI::dbConnect(
  RSQLite::SQLite(),
  dbname = db_path
)

# Check table exists -----------------------------------------------------

print(DBI::dbListTables(con))

# 1. Executive KPI summary ----------------------------------------------

executive_summary <- DBI::dbGetQuery(con, "
SELECT
    COUNT(*) AS total_videos,
    COUNT(DISTINCT team) AS total_teams,
    SUM(view_count) AS total_views,
    SUM(like_count_clean) AS total_likes,
    SUM(comment_count_clean) AS total_comments,
    SUM(engagement_count) AS total_engagements,
    ROUND(SUM(engagement_count) * 1.0 / SUM(view_count), 4) AS weighted_engagement_rate,
    ROUND(AVG(avg_comment_sentiment), 4) AS avg_comment_sentiment,
    ROUND(AVG(positive_comment_pct), 4) AS avg_positive_comment_pct,
    ROUND(AVG(negative_comment_pct), 4) AS avg_negative_comment_pct
FROM stg_youtube_videos;
")

print(executive_summary)


# 2. Team performance summary -------------------------------------------

team_performance <- DBI::dbGetQuery(con, "
SELECT
    team,
    conference,
    COUNT(*) AS total_videos,
    SUM(view_count) AS total_views,
    SUM(like_count_clean) AS total_likes,
    SUM(comment_count_clean) AS total_comments,
    SUM(engagement_count) AS total_engagements,
    ROUND(SUM(engagement_count) * 1.0 / SUM(view_count), 4) AS weighted_engagement_rate,
    ROUND(AVG(views_per_day), 2) AS avg_views_per_day,
    ROUND(AVG(avg_comment_sentiment), 4) AS avg_comment_sentiment,
    ROUND(AVG(positive_comment_pct), 4) AS avg_positive_comment_pct,
    ROUND(AVG(negative_comment_pct), 4) AS avg_negative_comment_pct
FROM stg_youtube_videos
GROUP BY team, conference
ORDER BY total_views DESC;
")

print(team_performance)


# 3. Content type performance -------------------------------------------

content_performance <- DBI::dbGetQuery(con, "
SELECT
    content_type,
    COUNT(*) AS total_videos,
    SUM(view_count) AS total_views,
    SUM(engagement_count) AS total_engagements,
    ROUND(SUM(engagement_count) * 1.0 / SUM(view_count), 4) AS weighted_engagement_rate,
    ROUND(AVG(views_per_day), 2) AS avg_views_per_day,
    ROUND(AVG(comments_per_1k_views), 2) AS avg_comments_per_1k_views,
    ROUND(AVG(avg_comment_sentiment), 4) AS avg_comment_sentiment,
    ROUND(AVG(positive_comment_pct), 4) AS avg_positive_comment_pct,
    ROUND(AVG(negative_comment_pct), 4) AS avg_negative_comment_pct
FROM stg_youtube_videos
GROUP BY content_type
ORDER BY total_views DESC;
")

print(content_performance)


# 4. Monitoring priority videos -----------------------------------------

monitoring_priority <- DBI::dbGetQuery(con, "
SELECT
    team,
    video_title,
    content_type,
    message_theme,
    published_date,
    view_count,
    ROUND(engagement_rate, 4) AS engagement_rate,
    ROUND(negative_comment_pct, 4) AS negative_comment_pct,
    ROUND(avg_comment_sentiment, 4) AS avg_comment_sentiment,
    monitoring_priority
FROM stg_youtube_videos
WHERE monitoring_priority != 'Standard'
ORDER BY view_count DESC;
")

print(monitoring_priority)


# Save SQL outputs -------------------------------------------------------

readr::write_csv(executive_summary, "data/exports/sql_executive_summary.csv")
readr::write_csv(team_performance, "data/exports/sql_team_performance.csv")
readr::write_csv(content_performance, "data/exports/sql_content_performance.csv")
readr::write_csv(monitoring_priority, "data/exports/sql_monitoring_priority.csv")

DBI::dbDisconnect(con)