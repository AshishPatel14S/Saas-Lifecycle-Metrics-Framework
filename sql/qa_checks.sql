-- qa_checks.sql
-- Checkpoint 5: Data QA + reconciliation checks (BigQuery)

-- ============================================================
-- 1) Row counts (snapshot)
-- ============================================================
SELECT 'dim_date' AS table_name, COUNT(*) AS cnt FROM `slmf-analytics.slmf_dw.dim_date`
UNION ALL SELECT 'dim_device', COUNT(*) FROM `slmf-analytics.slmf_dw.dim_device`
UNION ALL SELECT 'dim_geo', COUNT(*) FROM `slmf-analytics.slmf_dw.dim_geo`
UNION ALL SELECT 'dim_traffic_source', COUNT(*) FROM `slmf-analytics.slmf_dw.dim_traffic_source`
UNION ALL SELECT 'dim_user', COUNT(*) FROM `slmf-analytics.slmf_dw.dim_user`
UNION ALL SELECT 'fact_sessions', COUNT(*) FROM `slmf-analytics.slmf_dw.fact_sessions`
UNION ALL SELECT 'fact_funnel_steps', COUNT(*) FROM `slmf-analytics.slmf_dw.fact_funnel_steps`
UNION ALL SELECT 'fact_user_daily_activity', COUNT(*) FROM `slmf-analytics.slmf_dw.fact_user_daily_activity`
UNION ALL SELECT 'fact_purchases', COUNT(*) FROM `slmf-analytics.slmf_dw.fact_purchases`;

-- ============================================================
-- 2) Uniqueness checks (should return 0 rows if clean)
-- ============================================================

-- dim_user: user_id unique
SELECT user_id, COUNT(*) AS dup_cnt
FROM `slmf-analytics.slmf_dw.dim_user`
GROUP BY 1
HAVING COUNT(*) > 1;

-- fact_sessions: session_key unique
SELECT session_key, COUNT(*) AS dup_cnt
FROM `slmf-analytics.slmf_dw.fact_sessions`
GROUP BY 1
HAVING COUNT(*) > 1;

-- fact_user_daily_activity: (user_id, activity_date) unique
SELECT user_id, activity_date, COUNT(*) AS dup_cnt
FROM `slmf-analytics.slmf_dw.fact_user_daily_activity`
GROUP BY 1,2
HAVING COUNT(*) > 1;

-- fact_purchases: purchase_key unique
SELECT purchase_key, COUNT(*) AS dup_cnt
FROM `slmf-analytics.slmf_dw.fact_purchases`
GROUP BY 1
HAVING COUNT(*) > 1;

-- ============================================================
-- 3) Null checks (monitor critical fields)
-- ============================================================

SELECT
  COUNT(*) AS total_sessions,
  COUNTIF(user_id IS NULL) AS null_user_id,
  COUNTIF(session_id IS NULL) AS null_session_id,
  COUNTIF(session_start_ts IS NULL) AS null_session_start_ts,
  COUNTIF(session_date IS NULL) AS null_session_date
FROM `slmf-analytics.slmf_dw.fact_sessions`;

SELECT
  COUNT(*) AS total_user_days,
  COUNTIF(user_id IS NULL) AS null_user_id,
  COUNTIF(activity_date IS NULL) AS null_activity_date
FROM `slmf-analytics.slmf_dw.fact_user_daily_activity`;

SELECT
  COUNT(*) AS total_purchases,
  COUNTIF(user_id IS NULL) AS null_user_id,
  COUNTIF(purchase_ts IS NULL) AS null_purchase_ts,
  COUNTIF(purchase_date IS NULL) AS null_purchase_date,
  COUNTIF(revenue IS NULL) AS null_revenue
FROM `slmf-analytics.slmf_dw.fact_purchases`;

-- ============================================================
-- 4) Referential integrity (facts -> dims)
-- ============================================================

-- fact_sessions -> dim_user
SELECT COUNT(*) AS orphan_sessions_users
FROM `slmf-analytics.slmf_dw.fact_sessions` s
LEFT JOIN `slmf-analytics.slmf_dw.dim_user` u
  ON s.user_id = u.user_id
WHERE u.user_id IS NULL;

-- fact_sessions -> dim_device
SELECT COUNT(*) AS orphan_sessions_device
FROM `slmf-analytics.slmf_dw.fact_sessions` s
LEFT JOIN `slmf-analytics.slmf_dw.dim_device` d
  ON s.device_key = d.device_key
WHERE s.device_key IS NOT NULL AND d.device_key IS NULL;

-- fact_sessions -> dim_geo
SELECT COUNT(*) AS orphan_sessions_geo
FROM `slmf-analytics.slmf_dw.fact_sessions` s
LEFT JOIN `slmf-analytics.slmf_dw.dim_geo` g
  ON s.geo_key = g.geo_key
WHERE s.geo_key IS NOT NULL AND g.geo_key IS NULL;

-- fact_sessions -> dim_traffic_source
SELECT COUNT(*) AS orphan_sessions_traffic
FROM `slmf-analytics.slmf_dw.fact_sessions` s
LEFT JOIN `slmf-analytics.slmf_dw.dim_traffic_source` t
  ON s.traffic_key = t.traffic_key
WHERE s.traffic_key IS NOT NULL AND t.traffic_key IS NULL;

-- ============================================================
-- 5) Event ordering sanity (funnel step timestamps within session)
-- ============================================================

-- Funnel steps should fall within the session window (small violations may happen due to GA4 quirks)
SELECT
  COUNT(*) AS funnel_steps_outside_session_window
FROM `slmf-analytics.slmf_dw.fact_funnel_steps` fs
JOIN `slmf-analytics.slmf_dw.fact_sessions` s
  ON fs.session_key = s.session_key
WHERE fs.step_ts < s.session_start_ts
   OR fs.step_ts > s.session_end_ts;

-- ============================================================
-- 6) Reconciliation: events -> sessions -> users
-- ============================================================

-- Total events in enriched staging
SELECT COUNT(*) AS events_cnt
FROM `slmf-analytics.slmf_staging.stg_events_enriched`;

-- Sessions derived from events (should match fact_sessions count)
SELECT COUNT(DISTINCT session_key) AS sessions_distinct_from_events
FROM `slmf-analytics.slmf_staging.stg_events_enriched`;

-- Users derived from events (should match dim_user count)
SELECT COUNT(DISTINCT user_id) AS users_distinct_from_events
FROM `slmf-analytics.slmf_staging.stg_events_enriched`;
