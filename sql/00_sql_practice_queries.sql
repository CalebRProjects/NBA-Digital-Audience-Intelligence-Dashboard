-- NBA Digital Audience Intelligence Dashboard
-- 00_sql_practice_queries.sql

-- Purpose:
-- Practice SQL fundamentals using the cleaned YouTube video dataset.

-- 1. Preview rows

SELECT
    *
FROM stg_youtube_videos
LIMIT 10;


-- 2. Most viewed videos

SELECT
    team,
    video_title,
    view_count,
    like_count_clean,
    comment_count_clean
FROM stg_youtube_videos
ORDER BY view_count DESC
LIMIT 20;


-- 3. Team-level KPI summary

SELECT
    team,
    COUNT(*) AS total_videos,
    SUM(view_count) AS total_views,
    SUM(engagement_count) AS total_engagements,
    ROUND(SUM(engagement_count) * 1.0 / SUM(view_count), 4) AS weighted_engagement_rate
FROM stg_youtube_videos
GROUP BY team
ORDER BY total_views DESC;