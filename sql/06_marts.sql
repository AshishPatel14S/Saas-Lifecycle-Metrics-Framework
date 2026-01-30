-- 06_marts.sql
-- Checkpoint 6: Analytics marts (views) for Funnel, Cohorts/Retention, Churn Proxy, WoW KPIs
-- Source: slmf_dw star schema
-- Target: slmf_marts

-- ============================================================
-- 1) Daily funnel mart (session-based)
-- ============================================================
CREATE OR REPLACE VIEW `slmf-analytics.slmf_marts.mrt_funnel_daily` AS
WITH session_flags AS (
  SELECT
    session_key,
    ANY_VALUE(session_date) AS session_date,
    ANY_VALUE(user_id) AS user_id,
    MAX(CASE WHEN funnel_step >= 1 THEN 1 ELSE 0 END) AS did_session_start,
    MAX(CASE WHEN funnel_step >= 2 THEN 1 ELSE 0 END) AS did_view_item,
    MAX(CASE WHEN funnel_step >= 3 THEN 1 ELSE 0 END) AS did_add_to_cart,
    MAX(CASE WHEN funnel_step >= 4 THEN 1 ELSE 0 END) AS did_begin_checkout,
    MAX(CASE WHEN funnel_step >= 5 THEN 1 ELSE 0 END) AS did_purchase
  FROM `slmf-analytics.slmf_dw.fact_funnel_steps`
  GROUP BY 1
),
daily AS (
  SELECT
    session_date,
    COUNT(*) AS sessions,
    COUNTIF(did_view_item=1) AS sessions_view_item,
    COUNTIF(did_add_to_cart=1) AS sessions_add_to_cart,
    COUNTIF(did_begin_checkout=1) AS sessions_begin_checkout,
    COUNTIF(did_purchase=1) AS sessions_purchase
  FROM session_flags
  GROUP BY 1
)
SELECT
  session_date,
  sessions,
  sessions_view_item,
  sessions_add_to_cart,
  sessions_begin_checkout,
  sessions_purchase,
  SAFE_DIVIDE(sessions_view_item, sessions) AS rate_view_item,
  SAFE_DIVIDE(sessions_add_to_cart, sessions_view_item) AS rate_add_to_cart_given_view,
  SAFE_DIVIDE(sessions_begin_checkout, sessions_add_to_cart) AS rate_begin_checkout_given_cart,
  SAFE_DIVIDE(sessions_purchase, sessions_begin_checkout) AS rate_purchase_given_checkout,
  SAFE_DIVIDE(sessions_purchase, sessions) AS rate_purchase_overall
FROM daily;

-- ============================================================
-- 2) Cohort retention table (weekly cohorts, week 0..12)
-- ============================================================
CREATE OR REPLACE VIEW `slmf-analytics.slmf_marts.mrt_retention_cohorts` AS
WITH cohorts AS (
  SELECT
    user_id,
    DATE_TRUNC(first_seen_date, WEEK(MONDAY)) AS cohort_week
  FROM `slmf-analytics.slmf_dw.dim_user`
  WHERE first_seen_date IS NOT NULL
),
activity AS (
  SELECT
    user_id,
    DATE_TRUNC(activity_date, WEEK(MONDAY)) AS activity_week
  FROM `slmf-analytics.slmf_dw.fact_user_daily_activity`
  GROUP BY 1,2
),
cohort_sizes AS (
  SELECT cohort_week, COUNT(*) AS cohort_size
  FROM cohorts
  GROUP BY 1
),
retained AS (
  SELECT
    c.cohort_week,
    DATE_DIFF(a.activity_week, c.cohort_week, WEEK) AS week_index,
    COUNT(DISTINCT c.user_id) AS active_users
  FROM cohorts c
  JOIN activity a
    ON c.user_id = a.user_id
  WHERE DATE_DIFF(a.activity_week, c.cohort_week, WEEK) BETWEEN 0 AND 12
  GROUP BY 1,2
)
SELECT
  r.cohort_week,
  r.week_index,
  s.cohort_size,
  r.active_users,
  SAFE_DIVIDE(r.active_users, s.cohort_size) AS retention_rate
FROM retained r
JOIN cohort_sizes s
  USING (cohort_week);

