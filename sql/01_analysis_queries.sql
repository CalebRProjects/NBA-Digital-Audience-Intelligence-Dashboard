-- NBA Digital Audience Intelligence Dashboard
-- 01_analysis_queries.sql
--
-- Purpose:
-- Business-facing SQL queries for digital engagement, content performance,
-- audience sentiment, and monitoring priorities.
--
-- Source table:
-- stg_youtube_videos


-- 1. Executive KPI summary ---------------------------------------------
-- Overall performance across the full sample.

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


-- 2. Team performance summary ------------------------------------------
-- Compares reach, engagement, and sentiment by team.

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


-- 3. Content type performance ------------------------------------------
-- Evaluates which content formats drive reach, engagement, and comment response.

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


-- 4. Message theme performance -----------------------------------------
-- Evaluates which themes generate the strongest audience response.

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


-- 5. Top videos by views ------------------------------------------------
-- Identifies the highest-reach videos in the sample.

SELECT
    team,
    video_title,
    content_type,
    message_theme,
    published_date,
    view_count,
    like_count_clean,
    comment_count_clean,
    engagement_count,
    ROUND(engagement_rate, 4) AS engagement_rate,
    ROUND(avg_comment_sentiment, 4) AS avg_comment_sentiment
FROM stg_youtube_videos
ORDER BY view_count DESC
LIMIT 25;


-- 6. Top videos by engagement rate --------------------------------------
-- Uses a minimum view threshold so tiny videos do not dominate the result.

SELECT
    team,
    video_title,
    content_type,
    message_theme,
    published_date,
    view_count,
    engagement_count,
    ROUND(engagement_rate, 4) AS engagement_rate,
    ROUND(positive_comment_pct, 4) AS positive_comment_pct,
    ROUND(negative_comment_pct, 4) AS negative_comment_pct
FROM stg_youtube_videos
WHERE view_count >= 10000
ORDER BY engagement_rate DESC
LIMIT 25;


-- 7. Sentiment summary by team -----------------------------------------
-- Compares average comment sentiment across team channels.

SELECT
    team,
    COUNT(*) AS total_videos,
    ROUND(AVG(avg_comment_sentiment), 4) AS avg_comment_sentiment,
    ROUND(AVG(positive_comment_pct), 4) AS avg_positive_comment_pct,
    ROUND(AVG(neutral_comment_pct), 4) AS avg_neutral_comment_pct,
    ROUND(AVG(negative_comment_pct), 4) AS avg_negative_comment_pct
FROM stg_youtube_videos
GROUP BY team
ORDER BY avg_comment_sentiment DESC;


-- 8. Sentiment summary by content type ---------------------------------
-- Shows which content formats receive more positive or negative audience response.

SELECT
    content_type,
    COUNT(*) AS total_videos,
    ROUND(AVG(avg_comment_sentiment), 4) AS avg_comment_sentiment,
    ROUND(AVG(positive_comment_pct), 4) AS avg_positive_comment_pct,
    ROUND(AVG(neutral_comment_pct), 4) AS avg_neutral_comment_pct,
    ROUND(AVG(negative_comment_pct), 4) AS avg_negative_comment_pct
FROM stg_youtube_videos
GROUP BY content_type
ORDER BY avg_comment_sentiment DESC;


-- 9. Monitoring priority videos ----------------------------------------
-- Flags videos with high engagement, high negative sentiment, or both.

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
ORDER BY
    CASE
        WHEN monitoring_priority = 'High Engagement / High Negative Sentiment' THEN 1
        WHEN monitoring_priority = 'High Negative Sentiment' THEN 2
        WHEN monitoring_priority = 'High Engagement' THEN 3
        ELSE 4
    END,
    view_count DESC;


-- 10. Publishing hour performance --------------------------------------
-- Evaluates whether post timing is associated with reach or engagement.

SELECT
    published_hour,
    COUNT(*) AS total_videos,
    SUM(view_count) AS total_views,
    ROUND(AVG(views_per_day), 2) AS avg_views_per_day,
    ROUND(SUM(engagement_count) * 1.0 / SUM(view_count), 4) AS weighted_engagement_rate,
    ROUND(AVG(avg_comment_sentiment), 4) AS avg_comment_sentiment
FROM stg_youtube_videos
GROUP BY published_hour
HAVING COUNT(*) >= 3
ORDER BY avg_views_per_day DESC;