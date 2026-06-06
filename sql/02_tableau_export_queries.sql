-- NBA Digital Audience Intelligence Dashboard
-- 02_tableau_export_queries.sql
--
-- Purpose:
-- Tableau-ready SQL queries for dashboard data sources.
--
-- Current Tableau approach:
-- Tableau can use data/exports/tableau_video_level_export.csv directly.
-- These queries document the cleaned SQL outputs that support each dashboard page.


-- 1. Main video-level dashboard export ---------------------------------
-- One row per video.
-- Best for Tableau filters, detail tables, scatterplots, and video-level analysis.

SELECT
    video_id,
    team,
    team_abbreviation,
    conference,
    channel_title,
    video_title,
    published_date,
    published_hour,
    published_month,
    duration,
    content_type,
    message_theme,
    view_count,
    like_count_clean,
    comment_count_clean,
    engagement_count,
    ROUND(engagement_rate, 4) AS engagement_rate,
    ROUND(likes_per_1k_views, 2) AS likes_per_1k_views,
    ROUND(comments_per_1k_views, 2) AS comments_per_1k_views,
    ROUND(views_per_day, 2) AS views_per_day,
    comments_pulled,
    ROUND(avg_comment_sentiment, 4) AS avg_comment_sentiment,
    ROUND(positive_comment_pct, 4) AS positive_comment_pct,
    ROUND(neutral_comment_pct, 4) AS neutral_comment_pct,
    ROUND(negative_comment_pct, 4) AS negative_comment_pct,
    sentiment_bucket,
    monitoring_priority
FROM stg_youtube_videos;


-- 2. Executive KPI export ----------------------------------------------
-- One-row KPI summary for dashboard cards.

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


-- 3. Team dashboard export ---------------------------------------------
-- Aggregated team-level table for bar charts and comparison views.

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


-- 4. Content type dashboard export -------------------------------------
-- Aggregated content-type table for content strategy analysis.

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


-- 5. Message theme dashboard export ------------------------------------
-- Aggregated message-theme table for storytelling and audience-response analysis.

SELECT
    message_theme,
    COUNT(*) AS total_videos,
    SUM(view_count) AS total_views,
    SUM(engagement_count) AS total_engagements,
    ROUND(SUM(engagement_count) * 1.0 / SUM(view_count), 4) AS weighted_engagement_rate,
    ROUND(AVG(views_per_day), 2) AS avg_views_per_day,
    ROUND(AVG(avg_comment_sentiment), 4) AS avg_comment_sentiment,
    ROUND(AVG(negative_comment_pct), 4) AS avg_negative_comment_pct
FROM stg_youtube_videos
GROUP BY message_theme
ORDER BY total_views DESC;


-- 6. Monitoring dashboard export ---------------------------------------
-- Table for identifying videos that may need digital monitoring attention.

SELECT
    team,
    video_title,
    content_type,
    message_theme,
    published_date,
    view_count,
    engagement_count,
    ROUND(engagement_rate, 4) AS engagement_rate,
    ROUND(views_per_day, 2) AS views_per_day,
    ROUND(positive_comment_pct, 4) AS positive_comment_pct,
    ROUND(negative_comment_pct, 4) AS negative_comment_pct,
    ROUND(avg_comment_sentiment, 4) AS avg_comment_sentiment,
    monitoring_priority
FROM stg_youtube_videos
WHERE monitoring_priority != 'Standard'
ORDER BY view_count DESC;