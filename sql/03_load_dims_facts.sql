-- 03_load_dims_facts.sql
-- Checkpoint 4: Transformations to populate dims + facts from GA4 staging
-- Source: slmf_staging.stg_events_base / stg_events_enriched
-- Target: slmf_dw (star schema)

-- ============================================================
-- 1) Enriched staging view (adds deterministic dimension keys)
-- ============================================================

CREATE OR REPLACE VIEW `slmf-analytics.slmf_staging.stg_events_enriched` AS
SELECT
  user_id,
  event_ts_utc,
  event_date_utc,
  event_name,

  platform,
  device_category,
  country,
  region,
  traffic_source,
  traffic_medium,
  traffic_campaign,

  ga_session_id,
  ga_session_number,
  transaction_id,
  CAST(purchase_revenue AS NUMERIC) AS purchase_revenue,

  TO_HEX(MD5(CONCAT(IFNULL(device_category,''),'|',IFNULL(platform,'')))) AS device_key,
  TO_HEX(MD5(CONCAT(IFNULL(country,''),'|',IFNULL(region,'')))) AS geo_key,
  TO_HEX(MD5(CONCAT(IFNULL(traffic_source,''),'|',IFNULL(traffic_medium,''),'|',IFNULL(traffic_campaign,'')))) AS traffic_key,

  CONCAT(user_id, '-', CAST(ga_session_id AS STRING)) AS session_key
FROM `slmf-analytics.slmf_staging.stg_events_base`;

-- =========================
-- 2) Dimensions
-- =========================

-- dim_date
INSERT INTO `slmf-analytics.slmf_dw.dim_date`
(date_day, year, quarter, month, month_name, week, day_of_week, day_name, is_weekend)
SELECT
  d AS date_day,
  EXTRACT(YEAR FROM d) AS year,
  EXTRACT(QUARTER FROM d) AS quarter,
  EXTRACT(MONTH FROM d) AS month,
  FORMAT_DATE('%B', d) AS month_name,
  EXTRACT(WEEK FROM d) AS week,
  EXTRACT(DAYOFWEEK FROM d) AS day_of_week,
  FORMAT_DATE('%A', d) AS day_name,
  EXTRACT(DAYOFWEEK FROM d) IN (1,7) AS is_weekend
FROM (
  SELECT DISTINCT event_date_utc AS d
  FROM `slmf-analytics.slmf_staging.stg_events_enriched`
)
WHERE d IS NOT NULL
AND d NOT IN (SELECT date_day FROM `slmf-analytics.slmf_dw.dim_date`);

-- dim_device
INSERT INTO `slmf-analytics.slmf_dw.dim_device` (device_key, device_category, platform)
SELECT DISTINCT
  device_key,
  device_category,
  platform
FROM `slmf-analytics.slmf_staging.stg_events_enriched`
WHERE device_key IS NOT NULL
AND device_key NOT IN (SELECT device_key FROM `slmf-analytics.slmf_dw.dim_device`);

-- dim_geo
INSERT INTO `slmf-analytics.slmf_dw.dim_geo` (geo_key, country, region)
SELECT DISTINCT
  geo_key,
  country,
  region
FROM `slmf-analytics.slmf_staging.stg_events_enriched`
WHERE geo_key IS NOT NULL
AND geo_key NOT IN (SELECT geo_key FROM `slmf-analytics.slmf_dw.dim_geo`);

-- dim_traffic_source
INSERT INTO `slmf-analytics.slmf_dw.dim_traffic_source` (traffic_key, traffic_source, traffic_medium, traffic_campaign)
SELECT DISTINCT
  traffic_key,
  traffic_source,
  traffic_medium,
  traffic_campaign
FROM `slmf-analytics.slmf_staging.stg_events_enriched`
WHERE traffic_key IS NOT NULL
AND traffic_key NOT IN (SELECT traffic_key FROM `slmf-analytics.slmf_dw.dim_traffic_source`);

-- dim_user
INSERT INTO `slmf-analytics.slmf_dw.dim_user`
(user_id, first_seen_ts, first_seen_date, first_purchase_ts, first_purchase_date, is_purchaser)
WITH base AS (
  SELECT
    user_id,
    MIN(event_ts_utc) AS first_seen_ts,
    MIN(event_date_utc) AS first_seen_date,
    MIN(IF(event_name='purchase', event_ts_utc, NULL)) AS first_purchase_ts,
    MIN(IF(event_name='purchase', event_date_utc, NULL)) AS first_purchase_date,
    COUNTIF(event_name='purchase') > 0 AS is_purchaser
  FROM `slmf-analytics.slmf_staging.stg_events_enriched`
  GROUP BY 1
)
SELECT *
FROM base
WHERE user_id NOT IN (SELECT user_id FROM `slmf-analytics.slmf_dw.dim_user`);

-- =========================
-- 3) Facts
-- =========================

-- fact_sessions
INSERT INTO `slmf-analytics.slmf_dw.fact_sessions` (
  session_key, user_id, session_id, session_number,
  session_start_ts, session_end_ts, session_date,
  device_key, geo_key, traffic_key,
  event_count, purchase_count, revenue
)
SELECT
  session_key,
  ANY_VALUE(user_id) AS user_id,
  ANY_VALUE(ga_session_id) AS session_id,
  ANY_VALUE(ga_session_number) AS session_number,

  MIN(event_ts_utc) AS session_start_ts,
  MAX(event_ts_utc) AS session_end_ts,
  MIN(event_date_utc) AS session_date,

  ANY_VALUE(device_key) AS device_key,
  ANY_VALUE(geo_key) AS geo_key,
  ANY_VALUE(traffic_key) AS traffic_key,

  COUNT(*) AS event_count,
  COUNTIF(event_name='purchase') AS purchase_count,
  SUM(IF(event_name='purchase', purchase_revenue, 0)) AS revenue
