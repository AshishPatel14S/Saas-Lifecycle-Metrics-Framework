# Staging & Transformations (Checkpoint 4)

## Overview
This checkpoint populates the star schema tables in `slmf_dw` from GA4 staging.

## Enriched staging layer
Created `slmf_staging.stg_events_enriched` to centralize transformation logic and create deterministic keys:
- `device_key` = hash(device_category + platform)
- `geo_key` = hash(country + region)
- `traffic_key` = hash(source + medium + campaign)
- `session_key` = concat(user_id, ga_session_id)

## Load order
1. Dimensions: `dim_date`, `dim_device`, `dim_geo`, `dim_traffic_source`, `dim_user`
2. Facts: `fact_sessions`, `fact_funnel_steps`, `fact_user_daily_activity`, `fact_purchases`

## Loaded row counts (initial run)
- dim_date: 92
- dim_device: 3
- dim_geo: 451
- dim_traffic_source: 15
- dim_user: 270,154
- fact_sessions: 360,129
- fact_funnel_steps: 463,259
- fact_user_daily_activity: 319,066
- fact_purchases: 5,692

## Notes
- `ga_session_id` coverage is 100%, so sessionization uses native GA4 session id.
- Churn/retention will be computed primarily from `fact_user_daily_activity`.
