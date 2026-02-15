/* =========================================================
   UNIFIED CROSS-PLATFORM ADVERTISING DATA MODEL
   =========================================================
   Purpose:
   Standardize Facebook, Google, and TikTok advertising datasets
   into one unified reporting table for cross-channel analysis.

   Importace :
   Each platform exports data with different schemas. This query
   normalizes field names, aligns data types, and calculates key
   performance metrics so downstream dashboards can run faster
   and analysts can compare platforms consistently.
   =========================================================
*/

CREATE OR REPLACE TABLE `concise-haven-487417-c2.ads_data.unified_ads_performance` AS


-- FACEBOOK DATA NORMALIZATION
-- Renames columns + calculates metrics + aligns schema

WITH facebook_normalized AS (
  SELECT
    date,
    'Facebook' AS platform,              -- add platform label for source tracking
    campaign_id,
    campaign_name,
    ad_set_id AS ad_group_id,            -- standardize naming across platforms
    ad_set_name AS ad_group_name,
    impressions,
    clicks,
    spend AS cost,                       -- rename spend → cost for consistency
    conversions,

    -- Pre-calculate performance metrics for faster reporting
    SAFE_DIVIDE(clicks, impressions) AS ctr,
    SAFE_DIVIDE(spend, clicks) AS cpc,
    SAFE_DIVIDE(spend, conversions) AS cpa,
    SAFE_DIVIDE(conversions, clicks) AS conversion_rate,

    video_views,
    engagement_rate,
    reach,
    frequency,

    -- Fields which are not available in Facebook data
    CAST(NULL AS FLOAT64) AS conversion_value,
    CAST(NULL AS INT64) AS quality_score,
    CAST(NULL AS INT64) AS likes,
    CAST(NULL AS INT64) AS shares,
    CAST(NULL AS INT64) AS comments

  FROM `concise-haven-487417-c2.ads_data.facebook_ads`
),


-- GOOGLE ADS NORMALIZATION
-- Align schema to match unified structure

google_normalized AS (
  SELECT
    date,
    'Google' AS platform,
    campaign_id,
    campaign_name,
    ad_group_id,
    ad_group_name,
    impressions,
    clicks,
    cost,
    conversions,

    -- Google already provides CTR + CPC
    ctr,
    avg_cpc AS cpc,

    -- Calculate remaining metrics
    SAFE_DIVIDE(cost, conversions) AS cpa,
    SAFE_DIVIDE(conversions, clicks) AS conversion_rate,

    -- Fields not present in Google export
    CAST(NULL AS INT64) AS video_views,
    CAST(NULL AS FLOAT64) AS engagement_rate,
    CAST(NULL AS INT64) AS reach,
    CAST(NULL AS FLOAT64) AS frequency,

    conversion_value,
    quality_score,

    CAST(NULL AS INT64) AS likes,
    CAST(NULL AS INT64) AS shares,
    CAST(NULL AS INT64) AS comments

  FROM `concise-haven-487417-c2.ads_data.google_ads`
),


-- TIKTOK ADS NORMALIZATION
-- Standardize naming + calculate missing metrics

tiktok_normalized AS (
  SELECT
    date,
    'TikTok' AS platform,
    campaign_id,
    campaign_name,
    adgroup_id AS ad_group_id,
    adgroup_name AS ad_group_name,
    impressions,
    clicks,
    cost,
    conversions,

    -- TikTok does not provide CTR/CPC directly → calculate them
    SAFE_DIVIDE(clicks, impressions) AS ctr,
    SAFE_DIVIDE(cost, clicks) AS cpc,
    SAFE_DIVIDE(cost, conversions) AS cpa,
    SAFE_DIVIDE(conversions, clicks) AS conversion_rate,

    video_views,

    -- Not available in TikTok dataset
    CAST(NULL AS FLOAT64) AS engagement_rate,
    CAST(NULL AS INT64) AS reach,
    CAST(NULL AS FLOAT64) AS frequency,
    CAST(NULL AS FLOAT64) AS conversion_value,
    CAST(NULL AS INT64) AS quality_score,

    likes,
    shares,
    comments

  FROM `concise-haven-487417-c2.ads_data.tiktok_ads`
)


/*
   FINAL STEP: MERGE ALL PLATFORMS INTO ONE TABLE
   UNION ALL keeps all records without deduplication
   (important because each row represents unique ad data)
*/

SELECT * FROM facebook_normalized
UNION ALL
SELECT * FROM google_normalized
UNION ALL
SELECT * FROM tiktok_normalized


-- Order output for easier validation and readability
ORDER BY date, platform, campaign_name;



-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Check record counts by platform

SELECT 
  platform,
  COUNT(*) as record_count,
  MIN(date) as first_date,
  MAX(date) as last_date
FROM `concise-haven-487417-c2.ads_data.unified_ads_performance`
GROUP BY platform;

-- Total spend by platform
SELECT
  platform,
  ROUND(SUM(cost), 2) as total_spend,
  SUM(impressions) as total_impressions,
  SUM(clicks) as total_clicks,
  SUM(conversions) as total_conversions,
  ROUND(AVG(ctr) * 100, 2) as avg_ctr_percent
FROM `concise-haven-487417-c2.ads_data.unified_ads_performance`
GROUP BY platform
ORDER BY total_spend DESC;
