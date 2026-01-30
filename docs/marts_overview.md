# Analytics Marts (Checkpoint 6)

## What’s included
All marts are created as BigQuery views in `slmf_marts` sourced from the `slmf_dw` star schema.

### 1) mrt_funnel_daily
Daily session-based funnel:
- sessions
- sessions reaching view_item / add_to_cart / begin_checkout / purchase
- step conversion rates + overall purchase rate

### 2) mrt_retention_cohorts
Weekly cohorts by first_seen_date (week starting Monday), week_index 0–12:
- cohort_size
- active_users
- retention_rate

### 3) mrt_retention_curve
Weighted retention curve aggregated by week_index across cohorts.

### 4) mrt_churn_proxy
User-level churn proxy using days_since_last_active as of max activity date:
- churn_14d / churn_30d / churn_60d flags
- segmentation available via is_purchaser

### 5) mrt_wow_kpis
Weekly operating cadence KPIs:
- WAU, sessions, purchases, revenue
- WoW deltas and WoW % changes
