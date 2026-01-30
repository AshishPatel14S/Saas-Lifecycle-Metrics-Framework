# Data Acquisition & Ingestion (BigQuery)

## Source
- Public dataset: `bigquery-public-data.ga4_obfuscated_sample_ecommerce`
- Tables: `events_YYYYMMDD` (queried via wildcard `events_*`)

## Local Warehouse Layout (my project)
Project: `slmf-analytics`

Datasets:
- `slmf_raw`: source-aligned layer (raw/views, minimal transformation)
- `slmf_staging`: staging layer (standardized views used downstream)

## Base Staging View
Created: `slmf_staging.stg_events_base`

What it standardizes:
- `user_id` = `user_pseudo_id`
- `event_ts_utc` and `event_date_utc` from `event_timestamp`
- Key dimensions (when available): device, geo, traffic_source
- Session fields from `event_params`: `ga_session_id`, `ga_session_number`
- Ecommerce fields: `transaction_id`, `purchase_revenue`

## Validation
- `stg_events_base` row count: **4,295,584**
- Funnel events confirmed present: `session_start`, `view_item`, `add_to_cart`, `begin_checkout`, `purchase`
