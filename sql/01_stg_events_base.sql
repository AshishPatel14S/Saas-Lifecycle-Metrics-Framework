-- 01_stg_events_base.sql
-- Base staging view for GA4 events (standardized columns)

CREATE OR REPLACE VIEW `slmf-analytics.slmf_staging.stg_events_base` AS
SELECT
  user_pseudo_id AS user_id,
  TIMESTAMP_MICROS(event_timestamp) AS event_ts_utc,
  DATE(TIMESTAMP_MICROS(event_timestamp)) AS event_date_utc,
  event_name,

  platform,
  device.category AS device_category,
  geo.country AS country,
  geo.region AS region,

  traffic_source.source AS traffic_source,
  traffic_source.medium AS traffic_medium,
  traffic_source.name AS traffic_campaign,

  (SELECT ep.value.int_value FROM UNNEST(event_params) ep WHERE ep.key = 'ga_session_id') AS ga_session_id,
  (SELECT ep.value.int_value FROM UNNEST(event_params) ep WHERE ep.key = 'ga_session_number') AS ga_session_number,

  ecommerce.transaction_id AS transaction_id,
  ecommerce.purchase_revenue AS purchase_revenue
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`;