-- ============================================================
-- 3) Retention curve (aggregate across cohorts by week_index)
-- ============================================================
CREATE OR REPLACE VIEW `slmf-analytics.slmf_marts.mrt_retention_curve` AS
SELECT
  week_index,
  SUM(active_users) AS active_users,
  SUM(cohort_size) AS cohort_users,
  SAFE_DIVIDE(SUM(active_users), SUM(cohort_size)) AS retention_rate_weighted
FROM `slmf-analytics.slmf_marts.mrt_retention_cohorts`
GROUP BY 1
ORDER BY 1;

-- ============================================================
-- 4) Churn proxy (14/30/60 days since last active)
-- ============================================================
CREATE OR REPLACE VIEW `slmf-analytics.slmf_marts.mrt_churn_proxy` AS
WITH bounds AS (
  SELECT MAX(activity_date) AS as_of_date
  FROM `slmf-analytics.slmf_dw.fact_user_daily_activity`
),
last_active AS (
  SELECT
    u.user_id,
    u.first_seen_date,
    u.first_purchase_date,
    u.is_purchaser,
    MAX(a.activity_date) AS last_active_date
  FROM `slmf-analytics.slmf_dw.dim_user` u
  LEFT JOIN `slmf-analytics.slmf_dw.fact_user_daily_activity` a
    ON u.user_id = a.user_id
  GROUP BY 1,2,3,4
)
SELECT
  la.*,
  b.as_of_date,
  DATE_DIFF(b.as_of_date, la.last_active_date, DAY) AS days_since_last_active,
  CASE WHEN DATE_DIFF(b.as_of_date, la.last_active_date, DAY) >= 14 THEN 1 ELSE 0 END AS churn_14d,
  CASE WHEN DATE_DIFF(b.as_of_date, la.last_active_date, DAY) >= 30 THEN 1 ELSE 0 END AS churn_30d,
  CASE WHEN DATE_DIFF(b.as_of_date, la.last_active_date, DAY) >= 60 THEN 1 ELSE 0 END AS churn_60d
FROM last_active la
CROSS JOIN bounds b;

-- ============================================================
-- 5) WoW KPI mart (weekly “what changed this week?”)
-- ============================================================
CREATE OR REPLACE VIEW `slmf-analytics.slmf_marts.mrt_wow_kpis` AS
WITH weekly AS (
  SELECT
    DATE_TRUNC(activity_date, WEEK(MONDAY)) AS week_start,
    COUNT(DISTINCT user_id) AS wau,
    SUM(event_count) AS events,
    SUM(purchase_count) AS purchases,
    SUM(COALESCE(revenue,0)) AS revenue
  FROM `slmf-analytics.slmf_dw.fact_user_daily_activity`
  GROUP BY 1
),
sessions_weekly AS (
  SELECT
    DATE_TRUNC(session_date, WEEK(MONDAY)) AS week_start,
    COUNT(*) AS sessions
  FROM `slmf-analytics.slmf_dw.fact_sessions`
  GROUP BY 1
),
joined AS (
  SELECT
    w.week_start,
    w.wau,
    s.sessions,
    w.purchases,
    w.revenue,
    SAFE_DIVIDE(w.purchases, s.sessions) AS purchase_per_session,
    SAFE_DIVIDE(w.revenue, s.sessions) AS revenue_per_session
  FROM weekly w
  LEFT JOIN sessions_weekly s USING (week_start)
),
final AS (
  SELECT
    *,
    LAG(wau) OVER (ORDER BY week_start) AS wau_prev,
    LAG(sessions) OVER (ORDER BY week_start) AS sessions_prev,
    LAG(purchases) OVER (ORDER BY week_start) AS purchases_prev,
    LAG(revenue) OVER (ORDER BY week_start) AS revenue_prev
  FROM joined
)
SELECT
  week_start,
  wau,
  sessions,
  purchases,
  revenue,
  purchase_per_session,
  revenue_per_session,
  (wau - wau_prev) AS wau_wow_delta,
  SAFE_DIVIDE(wau - wau_prev, wau_prev) AS wau_wow_pct,
  (sessions - sessions_prev) AS sessions_wow_delta,
  SAFE_DIVIDE(sessions - sessions_prev, sessions_prev) AS sessions_wow_pct,
  (purchases - purchases_prev) AS purchases_wow_delta,
  SAFE_DIVIDE(purchases - purchases_prev, purchases_prev) AS purchases_wow_pct,
  (revenue - revenue_prev) AS revenue_wow_delta,
  SAFE_DIVIDE(revenue - revenue_prev, revenue_prev) AS revenue_wow_pct
FROM final
ORDER BY week_start;