FROM `slmf-analytics.slmf_staging.stg_events_enriched`
GROUP BY session_key
HAVING session_key NOT IN (SELECT session_key FROM `slmf-analytics.slmf_dw.fact_sessions`);

-- fact_funnel_steps
INSERT INTO `slmf-analytics.slmf_dw.fact_funnel_steps` (
  session_key, user_id, session_date,
  funnel_step, funnel_event_name, step_ts,
  device_key, geo_key, traffic_key
)
WITH steps AS (
  SELECT
    session_key,
    user_id,
    event_date_utc AS session_date,
    device_key,
    geo_key,
    traffic_key,
    event_name,
    MIN(event_ts_utc) AS step_ts
  FROM `slmf-analytics.slmf_staging.stg_events_enriched`
  WHERE event_name IN ('session_start','view_item','add_to_cart','begin_checkout','purchase')
  GROUP BY 1,2,3,4,5,6,7
),
mapped AS (
  SELECT
    session_key,
    user_id,
    session_date,
    CAST(
      CASE event_name
        WHEN 'session_start' THEN 1
        WHEN 'view_item' THEN 2
        WHEN 'add_to_cart' THEN 3
        WHEN 'begin_checkout' THEN 4
        WHEN 'purchase' THEN 5
        ELSE NULL
      END
    AS INT64) AS funnel_step,
    event_name AS funnel_event_name,
    step_ts,
    device_key,
    geo_key,
    traffic_key
  FROM steps
)
SELECT *
FROM mapped
WHERE funnel_step IS NOT NULL
AND CONCAT(session_key,'|',CAST(funnel_step AS STRING)) NOT IN (
  SELECT CONCAT(session_key,'|',CAST(funnel_step AS STRING))
  FROM `slmf-analytics.slmf_dw.fact_funnel_steps`
);

-- fact_user_daily_activity
INSERT INTO `slmf-analytics.slmf_dw.fact_user_daily_activity` (
  user_id, activity_date,
  device_key, geo_key, traffic_key,
  is_active, event_count,
  had_session_start, had_view_item, had_add_to_cart, had_begin_checkout, had_purchase,
  purchase_count, revenue
)
SELECT
  user_id,
  event_date_utc AS activity_date,

  ANY_VALUE(device_key) AS device_key,
  ANY_VALUE(geo_key) AS geo_key,
  ANY_VALUE(traffic_key) AS traffic_key,

  TRUE AS is_active,
  COUNT(*) AS event_count,

  COUNTIF(event_name='session_start') > 0 AS had_session_start,
  COUNTIF(event_name='view_item') > 0 AS had_view_item,
  COUNTIF(event_name='add_to_cart') > 0 AS had_add_to_cart,
  COUNTIF(event_name='begin_checkout') > 0 AS had_begin_checkout,
  COUNTIF(event_name='purchase') > 0 AS had_purchase,

  COUNTIF(event_name='purchase') AS purchase_count,
  SUM(IF(event_name='purchase', purchase_revenue, 0)) AS revenue
FROM `slmf-analytics.slmf_staging.stg_events_enriched`
GROUP BY 1,2
HAVING CONCAT(user_id,'|',CAST(activity_date AS STRING)) NOT IN (
  SELECT CONCAT(user_id,'|',CAST(activity_date AS STRING))
  FROM `slmf-analytics.slmf_dw.fact_user_daily_activity`
);

-- fact_purchases
INSERT INTO `slmf-analytics.slmf_dw.fact_purchases` (
  purchase_key, user_id, purchase_ts, purchase_date,
  transaction_id, revenue,
  device_key, geo_key, traffic_key, session_key
)
WITH p AS (
  SELECT
    user_id,
    session_key,
    event_ts_utc AS purchase_ts,
    event_date_utc AS purchase_date,
    transaction_id,
    purchase_revenue,
    device_key, geo_key, traffic_key
  FROM `slmf-analytics.slmf_staging.stg_events_enriched`
  WHERE event_name='purchase'
)
SELECT
  COALESCE(transaction_id, TO_HEX(MD5(CONCAT(user_id,'|',CAST(purchase_ts AS STRING))))) AS purchase_key,
  user_id,
  purchase_ts,
  purchase_date,
  transaction_id,
  purchase_revenue AS revenue,
  device_key, geo_key, traffic_key, session_key
FROM p
WHERE COALESCE(transaction_id, TO_HEX(MD5(CONCAT(user_id,'|',CAST(purchase_ts AS STRING))))) NOT IN (
  SELECT purchase_key FROM `slmf-analytics.slmf_dw.fact_purchases`
);
-- Enforce purchase grain: 1 row per purchase_key (dedupe)
CREATE OR REPLACE TABLE `slmf-analytics.slmf_dw.fact_purchases` AS
SELECT * EXCEPT(rn)
FROM (
  SELECT
    purchase_key, user_id, purchase_ts, purchase_date,
    transaction_id, revenue,
    device_key, geo_key, traffic_key, session_key,
    ROW_NUMBER() OVER (PARTITION BY purchase_key ORDER BY purchase_ts ASC) AS rn
  FROM `slmf-analytics.slmf_dw.fact_purchases`
)
WHERE rn = 1;
