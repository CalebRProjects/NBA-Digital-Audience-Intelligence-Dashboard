-- NBA Digital Audience Intelligence Dashboard
-- 00_sql_practice_queries.sql

-- Purpose:
-- Practice SQL fundamentals using the cleaned YouTube video dataset.

-- 1. Preview the full table ---------------------------------------------

SELECT
    *
FROM stg_youtube_videos
LIMIT 10;


-- 2. Select only key columns --------------------------------------------

SELECT
    team,
    video_title,
    published_date,
    content_type,
    message_theme,
    view_count,
    engagement_rate,
    avg_comment_sentiment
FROM stg_youtube_videos
LIMIT 20;


-- 3. Sort videos by most views ------------------------------------------

SELECT
    team,
    video_title,
    view_count,
    like_count_clean,
    comment_count_clean
FROM stg_youtube_videos
ORDER BY view_count DESC
LIMIT 20;


-- 4. Filter to one team -------------------------------------------------

SELECT
    team,
    video_title,
    view_count,
    engagement_rate
FROM stg_youtube_videos
WHERE team = 'New York Knicks'
ORDER BY view_count DESC;


-- 5. Filter to high-view videos -----------------------------------------

SELECT
    team,
    video_title,
    view_count,
    engagement_rate
FROM stg_youtube_videos
WHERE view_count >= 50000
ORDER BY view_count DESC;


-- 6. Calculate engagement rate manually --------------------------------

SELECT
    team,
    video_title,
    view_count,
    like_count_clean,
    comment_count_clean,
    like_count_clean + comment_count_clean AS total_engagements,
    ROUND((like_count_clean + comment_count_clean) * 1.0 / view_count, 4) AS calculated_engagement_rate
FROM stg_youtube_videos
WHERE view_count > 0
ORDER BY calculated_engagement_rate DESC
LIMIT 20;


-- 7. Count videos by team -----------------------------------------------

SELECT
    team,
    COUNT(*) AS total_videos
FROM stg_youtube_videos
GROUP BY team
ORDER BY total_videos DESC;


-- 8. Team-level KPI summary ---------------------------------------------

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


-- 9. Content type performance -------------------------------------------

SELECT
    content_type,
    COUNT(*) AS total_videos,
    SUM(view_count) AS total_views,
    SUM(engagement_count) AS total_engagements,
    ROUND(SUM(engagement_count) * 1.0 / SUM(view_count), 4) AS weighted_engagement_rate,
    ROUND(AVG(comments_per_1k_views), 2) AS avg_comments_per_1k_views,
    ROUND(AVG(negative_comment_pct), 4) AS avg_negative_comment_pct
FROM stg_youtube_videos
GROUP BY content_type
ORDER BY total_views DESC;


-- 10. Message theme performance -----------------------------------------

SELECT
    message_theme,
    COUNT(*) AS total_videos,
    SUM(view_count) AS total_views,
    SUM(engagement_count) AS total_engagements,
    ROUND(SUM(engagement_count) * 1.0 / SUM(view_count), 4) AS weighted_engagement_rate,
    ROUND(AVG(avg_comment_sentiment), 4) AS avg_comment_sentiment
FROM stg_youtube_videos
GROUP BY message_theme
ORDER BY total_views DESC;


-- 11. Digital monitoring priority ---------------------------------------

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


-- 12. Sentiment bucket summary ------------------------------------------

SELECT
    sentiment_bucket,
    COUNT(*) AS total_videos,
    SUM(view_count) AS total_views,
    ROUND(AVG(engagement_rate), 4) AS avg_engagement_rate,
    ROUND(AVG(positive_comment_pct), 4) AS avg_positive_comment_pct,
    ROUND(AVG(negative_comment_pct), 4) AS avg_negative_comment_pct
FROM stg_youtube_videos
GROUP BY sentiment_bucket
ORDER BY total_views DESC;
