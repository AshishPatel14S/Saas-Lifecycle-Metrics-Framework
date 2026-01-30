# Data Quality Checks (Checkpoint 5)

## Scope
QA checks validate the dimensional model built from GA4 events:
- uniqueness
- nulls
- referential integrity
- event ordering sanity
- reconciliation (events → sessions → users)

## Results summary (initial run)

### Row counts
- dim_date: 92
- dim_device: 3
- dim_geo: 451
- dim_traffic_source: 15
- dim_user: 270,154
- fact_sessions: 360,129
- fact_funnel_steps: 463,259
- fact_user_daily_activity: 319,066
- fact_purchases: 4,475 (after dedupe)

### Uniqueness
- dim_user user_id duplicates: 0
- fact_sessions session_key duplicates: 0
- fact_user_daily_activity (user_id, activity_date) duplicates: 0
- fact_purchases purchase_key duplicates: 327  ✅ identified issue

### Null checks (critical fields)
- fact_sessions nulls (user_id/session_id/session_start_ts/session_date): all 0
- fact_user_daily_activity nulls (user_id/activity_date): all 0
- fact_purchases nulls:
  - user_id: 0
  - purchase_ts: 0
  - purchase_date: 0
  - revenue: 0 (after dedupe)

### Referential integrity (orphans)
- sessions without dim_user: 0
- sessions device_key missing in dim_device: 0
- sessions geo_key missing in dim_geo: 0
- sessions traffic_key missing in dim_traffic_source: 0

### Event ordering sanity
- funnel steps outside session window: 0

### Reconciliation
- events_cnt (stg_events_enriched): 4,295,584
- sessions_distinct_from_events: 360,129 (matches fact_sessions)
- users_distinct_from_events: 270,154 (matches dim_user)

## Remediation actions
### Duplicate purchase keys
Observed 327 duplicate `purchase_key` values in `fact_purchases`. Root cause is likely repeated purchase events sharing the same transaction id or duplicate purchase events emitted in GA4 export.

**Fix applied:** rebuilt `fact_purchases` to enforce 1 row per `purchase_key` using `ROW_NUMBER()` deduplication (canonical earliest purchase_ts per key).

### Null revenue on purchases
450 purchase rows have NULL revenue. For downstream marts and BI measures, revenue will be treated as 0 unless the analysis specifically calls out missing revenue.

## Notes / caveats
- GA4 exports can include edge cases (duplicate event emission and revenue nulls).
- These are documented and handled with explicit grain rules and conservative assumptions.

- ## After remediation (final)
- fact_purchases duplicate purchase_keys: 0
- fact_purchases row count: 4,475
- fact_purchases null revenue count: 0

