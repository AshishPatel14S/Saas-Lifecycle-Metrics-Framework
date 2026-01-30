# Metric Dictionary (SaaS-ready)

This dictionary defines business-facing KPIs and the exact rules used in SQL marts and Power BI measures.
All dashboard measures must match these definitions.

## Core Entities
- **Event**: a tracked interaction (event_name + timestamp + properties)
- **User**: pseudonymous GA4 identifier (not stitched across devices)
- **Session**: derived using sessionization rules (see Tracking Plan)

---

## North Star
### Activated Users (North Star)
**Definition:** Unique users who complete the activation event in the period.  
**Activation event (project proxy):** `purchase`  
**Formula:** `COUNT(DISTINCT user_id) WHERE event_name = 'purchase'` within date range.  
**Caveat:** In real SaaS, activation is an “aha” event (e.g., created first project). GA4 sample lacks true SaaS activation; purchase is the closest value proxy.

---

## Funnel
**Primary funnel steps (GA4 ecommerce proxy):**
1) `session_start` (or first event in session)  
2) `view_item`  
3) `add_to_cart`  
4) `begin_checkout`  
5) `purchase`

### Step Users
**Definition:** Unique users who fired the step event at least once in the period.

### Step Conversion Rate
**Definition:** Users who reached step N ÷ users who reached step N-1.  
**Formula:** `users_step_n / users_step_(n-1)`

### Overall Funnel Conversion
**Definition:** Purchase users ÷ top-of-funnel users (`session_start` users).  
**Formula:** `purchase_users / session_start_users`

### Drop-off Rate
**Definition:** 1 − Step Conversion Rate

---

## Retention
### Active User
**Definition:** A user with ≥1 qualifying event in the time grain.  
**Default qualifying events:** all events unless excluded as noise (documented in Tracking Plan).

### Cohort
**Definition:** Users grouped by first-seen date based on the cohort anchor event.  
**Default anchor:** first `session_start` date (acquisition proxy).  
**Alternative (activation cohort):** first `purchase` date.

### N-Day Retention
**Definition:** % of cohort users active on day N after cohort date.  
**Formula:** `retained_users_on_day_N / cohort_size`  
**Outputs:** cohort retention table (heatmap-ready) + retention curves.

---

## Churn (Behavioral proxy)
### Churned User (inactivity-based)
**Definition:** A user is churned if they have **no qualifying events** for X days.  
**Windows:** 14 / 30 / 60 days.

### Churn Rate (windowed)
**Definition:** Users who newly cross the inactivity threshold ÷ users at risk.  
**At risk:** users active prior to the threshold window.

---

## Guardrails
### Event Volume
**Definition:** total events in period (detect tracking breaks)

### Purchases per Purchasing User
**Definition:** `purchase_event_count / distinct_purchase_users` (detect outliers/spam)

---

## Required Segments (minimum)
- Device category (if available)
- Geo (if available)
- Acquisition source/medium/channel (if available)
- New vs returning (derived from first-seen date)

