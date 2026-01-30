-- qa_summary.sql
-- Single-run QA summary (outputs metric + value)
-- Use this to quickly validate the warehouse after loads.

WITH
t_counts AS (
  SELECT 'count_dim_date' AS metric, COUNT(*) AS value FROM `slmf-analytics.slmf_dw.dim_date` UNION ALL
  SELECT 'count_dim_device', COUNT(*) FROM `slmf-analytics.slmf_dw.dim_device` UNION ALL
  SELECT 'count_dim_geo', COUNT(*) FROM `slmf-analytics.slmf_dw.dim_geo` UNION ALL
  SELECT 'count_dim_traffic_source', COUNT(*) FROM `slmf-analytics.slmf_dw.dim_traffic_source` UNION ALL
  SELECT 'count_dim_user', COUNT(*) FROM `slmf-analytics.slmf_dw.dim_user` UNION ALL
  SELECT 'count_fact_sessions', COUNT(*) FROM `slmf-analytics.slmf_dw.fact_sessions` UNION ALL
  SELECT 'count_fact_funnel_steps', COUNT(*) FROM `slmf-analytics.slmf_dw.fact_funnel_steps` UNION ALL
  SELECT 'count_fact_user_daily_activity', COUNT(*) FROM `slmf-analytics.slmf_dw.fact_user_daily_activity` UNION ALL
  SELECT 'count_fact_purchases', COUNT(*) FROM `slmf-analytics.slmf_dw.fact_purchases`
),

t_dupes AS (
  SELECT 'dupes_dim_user_user_id' AS metric, COUNT(*) AS value
  FROM (SELECT user_id FROM `slmf-analytics.slmf_dw.dim_user` GROUP BY 1 HAVING COUNT(*) > 1)
  UNION ALL
  SELECT 'dupes_fact_sessions_session_key', COUNT(*)
  FROM (SELECT session_key FROM `slmf-analytics.slmf_dw.fact_sessions` GROUP BY 1 HAVING COUNT(*) > 1)
  UNION ALL
  SELECT 'dupes_fact_user_daily_activity_user_day', COUNT(*)
  FROM (SELECT user_id, activity_date FROM `slmf-analytics.slmf_dw.fact_user_daily_activity` GROUP BY 1,2 HAVING COUNT(*) > 1)
  UNION ALL
  SELECT 'dupes_fact_purchases_purchase_key', COUNT(*)
  FROM (SELECT purchase_key FROM `slmf-analytics.slmf_dw.fact_purchases` GROUP BY 1 HAVING COUNT(*) > 1)
),

t_null_metrics AS (
  SELECT 'nulls_fact_sessions_user_id' AS metric, COUNTIF(user_id IS NULL) AS value
  FROM `slmf-analytics.slmf_dw.fact_sessions`
  UNION ALL
  SELECT 'nulls_fact_sessions_session_id', COUNTIF(session_id IS NULL)
  FROM `slmf-analytics.slmf_dw.fact_sessions`
  UNION ALL
  SELECT 'nulls_fact_sessions_session_start_ts', COUNTIF(session_start_ts IS NULL)
  FROM `slmf-analytics.slmf_dw.fact_sessions`
  UNION ALL
  SELECT 'nulls_fact_sessions_session_date', COUNTIF(session_date IS NULL)
  FROM `slmf-analytics.slmf_dw.fact_sessions`
  UNION ALL
  SELECT 'nulls_fact_user_daily_activity_user_id', COUNTIF(user_id IS NULL)
  FROM `slmf-analytics.slmf_dw.fact_user_daily_activity`
  UNION ALL
  SELECT 'nulls_fact_user_daily_activity_activity_date', COUNTIF(activity_date IS NULL)
  FROM `slmf-analytics.slmf_dw.fact_user_daily_activity`
  UNION ALL
  SELECT 'nulls_fact_purchases_user_id', COUNTIF(user_id IS NULL)
  FROM `slmf-analytics.slmf_dw.fact_purchases`
  UNION ALL
  SELECT 'nulls_fact_purchases_purchase_ts', COUNTIF(purchase_ts IS NULL)
  FROM `slmf-analytics.slmf_dw.fact_purchases`
  UNION ALL
  SELECT 'nulls_fact_purchases_purchase_date', COUNTIF(purchase_date IS NULL)
  FROM `slmf-analytics.slmf_dw.fact_purchases`
  UNION ALL
  SELECT 'nulls_fact_purchases_revenue', COUNTIF(revenue IS NULL)
  FROM `slmf-analytics.slmf_dw.fact_purchases`
),

t_orphans AS (
  SELECT 'orphans_fact_sessions_dim_user' AS metric, COUNT(*) AS value
  FROM `slmf-analytics.slmf_dw.fact_sessions` s
  LEFT JOIN `slmf-analytics.slmf_dw.dim_user` u ON s.user_id = u.user_id
  WHERE u.user_id IS NULL
  UNION ALL
  SELECT 'orphans_fact_sessions_dim_device', COUNT(*)
  FROM `slmf-analytics.slmf_dw.fact_sessions` s
  LEFT JOIN `slmf-analytics.slmf_dw.dim_device` d ON s.device_key = d.device_key
  WHERE s.device_key IS NOT NULL AND d.device_key IS NULL
  UNION ALL
  SELECT 'orphans_fact_sessions_dim_geo', COUNT(*)
  FROM `slmf-analytics.slmf_dw.fact_sessions` s
  LEFT JOIN `slmf-analytics.slmf_dw.dim_geo` g ON s.geo_key = g.geo_key
  WHERE s.geo_key IS NOT NULL AND g.geo_key IS NULL
  UNION ALL
  SELECT 'orphans_fact_sessions_dim_traffic_source', COUNT(*)
  FROM `slmf-analytics.slmf_dw.fact_sessions` s
  LEFT JOIN `slmf-analytics.slmf_dw.dim_traffic_source` t ON s.traffic_key = t.traffic_key
  WHERE s.traffic_key IS NOT NULL AND t.traffic_key IS NULL
),

t_recon AS (
  SELECT 'recon_events_cnt' AS metric, COUNT(*) AS value
  FROM `slmf-analytics.slmf_staging.stg_events_enriched`
  UNION ALL
  SELECT 'recon_sessions_distinct_from_events', COUNT(DISTINCT session_key)
  FROM `slmf-analytics.slmf_staging.stg_events_enriched`
  UNION ALL
  SELECT 'recon_users_distinct_from_events', COUNT(DISTINCT user_id)
  FROM `slmf-analytics.slmf_staging.stg_events_enriched`
),

t_ordering AS (
  SELECT 'funnel_steps_outside_session_window' AS metric, COUNT(*) AS value
  FROM `slmf-analytics.slmf_dw.fact_funnel_steps` fs
  JOIN `slmf-analytics.slmf_dw.fact_sessions` s
    ON fs.session_key = s.session_key
  WHERE fs.step_ts < s.session_start_ts OR fs.step_ts > s.session_end_ts
)

SELECT * FROM t_counts
UNION ALL SELECT * FROM t_dupes
UNION ALL SELECT * FROM t_null_metrics
UNION ALL SELECT * FROM t_orphans
UNION ALL SELECT * FROM t_recon
UNION ALL SELECT * FROM t_ordering
ORDER BY metric;
