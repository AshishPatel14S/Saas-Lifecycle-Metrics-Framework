-- 02_dim_model_ddl.sql
-- Dimensional model (star schema) for SaaS lifecycle analytics
-- Dataset: slmf_dw

CREATE TABLE IF NOT EXISTS `slmf-analytics.slmf_dw.dim_date` (
  date_day DATE NOT NULL,
  year INT64,
  quarter INT64,
  month INT64,
  month_name STRING,
  week INT64,
  day_of_week INT64,
  day_name STRING,
  is_weekend BOOL
);

CREATE TABLE IF NOT EXISTS `slmf-analytics.slmf_dw.dim_user` (
  user_id STRING NOT NULL,
  first_seen_ts TIMESTAMP,
  first_seen_date DATE,
  first_purchase_ts TIMESTAMP,
  first_purchase_date DATE,
  is_purchaser BOOL
);

CREATE TABLE IF NOT EXISTS `slmf-analytics.slmf_dw.dim_device` (
  device_key STRING NOT NULL,
  device_category STRING,
  platform STRING
);

CREATE TABLE IF NOT EXISTS `slmf-analytics.slmf_dw.dim_geo` (
  geo_key STRING NOT NULL,
  country STRING,
  region STRING
);

CREATE TABLE IF NOT EXISTS `slmf-analytics.slmf_dw.dim_traffic_source` (
  traffic_key STRING NOT NULL,
  traffic_source STRING,
  traffic_medium STRING,
  traffic_campaign STRING
);

CREATE TABLE IF NOT EXISTS `slmf-analytics.slmf_dw.fact_sessions` (
  session_key STRING NOT NULL,
  user_id STRING NOT NULL,
  session_id INT64,
  session_number INT64,

  session_start_ts TIMESTAMP,
  session_end_ts TIMESTAMP,
  session_date DATE,

  device_key STRING,
  geo_key STRING,
  traffic_key STRING,

  event_count INT64,
  purchase_count INT64,
  revenue NUMERIC
);

CREATE TABLE IF NOT EXISTS `slmf-analytics.slmf_dw.fact_funnel_steps` (
  session_key STRING NOT NULL,
  user_id STRING NOT NULL,
  session_date DATE,

  funnel_step INT64 NOT NULL,
  funnel_event_name STRING NOT NULL,
  step_ts TIMESTAMP,

  device_key STRING,
  geo_key STRING,
  traffic_key STRING
);

CREATE TABLE IF NOT EXISTS `slmf-analytics.slmf_dw.fact_user_daily_activity` (
  user_id STRING NOT NULL,
  activity_date DATE NOT NULL,

  device_key STRING,
  geo_key STRING,
  traffic_key STRING,

  is_active BOOL,
  event_count INT64,
  had_session_start BOOL,
  had_view_item BOOL,
  had_add_to_cart BOOL,
  had_begin_checkout BOOL,
  had_purchase BOOL,
  purchase_count INT64,
  revenue NUMERIC
);

CREATE TABLE IF NOT EXISTS `slmf-analytics.slmf_dw.fact_purchases` (
  purchase_key STRING NOT NULL,
  user_id STRING NOT NULL,
  purchase_ts TIMESTAMP,
  purchase_date DATE,
  transaction_id STRING,
  revenue NUMERIC,

  device_key STRING,
  geo_key STRING,
  traffic_key STRING,
  session_key STRING
);
