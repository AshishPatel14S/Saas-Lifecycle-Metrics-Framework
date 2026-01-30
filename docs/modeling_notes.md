# Modeling Notes (Star Schema)

## Design goals
- BI-friendly star schema for Power BI
- Supports funnel analysis, cohort retention, and churn proxy (14/30/60 days)
- Keeps raw GA4 events in staging; materializes only analytics-ready facts

## Grains
- `fact_sessions`: 1 row per session (user_id + ga_session_id)
- `fact_funnel_steps`: 1 row per session per funnel step
- `fact_user_daily_activity`: 1 row per user per day (retention/churn backbone)
- `fact_purchases`: 1 row per purchase/transaction

## Keys
- `user_id`: GA4 `user_pseudo_id`
- `session_key`: concat(user_id, ga_session_id)
- Dim keys (`device_key`, `geo_key`, `traffic_key`) are deterministic hashes of natural keys (implemented in transformations)

## Profiling results
- `ga_session_id` coverage: 100% in `stg_events_base` (safe to use native session id)
- Events-per-user deciles: [1, 4, 4, 5, 5, 6, 7, 9, 14, 28, 1309]
